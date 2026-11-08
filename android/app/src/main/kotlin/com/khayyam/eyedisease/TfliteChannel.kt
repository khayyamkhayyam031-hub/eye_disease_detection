package com.khayyam.eyedisease

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import java.util.concurrent.Executors

/**
 * Minimal TFLite bridge: one shared [Interpreter] for the whole app, used only
 * from a single background thread (Interpreter is not thread-safe).
 * CPU with the built-in XNNPACK delegate; no GPU delegate (APK size budget).
 *
 * Methods:
 *  - load {asset, threads} -> {input: [shape], output: [shape]}
 *  - run  {input: Float32List} -> Float32List (softmax probabilities)
 *  - close
 */
object TfliteChannel {
    private const val CHANNEL = "eye_disease/tflite"

    private val executor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "tflite").apply { priority = Thread.NORM_PRIORITY }
    }
    private val main = Handler(Looper.getMainLooper())

    @Volatile private var interpreter: Interpreter? = null
    private var inputBuffer: ByteBuffer? = null
    private var outputBuffer: ByteBuffer? = null

    fun register(context: Context, messenger: BinaryMessenger) {
        val appContext = context.applicationContext
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            executor.execute { handle(appContext, call, result) }
        }
    }

    private fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "load" -> {
                    val asset = call.argument<String>("asset")
                        ?: throw IllegalArgumentException("asset missing")
                    val threads = call.argument<Int>("threads") ?: 4
                    val interp = interpreter ?: load(context, asset, threads)
                    val inShape = interp.getInputTensor(0).shape().toList()
                    val outShape = interp.getOutputTensor(0).shape().toList()
                    reply { result.success(mapOf("input" to inShape, "output" to outShape)) }
                }
                "run" -> {
                    val interp = interpreter ?: throw IllegalStateException("model not loaded")
                    val input = call.argument<FloatArray>("input")
                        ?: throw IllegalArgumentException("input missing")
                    val out = run(interp, input)
                    reply { result.success(out) }
                }
                "close" -> {
                    interpreter?.close()
                    interpreter = null
                    inputBuffer = null
                    outputBuffer = null
                    reply { result.success(null) }
                }
                else -> reply { result.notImplemented() }
            }
        } catch (t: Throwable) {
            reply { result.error("tflite_error", t.message ?: t.javaClass.simpleName, null) }
        }
    }

    private fun load(context: Context, asset: String, threads: Int): Interpreter {
        val model = mapAsset(context, asset)
        val options = Interpreter.Options().apply {
            setNumThreads(threads.coerceIn(1, 4))
        }
        val interp = Interpreter(model, options)
        interp.allocateTensors()
        interpreter = interp
        return interp
    }

    /** Memory-maps the model (it is stored uncompressed, see build.gradle noCompress). */
    private fun mapAsset(context: Context, asset: String): ByteBuffer {
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
        return try {
            context.assets.openFd(key).use { fd ->
                FileInputStream(fd.fileDescriptor).channel.use { ch ->
                    ch.map(FileChannel.MapMode.READ_ONLY, fd.startOffset, fd.declaredLength)
                } as MappedByteBuffer
            }
        } catch (e: Exception) {
            // Fallback when the asset is compressed: copy into a direct buffer.
            val bytes = context.assets.open(key).use { it.readBytes() }
            ByteBuffer.allocateDirect(bytes.size).order(ByteOrder.nativeOrder()).apply {
                put(bytes)
                rewind()
            }
        }
    }

    private fun run(interp: Interpreter, input: FloatArray): FloatArray {
        val inBytes = input.size * 4
        val inBuf = inputBuffer?.takeIf { it.capacity() == inBytes }
            ?: ByteBuffer.allocateDirect(inBytes).order(ByteOrder.nativeOrder()).also { inputBuffer = it }
        inBuf.rewind()
        inBuf.asFloatBuffer().put(input)

        val outCount = interp.getOutputTensor(0).numElements()
        val outBuf = outputBuffer?.takeIf { it.capacity() == outCount * 4 }
            ?: ByteBuffer.allocateDirect(outCount * 4).order(ByteOrder.nativeOrder()).also { outputBuffer = it }
        outBuf.rewind()

        interp.run(inBuf, outBuf)

        outBuf.rewind()
        val out = FloatArray(outCount)
        outBuf.asFloatBuffer().get(out)
        return out
    }

    private inline fun reply(crossinline block: () -> Unit) {
        main.post { block() }
    }
}
