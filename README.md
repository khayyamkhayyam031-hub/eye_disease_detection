# Eye Disease Detection (Flutter)

On-device AI screening of retina (fundus) images for **Cataract, Diabetic Retinopathy, Glaucoma, Normal**, with a `not_fundus` class + confidence threshold to reject non-retina photos. Implements `PRD.md`, `UI_UX.md`, `architecture.md` and `Testing.md`.

> Screening and awareness aid only — **not** a medical diagnosis.

## Run

```bash
flutter pub get
cp env.example.json env.json        # fill in your Supabase URL + anon key
flutter run --dart-define-from-file=env.json
```

Without `env.json` the app still starts; Login/Register show a "not configured" message.

### Release build (APK ≤ 20 MB)

```bash
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64 --dart-define-from-file=env.json
# or for Play Store:
flutter build appbundle --release --dart-define-from-file=env.json
```

Check sizes in `build/app/outputs/flutter-apk/` (each per-ABI APK must be ≤ 20 MB).

## Supabase setup (one time)

1. Create a project at supabase.com.
2. SQL Editor → run [`supabase/schema.sql`](supabase/schema.sql) (history table + RLS + private `scans` bucket).
3. Authentication → Email: enable **Confirm email**; in the **Confirm signup** and **Reset password** templates include `{{ .Token }}` so users receive a 6-digit code.
4. Put the project URL and anon/publishable key in `env.json`. Never put the `service_role` key in the app.

## Architecture

| Layer | Files |
|---|---|
| UI (screens) | `lib/ui/auth/*` (login, register, OTP, forgot password), `lib/ui/screens/*` (splash, onboarding, dashboard, preview/crop, result, history, history detail, library, statistics, profile, settings, about, disclaimer, help) |
| State | `provider` + `ChangeNotifier` repositories |
| Data | `AuthRepository` (Supabase Auth, encrypted session via `SecureSessionStorage`), `HistoryRepository` (local-first JSON + images per user, background sync/upload queue, optimistic delete with Undo), `DiseaseInfoRepository`, `SettingsRepository` |
| ML | `lib/ml/preprocess.dart` (pure Dart, background isolate), `lib/ml/eye_classifier.dart` → native `TfliteChannel.kt` (one shared LiteRT interpreter, CPU/XNNPACK, own thread, preload + warm-up) |
| Utils | `ImageUtils` (EXIF fix, max 1024 px, JPEG 90, rotate/crop), `PdfReport` (PDF + share sheet), `Formatters`/`Validators` |

**Preprocessing** follows `assets/model/model_config.json` exactly (parity with Colab):
EXIF rotate → RGB → downscale to max 448 (bilinear) → crop dark border → pad to square (black) → resize 224 (bilinear) → float32 **raw 0–255** → optional horizontal-flip TTA (averaged).

**Reject rule:** top class = `not_fundus` **or** confidence < `min_confidence` (0.60 from config; 0.70 if the config is missing) → "Please upload a clear fundus image", not saved to History.

### Size and speed choices
- TFLite runs through a ~150-line Kotlin bridge on LiteRT (no `tflite_flutter`, no GPU delegate).
- One model (FP16, 5 MB). For extra headroom swap in `eye_disease_model_int8.tflite` and change `model_file` in `model_config.json`.
- R8 + resource shrinking, per-ABI APKs (arm64-v8a, armeabi-v7a), vector icons, no bundled fonts, charts drawn with `CustomPainter`, PDFs with the pure-Dart `pdf` package, Maps via intent.
- Heavy work (decode, preprocess, inference, JSON, file IO) never runs on the UI thread.

## Tests

```bash
flutter test
```

`test/unit_test.dart` covers Testing.md UT-01…UT-13 and UT-17 (preprocessing, reject rule, labels/config, validators, date/confidence formatting, disease info), plus auth error mapping and history serialisation. Device/instrumented and manual cases (IT-*, TC-*) are run from Testing.md on real phones.

## Notes / deviations
- Backend follows `architecture.md` (Supabase); PRD's Firebase + Room alternative was not used.
- Urdu UI strings are included; disease content and the PDF report are English (the default PDF font has no Urdu glyphs, and bundling a Nastaliq font would cost several MB).
- Checkup reminders (optional M23) are not implemented.
