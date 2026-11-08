# Product Requirements Document (PRD)
## Eye Disease Detection App (Android, Java + XML)

| Field | Value |
|---|---|
| Product | Eye Disease Detection App |
| Platform | Android (Java + XML), min SDK 24 (Android 7.0) |
| AI model | MobileNetV2 → TensorFlow Lite (`eye_disease_model_fp16.tflite`) |
| App size limit | **Release APK ≤ 20 MB** (hard limit) |
| Performance | **Fastest rendering, smooth 60 fps, no lag / jank / freeze**; all heavy work in the background (AJAX-style) |
| Owner | Khayyam (Kohsar University Murree) |
| Version | 1.0 |
| Date | October 2026 |
| Status | Final, ready for development |

---

## 1. Overview

The Eye Disease Detection App lets a user capture or choose a **retina (fundus) image** and get an on-device AI prediction for four classes: **Cataract, Diabetic Retinopathy, Glaucoma, Normal**. A fifth class, **`not_fundus`**, together with a **confidence threshold**, lets the app reject images that are not retina images (a hand, a face, a random object).

With every prediction the app shows a **confidence score**, probabilities for all classes, and **disease information** (about, symptoms, prevention, treatment, when to see a doctor). Results are saved to **History** with date and time, and the user can delete them. The app has full user accounts: **Register, OTP/verification, Login, Forgot Password, Logout**.

The whole app must stay **small and lightweight: the release APK must not exceed 20 MB.**

The app must also feel **instant and smooth**: every screen opens fast, every tap responds immediately, and there is **no lag, stutter (jank) or freezing** anywhere. Like AJAX on the web, the screen never waits or locks up: heavy work (AI model, images, database, network) always runs in the background, and the screen updates as soon as the result is ready.

> **Medical disclaimer:** The app is a screening and awareness aid. It is **not** a medical diagnosis and does not replace an eye specialist.

---

## 2. Problem Statement

Eye diseases such as diabetic retinopathy, glaucoma and cataract can cause vision loss if they are found late. Many people do not have quick access to an eye specialist. A simple, lightweight mobile tool that screens fundus images, explains the result in plain language and encourages a doctor visit can help with early awareness, even on low-end phones with limited storage and slow internet.

---

## 3. Goals and Non-Goals

### 3.1 Goals
- **G1.** Predict the class of a fundus image on the device (offline) in about 1 second or less on a mid-range phone.
- **G2.** Show the result clearly with a confidence score and per-class probabilities.
- **G3.** Reject non-retina images instead of giving a misleading disease result.
- **G4.** Give understandable information: symptoms, prevention, treatment, when to see a doctor.
- **G5.** Keep a personal, deletable history of scans with date and time.
- **G6.** Provide secure accounts (register, verify, login, reset password, logout).
- **G7.** Keep the app lightweight: **release APK ≤ 20 MB**.
- **G8.** Make every functionality **fast and smooth**: quick startup, instant screen changes, 60 fps scrolling and animations, no lag, no freeze, no ANR (see Section 11).

### 3.2 Non-Goals (v1.0)
- Clinical diagnosis, prescriptions or treatment plans.
- Detecting diseases from normal (non-fundus) phone photos of the eye.
- Doctor or admin portal, telemedicine or chat.
- Cloud model inference (the model runs on the device only).
- iOS version.

---

## 4. Target Users and Personas

| Persona | Description | Needs |
|---|---|---|
| **Student / researcher** | Studies AI in healthcare; demonstrates the project | Clear results, model info, statistics |
| **Health worker / optometry assistant** | Has access to fundus images from a fundus camera or adapter | Fast screening, history, shareable report |
| **Patient / family member** | Has fundus images from a clinic visit; may use a low-end phone | Simple language, small app, prevention and treatment info, when to see a doctor |

---

## 5. Scope

### 5.1 MVP (v1.0, Must have)
Splash · Register · OTP Verification · Login · Forgot Password · Dashboard · Image Capture (Camera/Gallery) · Prediction & Result · Disease Information · History (with delete) · Disclaimer & Privacy · Logout

### 5.2 v1.1 (Should have)
Onboarding · Image Preview/Crop · History Detail · Profile & Change Password · Disease Library · Statistics · PDF Report & Share · Settings (dark mode, language) · About / Model Info

### 5.3 Later (Optional)
Nearby Eye Doctors · Checkup Reminder · Help/FAQ & Feedback · No Internet screen

> Every feature (including v1.1 and optional ones) must fit inside the 20 MB APK limit. A feature that would push the APK over 20 MB must be redesigned or dropped.

---

## 6. Assumptions and Decisions

| # | Decision / Assumption | Alternative |
|---|---|---|
| A1 | **Firebase Authentication** for register/login/reset | Supabase Auth |
| A2 | OTP step = **Firebase email verification link** by default; **Phone OTP (SMS)** optional | Supabase 6-digit email OTP via REST |
| A3 | **History stored locally with Room (SQLite)**, per user (`user_id`) | Firestore for cross-device sync |
| A4 | Images are stored in the app's **private storage**, not uploaded | Firebase/Supabase Storage |
| A5 | Model input = float32 `[1,224,224,3]`, **raw 0–255** (normalization inside the model) | n/a |
| A6 | Label order = `cataract, diabetic_retinopathy, glaucoma, normal, not_fundus` | n/a |
| A7 | Reject threshold read from `model_config.json` (`min_confidence`) | Hard-coded 0.70 |
| A8 | **Only one model file** is bundled (FP16); INT8 is used instead if the size budget requires it | n/a |
| A9 | **Release APK ≤ 20 MB** is a hard requirement | n/a |

---

## 7. User Stories and Acceptance Criteria

### M1. Splash Screen
**Story:** As a user, I want to see the app logo when it starts, so I know the app is loading.
- **AC1:** Splash shows logo + app name only while startup work runs: **minimum 1 s, maximum 2 s** (no artificial long delay). Uses the Android SplashScreen API.
- **AC2:** Logged-in user → Dashboard; first launch → Onboarding; otherwise → Login.
- **AC3:** Back button cannot return to the splash.

### M2. Onboarding (v1.1)
**Story:** As a new user, I want a short intro so I understand how to use the app and what a fundus image is.
- **AC1:** 2–3 slides with Skip and Get Started.
- **AC2:** Shown only once (first launch).
- **AC3:** Slide illustrations are vector drawables or compressed WebP (size budget).

### M3. Register
**Story:** As a new user, I want to create an account with my name, email and password.
- **AC1:** Validation: all fields required; valid email; password ≥ 6 characters (recommended 8+); passwords match.
- **AC2:** Disclaimer checkbox must be accepted before registering.
- **AC3:** On success, the verification/OTP step starts.
- **AC4:** Clear errors: email already in use, weak password, no internet.

### M4. OTP Verification
**Story:** As a new user, I want to verify my email/phone so my account is secure.
- **AC1:** Screen shows where the link/code was sent.
- **AC2:** Resend button is disabled for 60 seconds with a countdown.
- **AC3:** After verification, the Dashboard opens.
- **AC4:** Unverified users cannot reach the Dashboard.

### M5. Login
**Story:** As a registered user, I want to log in with email and password.
- **AC1:** Correct details + verified account → Dashboard.
- **AC2:** Wrong password / unknown user / unverified email → specific error message.
- **AC3:** Session persists until Logout.

### M6. Forgot Password
**Story:** As a user who forgot the password, I want to reset it by email.
- **AC1:** Valid registered email → reset link/OTP sent, success message shown.
- **AC2:** Unknown email → friendly message (do not reveal too much detail).

### M7. Dashboard
**Story:** As a logged-in user, I want one home screen with all main actions.
- **AC1:** Shows heading "Eye Disease Detection" and a welcome with the user's name.
- **AC2:** Buttons: Camera, Gallery, Predict, History, Logout (+ v1.1 cards).
- **AC3:** Predict is disabled until an image is selected.
- **AC4:** Selected image shown in a preview area.

### M8. Image Capture
**Story:** As a user, I want to take a photo or pick one from the gallery.
- **AC1:** Camera asks for permission; if denied, show an explanation and a Settings link.
- **AC2:** Gallery uses the system picker (no storage permission needed on modern Android).
- **AC3:** EXIF rotation is corrected.

### M9. Image Preview / Crop (v1.1)
- **AC1:** User can crop/rotate, retake, or confirm.
- **AC2:** Prefer a built-in rotate/crop implementation over a heavy third-party library (size budget).

### M10. Prediction & Result
**Story:** As a user, I want to see what the model predicts and how confident it is.
- **AC1:** Inference runs off the main thread; a loader appears within 100 ms; the model is already preloaded and warmed up, so the result appears in ≤ 1 s and the screen never freezes.
- **AC2:** Result shows: class name, confidence % (1 decimal), probability bars for all classes.
- **AC3:** **Reject rule:** if top class = `not_fundus` OR confidence < `min_confidence` → show "Please upload a clear fundus (retina) image" and do **not** save to History.
- **AC4:** Accepted results are saved to History automatically with date/time.
- **AC5:** Disclaimer is always visible on the Result screen.
- **AC6:** App prediction for the same image matches the Colab prediction (same class).

### M11. Disease Information
**Story:** As a user, I want to understand the predicted disease and what to do next.
- **AC1:** Sections: About, Symptoms, Prevention, Treatment, When to see a doctor.
- **AC2:** Content loaded from `assets/disease_info.json`, reviewed from reliable medical sources.
- **AC3:** For **Normal**, show healthy-eye tips and regular checkup advice.

### M12. History
**Story:** As a user, I want to see my past scans and delete any of them.
- **AC1:** List newest first: thumbnail, class, confidence, date and time (e.g. "12 Oct 2026, 3:45 PM").
- **AC2:** Delete one item with a confirmation dialog; image file also deleted.
- **AC3:** Clear All with confirmation.
- **AC4:** Empty state when there is no history.
- **AC5:** A user only sees their own history.
- **AC6:** History opens in ≤ 300 ms and scrolls smoothly at 60 fps even with 500+ records; a deleted item disappears instantly (≤ 100 ms).

### M13. History Detail (v1.1)
- **AC1:** Shows saved image, result, probabilities, date/time, disease info, Share and Delete.

### M14. Profile & Change Password (v1.1)
- **AC1:** Edit name; change password with re-authentication.

### M15. Disease Library (v1.1)
- **AC1:** Cards for all four classes; detail page uses the same JSON content.

### M16. Statistics (v1.1)
- **AC1:** Total scans, pie chart by class, bar chart by month.
- **AC2:** Use a lightweight chart library (or simple custom views) within the size budget.

### M17. PDF Report & Share (v1.1)
- **AC1:** PDF includes image, result, confidence, date/time, disclaimer; shared via Android share sheet.
- **AC2:** Built with Android's built-in `PdfDocument` (no extra library).

### M18. Settings (v1.1)
- **AC1:** Dark mode, language (English/Urdu), notifications, clear history; values remembered.
- **AC2:** Urdu font is not bundled if it is large; use a system font or Android downloadable fonts.

### M19. About / Model Info (v1.1)
- **AC1:** App version, model name, test accuracy, classes, developer.

### M20. Disclaimer & Privacy
- **AC1:** Must be accepted on registration/first use; readable later from Settings.

### M21. Logout
- **AC1:** Confirmation dialog; on Yes → sign out, open Login, clear back stack.

### Optional (M22–M25)
Nearby Eye Doctors (Google Maps **intent**, no Maps SDK, to save size) · Checkup Reminder (WorkManager notification) · Help/FAQ & Feedback · No Internet screen (auth screens only; prediction works offline).

---

## 8. Functional Requirements

| ID | Requirement | Module | Priority |
|---|---|---|---|
| FR-01 | Route from splash based on session / first launch | M1 | Must |
| FR-02 | Register with name, email, password; validation | M3 | Must |
| FR-03 | Verify account (link or OTP) before Dashboard access | M4 | Must |
| FR-04 | Login with email + password; persistent session | M5 | Must |
| FR-05 | Password reset by email | M6 | Must |
| FR-06 | Capture image with camera / pick from gallery | M8 | Must |
| FR-07 | Run TFLite model on device; return 5 probabilities | M10 | Must |
| FR-08 | Apply reject rule (`not_fundus` or low confidence) | M10 | Must |
| FR-09 | Show class, confidence, all probabilities | M10 | Must |
| FR-10 | Show about/symptoms/prevention/treatment/when to see doctor | M11 | Must |
| FR-11 | Save accepted results with timestamp per user | M12 | Must |
| FR-12 | List, delete one, and clear all history | M12 | Must |
| FR-13 | Disclaimer acceptance and display | M20 | Must |
| FR-14 | Logout and clear back stack | M21 | Must |
| FR-15 | Crop/rotate before prediction | M9 | Should |
| FR-16 | History detail view | M13 | Should |
| FR-17 | Edit profile, change password | M14 | Should |
| FR-18 | Disease library | M15 | Should |
| FR-19 | Statistics charts | M16 | Should |
| FR-20 | PDF report and share | M17 | Should |
| FR-21 | Dark mode and Urdu language | M18 | Should |
| FR-22 | About / model info | M19 | Should |

---

## 9. Non-Functional Requirements

| ID | Category | Requirement |
|---|---|---|
| NFR-01 | Performance | Cold start ≤ 1.5 s; every screen opens in ≤ 300 ms; inference ≤ 1 s on a mid-range phone (full targets in Section 11) |
| NFR-02 | Offline | Prediction, disease info and History work without internet |
| NFR-03 | **App size** | **Release APK ≤ 20 MB (hard limit).** Checked on every release build; a build over 20 MB fails the release |
| NFR-04 | Compatibility | Android 7.0 (API 24) and above; phones 5"–7" |
| NFR-05 | Reliability | No crash on denied permissions, corrupt images, or no internet |
| NFR-06 | Security | Passwords handled only by Firebase; no secrets hard-coded; history scoped by `user_id` |
| NFR-07 | Privacy | Images stay on the device; user can delete any record; privacy policy available |
| NFR-08 | Usability | Main flow (open → result) in ≤ 4 taps; clear error messages |
| NFR-09 | Accessibility | Touch targets ≥ 48dp; text contrast ≥ 4.5:1; content descriptions on icons; supports font scaling |
| NFR-10 | Localization | All text in `strings.xml`; Urdu support in v1.1 |
| NFR-11 | Storage use | Saved scan images compressed (JPEG ~90%, max side 1024px) so History does not fill the phone |
| NFR-12 | Smoothness | 60 fps rendering; janky frames < 5%; no visible lag or stutter on any screen |
| NFR-13 | Responsiveness | Visual feedback for every tap within 100 ms; main thread never blocked > 100 ms; **zero ANRs** |

---

## 10. App Size Requirement (≤ 20 MB)

### 10.1 Size Budget (estimates, to be verified with Android Studio **Build → Analyze APK**)

| Part | Estimated size | Notes |
|---|---|---|
| TFLite model (FP16) | ~5 MB | Use INT8 (~3 MB) if the total is too close to 20 MB |
| TensorFlow Lite runtime (native libs) | ~2–4 MB | Depends on CPU architectures included |
| Firebase Authentication | ~2–3 MB | Only `firebase-auth`; no other Firebase products |
| AndroidX + Material Components | ~2–3 MB | After R8 shrinking |
| Room, Gson, other small libs | ~1 MB | |
| App code, layouts, strings, JSON | < 1 MB | |
| Images and icons | < 1 MB | Vector drawables / WebP |
| **Target total** | **~14–18 MB** | Leaves a safety margin under 20 MB |

### 10.2 Rules to Stay Under 20 MB
1. **Enable R8:** `minifyEnabled true` and `shrinkResources true` in release builds (with keep rules for TFLite, Room and Gson).
2. **Bundle only one model:** FP16 by default; switch to INT8 if needed. Never ship both.
3. **Limit CPU architectures:** include only `arm64-v8a` and `armeabi-v7a` (drop `x86`/`x86_64` from the release APK), or publish as an **Android App Bundle (AAB)** so each phone downloads only its own architecture.
4. **Images:** vector drawables for icons; WebP for illustrations; no large PNG/JPG assets.
5. **Fonts:** do not bundle large font files (e.g. Urdu Nastaliq fonts can be several MB); use system fonts or downloadable fonts.
6. **Libraries:** avoid heavy libraries. Use Android's built-in `PdfDocument` for PDFs; Google Maps **intent** instead of the Maps SDK; a built-in rotate/crop instead of a crop library where possible; only `firebase-auth` from Firebase.
7. **Resources:** `resConfigs "en", "ur"` to remove unused language resources from libraries.
8. **Check every release:** run Analyze APK; if the APK is over 20 MB, find the biggest part and reduce it before release.

---

## 11. Performance & Smoothness Requirements (Fastest, No Lag)

**Principle (AJAX-style):** the screen never freezes or waits. Every screen appears immediately, heavy work runs in the background, and the UI updates as soon as the result is ready. Every functionality must work at full speed with **no lag, jank (stutter), freeze or ANR**.

### 11.1 Performance Targets

| ID | Area | Target (mid-range phone) | Low-end phone |
|---|---|---|---|
| PF-01 | Cold start (tap icon → first screen drawn) | ≤ 1.5 s | ≤ 2.5 s |
| PF-02 | Warm start (app reopened from background) | ≤ 0.5 s | ≤ 1 s |
| PF-03 | Screen open (tap → next screen visible) | ≤ 300 ms | ≤ 500 ms |
| PF-04 | Touch feedback (ripple / loader / button state) | ≤ 100 ms | ≤ 100 ms |
| PF-05 | Rendering | 60 fps, frame time ≤ 16 ms, janky frames < 5% | janky frames < 10% |
| PF-06 | First prediction (model already preloaded) | ≤ 1 s | ≤ 2 s |
| PF-07 | Next predictions (inference only) | ≤ 300 ms | ≤ 1 s |
| PF-08 | History screen open (100 records) | ≤ 300 ms | ≤ 500 ms |
| PF-09 | History scroll (500+ records) | Smooth 60 fps | No visible stutter |
| PF-10 | Delete / Undo reflected in the list | ≤ 100 ms | ≤ 100 ms |
| PF-11 | Login / Register network call | Loader instantly; timeout 15 s with friendly retry | Same |
| PF-12 | Main-thread blocking | Never > 100 ms | Never > 100 ms |
| PF-13 | ANRs and crashes | 0 | 0 |
| PF-14 | Memory | No leaks; no OutOfMemory errors | Same |

### 11.2 Engineering Rules (how the app stays fast)

1. **Nothing heavy on the main thread.** TFLite inference, image decode/resize/save, Room queries, JSON parsing, PDF creation and file deletes all run on background executors (`AppExecutors`). StrictMode is enabled in debug builds to catch mistakes.
2. **Asynchronous, AJAX-style UI.** MVVM with ViewModel + LiveData: a screen opens instantly with a loader or placeholder, and data fills in when ready. Screens never wait for data before showing.
3. **Preload and warm up.** Right after the first screen is drawn, the app loads in the background: the TFLite model (memory-mapped), `labels.txt`, `model_config.json` and `disease_info.json`, and runs one dummy inference, so the user's first Predict is fast.
4. **Reuse expensive objects.** One shared TFLite Interpreter for the whole app (2–4 CPU threads, XNNPACK built-in), reused input buffers, cached disease info. Nothing is re-created per prediction. The GPU delegate is **not** used, because it adds several MB (20 MB rule).
5. **Light images.** Decode with bounds + `inSampleSize` (never full-resolution bitmaps); saved images max 1024px; history thumbnails ~128px, loaded in the background and cached in memory (`LruCache`).
6. **Fast lists.** RecyclerView + `ListAdapter`/`DiffUtil` (only changed rows redraw), ViewHolder pattern, stable IDs; load history in pages (LIMIT/OFFSET) when it is very large.
7. **Flat, light layouts.** ConstraintLayout instead of deep nesting, no nested weights, ViewBinding, vector icons, no unnecessary backgrounds (low overdraw).
8. **Fast database.** Room indexes on `user_id` and `created_at`; all queries asynchronous through LiveData.
9. **Fast startup.** No heavy work in `Application.onCreate()`; Firebase and other services initialized lazily; Android SplashScreen API with no artificial delay beyond the 1–2 s brand display; **Baseline Profile** (`androidx.profileinstaller`) for faster startup and scrolling.
10. **Optimistic UI.** Delete removes the item from the list instantly (with Undo); the database work happens in the background.
11. **No double work.** Buttons are disabled while their action runs; double taps are ignored; only one prediction runs at a time.
12. **Smooth animations.** Only short Material transitions (250–300 ms); no heavy animations; respect the system "Remove animations" setting.
13. **Release optimization.** R8 full optimization in release builds (also helps the 20 MB size limit).
14. **Size-friendly.** All performance techniques above add almost nothing to the APK size, so they work together with the 20 MB rule.

### 11.3 How Performance Is Measured

- Android Studio **Profiler** (CPU, memory, energy) on real low-end and mid-range phones.
- **Profile HWUI rendering** (Developer options) for frame times / janky frames.
- **Macrobenchmark** (test-only) for cold/warm startup and History scrolling.
- **StrictMode** (debug) for main-thread disk/network access.
- **LeakCanary** (debug only, not in release, so no size impact) for memory leaks.
- Every release must meet PF-01 to PF-14 (see `Testing.md`).

---

## 12. ML Model Requirements

| Item | Requirement |
|---|---|
| Model | MobileNetV2 (transfer learning, fine-tuned) exported as TFLite FP16 |
| Classes | cataract, diabetic_retinopathy, glaucoma, normal, not_fundus |
| Input | float32 `[1,224,224,3]`, RGB, raw 0–255 |
| Output | 5 softmax probabilities (label order above) |
| Accuracy target | Test accuracy ≥ 90% (to be confirmed after the final Colab run) |
| Reject rule | `not_fundus` or confidence < `min_confidence` from `model_config.json` |
| Parity | TFLite result must match the Keras/Colab result for the same image |
| Model size | ≤ 6 MB (FP16), or ≤ 3.5 MB (INT8) if the size budget needs it |
| Files in app | `eye_disease_model_fp16.tflite` (or INT8), `labels.txt`, `model_config.json` |

---

## 13. Content Requirements

- `assets/disease_info.json` with one entry per class: `title`, `about`, `symptoms[]`, `prevention[]`, `treatment[]`, `see_doctor`.
- Content written in simple language and checked against reliable medical sources (e.g. WHO, national eye institutes).
- Disclaimer and privacy policy text.

---

## 14. Success Metrics

| Metric | Target |
|---|---|
| Model test accuracy (MobileNetV2) | ≥ 90% |
| Non-fundus images correctly rejected (test set) | ≥ 90% |
| Inference time (mid-range phone) | ≤ 1 s |
| **Release APK size** | **≤ 20 MB** |
| **Cold start (mid-range)** | **≤ 1.5 s** |
| **Janky frames** | **< 5% (60 fps)** |
| **ANRs** | **0** |
| Crash-free sessions in testing | 100% of test cases |
| Main flow completion in usability test | ≥ 90% of testers without help |

---

## 15. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Users upload normal eye/selfie photos | Misleading results | `not_fundus` class + threshold + Image Guide + Onboarding |
| Model accuracy lower than target | Weak results | More epochs/FULL mode, higher resolution, more data |
| App vs Colab results differ | Wrong predictions | Same resize, RGB order, 0–255 input; parity tests |
| **APK grows above 20 MB** | Requirement failed | Size budget, R8 + shrinkResources, one model only, INT8 option, ABI filters/AAB, no heavy libraries or fonts, Analyze APK on every release |
| **App feels slow or laggy** | Bad user experience | Section 11 rules: background threads, preloaded model, DiffUtil lists, light images, Baseline Profile; measure with Profiler and Macrobenchmark before every release |
| Firebase phone OTP needs billing | Blocked feature | Use email verification link (free) |
| Medical misunderstanding | User harm | Disclaimer everywhere, "see a doctor" advice |
| Large images cause memory errors | Crash | Downscale on load; handle exceptions |

---

## 16. Open Questions

1. OTP type: email link (default), phone SMS OTP, or 6-digit email code (Supabase)?
2. Should history sync to the cloud (Firestore), or stay on the device only?
3. Is Urdu language required in v1.0 or v1.1?
4. Will the app be published on Google Play (AAB, privacy policy URL, health app declarations), or shared as an APK?

---

## 17. Milestones

| # | Milestone | Contents |
|---|---|---|
| 1 | Setup | Project, dependencies, assets, permissions, R8 + size settings, AppExecutors + StrictMode, EyeClassifier test with preload/warm-up |
| 2 | Auth | Splash, Register, OTP, Login, Forgot Password |
| 3 | Core | Dashboard, Camera/Gallery, Prediction & Result, Disease Info |
| 4 | History | Room DB, History list, delete, History Detail |
| 5 | Polish | Logout, Profile, Disclaimer, Settings, About |
| 6 | Extras | Library, Statistics, PDF, optional modules (only if they fit the size budget) |
| 7 | Testing & Release | Full test pass (see `Testing.md`), **performance check (PF-01 to PF-14)**, **APK size check ≤ 20 MB**, signed release |
