import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../data/disease_info.dart';
import 'config.dart';
import 'formatters.dart';
import 'image_utils.dart';

/// Builds a one-page PDF screening report and opens the share sheet.
/// (English text: the default PDF font has no Urdu glyphs and bundling a
/// Nastaliq font would break the size budget.)
class PdfReport {
  PdfReport._();

  static const _names = {
    'cataract': 'Cataract',
    'diabetic_retinopathy': 'Diabetic Retinopathy',
    'glaucoma': 'Glaucoma',
    'normal': 'Normal',
    'not_fundus': 'Not a retina image',
  };

  static Future<void> share({
    required String imagePath,
    required String label,
    required double confidence,
    required Map<String, double> probabilities,
    required DateTime createdAt,
    required String patientName,
    DiseaseInfo? info,
  }) async {
    final file = await build(
      imagePath: imagePath,
      label: label,
      confidence: confidence,
      probabilities: probabilities,
      createdAt: createdAt,
      patientName: patientName,
      info: info,
    );
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Eye screening report',
    ));
  }

  static Future<File> build({
    required String imagePath,
    required String label,
    required double confidence,
    required Map<String, double> probabilities,
    required DateTime createdAt,
    required String patientName,
    DiseaseInfo? info,
  }) async {
    final imageBytes = await ImageUtils.reportImage(imagePath);
    final doc = pw.Document(title: 'Eye screening report', author: AppConfig.developer);
    const primary = PdfColor.fromInt(0xFF1E5AA8);
    const grey = PdfColor.fromInt(0xFF5F6B7A);

    final sorted = probabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        pw.Text('Eye Disease Detection',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: primary)),
        pw.Text('AI screening report', style: const pw.TextStyle(fontSize: 12, color: grey)),
        pw.SizedBox(height: 4),
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 8),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          if (imageBytes != null)
            pw.Container(
              width: 180,
              height: 180,
              child: pw.ClipRRect(
                horizontalRadius: 12,
                verticalRadius: 12,
                child: pw.Image(pw.MemoryImage(imageBytes), fit: pw.BoxFit.cover),
              ),
            ),
          pw.SizedBox(width: 20),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _kv('Name', patientName),
              _kv('Date', Formatters.dateTime(createdAt)),
              pw.SizedBox(height: 8),
              pw.Text('Result', style: const pw.TextStyle(fontSize: 11, color: grey)),
              pw.Text(_names[label] ?? label,
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              _kv('Confidence', Formatters.confidence(confidence)),
              pw.SizedBox(height: 10),
              pw.Text('All probabilities',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              for (final e in sorted)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 3),
                  child: pw.Row(children: [
                    pw.Expanded(child: pw.Text(_names[e.key] ?? e.key,
                        style: const pw.TextStyle(fontSize: 10))),
                    pw.Text(Formatters.confidence(e.value),
                        style: const pw.TextStyle(fontSize: 10)),
                  ]),
                ),
            ]),
          ),
        ]),
        if (info != null) ...[
          pw.SizedBox(height: 18),
          _section('About', [info.about]),
          _section('Symptoms', info.symptoms, bullets: true),
          _section('Prevention', info.prevention, bullets: true),
          _section('Treatment', info.treatment, bullets: true),
          _section('When to see a doctor', [info.seeDoctor]),
        ],
        pw.SizedBox(height: 18),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFFFF6E5),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text(
            'Disclaimer: This app is a screening aid, not a medical diagnosis. '
            'Please consult an eye specialist.',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Model: MobileNetV2 (TensorFlow Lite). Generated on device.',
            style: const pw.TextStyle(fontSize: 8, color: grey)),
      ],
    ));

    final dir = Directory('${(await getTemporaryDirectory()).path}/reports');
    if (!dir.existsSync()) await dir.create(recursive: true);
    final stamp = createdAt.millisecondsSinceEpoch;
    final file = File('${dir.path}/eye_report_$stamp.pdf');
    await file.writeAsBytes(await doc.save(), flush: true);
    return file;
  }

  static pw.Widget _kv(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(text: '$k: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.TextSpan(text: v, style: const pw.TextStyle(fontSize: 11)),
          ]),
        ),
      );

  static pw.Widget _section(String title, List<String> lines, {bool bullets = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          for (final l in lines)
            pw.Text(bullets ? '-  $l' : l, style: const pw.TextStyle(fontSize: 10)),
        ]),
      );
}
