# Testing Plan
## Eye Disease Detection App (Android, Java + XML)

---

## 1. Purpose and Scope

This plan describes how the app is tested before release: the ML model, every module (M1–M25), performance, security, accessibility and regression. Each test case has an ID, steps and expected result, so results can be recorded and reported (for example in the project report).

**In scope:** all MVP and v1.1 modules, TFLite model behaviour, Room database, Firebase Authentication flows.
**Out of scope:** clinical validation of the model (the app is a screening aid, not a medical device).

---

## 2. Test Levels

| Level | What | Tools |
|---|---|---|
| **Model tests** | Accuracy, reject rule, Keras vs TFLite parity | Colab notebook (Steps 31–46) |
| **Unit tests** | Pure Java logic: preprocessing, reject rule, validators, date formatting, ViewModels with fake repositories | JUnit 4/5, Mockito |
| **Instrumented tests** | Room DAO (in-memory DB), EyeClassifier with real model on device, file storage | AndroidX Test, JUnit |
| **UI tests** | Screen flows, buttons, dialogs, navigation | Espresso, (optional) UI Automator for camera/permission dialogs |
| **Manual tests** | Full user flows on real phones, camera, look and feel | Test cases below |
| **Non-functional** | Performance, memory, offline, accessibility, security | Android Studio Profiler, Accessibility Scanner, TalkBack |

---

## 3. Test Environment

| Item | Details |
|---|---|
| Devices | At least 3 phones: low-end (2–3 GB RAM), mid-range, recent flagship; plus an emulator |
| Android versions | API 24 (7.0), API 29 (10), API 33+ (13/14) |
| Screen sizes | Small (~5"), normal (~6.1"), large (~6.7") |
| Network | Wi-Fi, mobile data, airplane mode |
| Accounts | 2 test accounts (to check history separation), 1 unverified account |
| Test images | See Section 4.2 |

---

## 4. Model Testing

### 4.1 Model Acceptance Criteria

| ID | Check | Target | Where |
|---|---|---|---|
| ML-01 | MobileNetV2 test accuracy (Keras) | ≥ 90% | Colab Step 31 |
| ML-02 | Per-class accuracy | No class below 80% | Colab per-class chart |
| ML-03 | not_fundus rejection rate (test) | ≥ 90% | Colab Step 40 |
| ML-04 | Accepted-image accuracy at threshold | ≥ 93% | Colab Step 40 |
| ML-05 | TFLite FP16 accuracy vs Keras | Drop ≤ 1% | Colab Step 45 |
| ML-06 | App vs Colab parity (same 20 images) | Same class for all 20; confidence within ±2% | Manual (Section 4.3) |

### 4.2 Test Image Set (keep in a folder on the phone)

| Group | Count | Source | Expected |
|---|---|---|---|
| A. Dataset test images (each class) | 5 per class (20) | Kaggle dataset, from the test split | Correct class, mostly high confidence |
| B. Internet fundus images | 10 | Google search "fundus image <disease>" | Mostly correct; some may be rejected (low confidence) |
| C. Normal eye photos (selfie/close-up) | 10 | Phone camera | Rejected or low confidence (known weak area) |
| D. Non-eye photos (hand, face, object, text) | 10 | Phone camera | **Rejected** (not_fundus) |
| E. Edge cases (blurry, dark, very small, screenshot, black image) | 10 | Created | Rejected or error message, **no crash** |

### 4.3 Parity Test Procedure (App vs Colab)
1. Pick 20 images (Group A).
2. In Colab, run **Step 46 (Upload & Predict)** and note class and confidence.
3. Copy the same images to the phone and predict in the app.
4. Record both in a table; classes must match and confidence must differ by ≤ 2%.
5. If they differ, check: RGB order, resize method (bilinear 224×224), EXIF rotation, and that the app does **not** divide by 255.

---

## 5. Unit Test Cases

| ID | Component | Test | Expected |
|---|---|---|---|
| UT-01 | Preprocess | 224×224 red bitmap → buffer | Buffer size 224×224×3 floats; first pixel = (255, 0, 0) |
| UT-02 | Preprocess | Non-square bitmap | Resized to 224×224, no exception |
| UT-03 | Reject rule | Top = glaucoma 0.92, threshold 0.70 | ACCEPTED, glaucoma |
| UT-04 | Reject rule | Top = normal 0.55, threshold 0.70 | REJECTED |
| UT-05 | Reject rule | Top = not_fundus 0.95 | REJECTED |
| UT-06 | Reject rule | Confidence exactly = threshold | ACCEPTED (≥ rule), as documented |
| UT-07 | Labels | labels.txt has 5 lines in correct order | Index 4 = not_fundus |
| UT-08 | ModelConfig | Parse model_config.json | Threshold and labels read correctly; missing file → default 0.70 |
| UT-09 | Validator | Email "abc" / "a@b.com" | Invalid / valid |
| UT-10 | Validator | Password "12345" / "123456" | Invalid / valid |
| UT-11 | Validator | Password ≠ confirm | Error "Passwords do not match" |
| UT-12 | DateUtils | Epoch → display text | "12 Oct 2026, 3:45 PM" format |
| UT-13 | Confidence format | 0.92437 → "92.4%"; 0.9999 → "99.9%" | Correct, capped at 99.9% |
| UT-14 | AuthViewModel | Fake repo returns error | LiveData = ERROR with friendly message |
| UT-15 | ResultViewModel | Fake classifier ACCEPTED | History insert called once |
| UT-16 | ResultViewModel | Fake classifier REJECTED | History insert **not** called |
| UT-17 | DiseaseInfoRepository | Load JSON | 4 classes, each with all sections non-empty |

---

## 6. Instrumented Test Cases

| ID | Component | Test | Expected |
|---|---|---|---|
| IT-01 | Room DAO | Insert 3 rows, getAllForUser | 3 rows, newest first |
| IT-02 | Room DAO | Rows for user A and B | Each user sees only their rows |
| IT-03 | Room DAO | deleteById | Row removed; others remain |
| IT-04 | Room DAO | deleteAllForUser(A) | A empty; B unchanged |
| IT-05 | Room DAO | countByLabel | Correct counts per label |
| IT-06 | HistoryRepository | Delete record | Row and image file deleted |
| IT-07 | EyeClassifier | Load model from assets | No exception; input [1,224,224,3], output [1,5] |
| IT-08 | EyeClassifier | Known test image (each class) | Same class as Colab |
| IT-09 | EyeClassifier | Black image / noise | REJECTED |
| IT-10 | EyeClassifier | 50 predictions in a row | No memory growth / crash |
| IT-11 | ImageUtils | Camera photo with EXIF rotation 90° | Saved bitmap is upright |

---

## 7. Functional / Manual Test Cases (by Module)

**Legend:** P = Pass, F = Fail, B = Blocked (fill the Result column during testing).

### M1. Splash
| ID | Steps | Expected | Result |
|---|---|---|---|
| TC-SP-01 | Fresh install, open app | Splash 1–2 s → Onboarding | |
| TC-SP-02 | Logged-in verified user opens app | Splash → Dashboard | |
| TC-SP-03 | Logged-out user opens app | Splash → Login | |
| TC-SP-04 | Press Back on next screen | App does not return to Splash | |

### M2. Onboarding
| ID | Steps | Expected | Result |
|---|---|---|---|
| TC-OB-01 | Swipe all slides, Get Started | Login opens | |
| TC-OB-02 | Tap Skip | Login opens | |
| TC-OB-03 | Reopen app | Onboarding not shown again | |

### M3. Register
| ID | Steps | Expected | Result |
|---|---|---|---|
| TC-RG-01 | Submit with empty fields | "This field is required" on each | |
| TC-RG-02 | Invalid email | Email error | |
| TC-RG-03 | Password < 6 chars | Password error | |
| TC-RG-04 | Passwords don't match | Mismatch error | |
| TC-RG-05 | Disclaimer not checked | Cannot register; message shown | |
| TC-RG-06 | Valid data | Account created → OTP/verification screen | |
| TC-RG-07 | Already registered email | "Email already in use" | |
| TC-RG-08 | No internet | No-internet message, no crash | |

### M4. OTP / Verification
| ID | Steps | Expected | Result |
|---|---|---|---|
| TC-OT-01 | Open screen after register | Shows masked email/phone | |
| TC-OT-02 | Resend immediately | Disabled with countdown 60 s | |
| TC-OT-03 | Verify with link, tap "I've verified" | Dashboard opens | |
| TC-OT-04 | Tap verify without verifying | "Not verified yet" message | |
| TC-OT-05 | (Code mode) wrong code | Error, can retry | |
| TC-OT-06 | (Code mode) correct code | Dashboard opens | |
| TC-OT-07 | Unverified user tries to log in | Blocked with resend option | |

### M5. Login
| ID | Steps | Expected | Result |
|---|---|---|---|
| TC-LG-01 | Correct email/password | Dashboard | |
| TC-LG-02 | Wrong password | "Email or password is incorrect" | |
| TC-LG-03 | Unknown email | Friendly error | |
| TC-LG-04 | Kill and reopen app | Still logged in | |
| TC-LG-05 | Double-tap Login quickly | Only one request; button shows loader | |

### M6. Forgot Password
| ID | Steps | Expected | Result |
|---|---|---|---|
| TC-FP-01 | Registered email | Success message; email received | |
| TC-FP-02 | Reset via email link, login with new password | Login works | |
| TC-FP-03 | Invalid email format | Validation error | |

### M7. Dashboard
| ID | Steps | Expected | Result |
|---|---|---|---|
| TC-DB-01 | Open Dashboard | Title, user name, all buttons visible | |
| TC-DB-02 | No image selected | Predict disabled | |
| TC-DB-03 | Select image | Preview shows image; Predict enabled | |
| TC-DB-04 | Press Back twice | Exit prompt then app closes | |
| TC-DB-05 | Rotate screen after selecting image | Image still selected | |

### M8. Image Capture
| ID | Steps | Expected | Result |
|---|---|---|---|
| TC-IC-01 | Tap Camera first time | Permission dialog | |
| TC-IC-02 | Allow, take photo | Photo appears upright in preview | |
| TC-IC-03 | Deny permission | Explanation message, no crash | |
| TC-IC-04 | Deny with "Don't ask again" | Message with Settings link | |
| TC-IC-05 | Cancel camera | Returns to Dashboard, nothing changes | |
| TC-IC-06 | Pick from Gallery | Image appears in preview | |
| TC-IC-07 | Pick a very large image (> 10 MB) | Loads without crash | |

### M9. Image Preview / Crop
| ID | Steps | Expected | Result |
|---|---|---|---|
| TC-PV-01 | Rotate image | Image rotates 90° | |
| TC-PV-02 | Crop and Use Image | Cropped image used for prediction | |
| TC-PV-03 | Retake | Camera/Gallery opens again | |

### M10. Prediction & Result
| ID | Steps | Expected | Result |
|---|---|---|---|
| TC-PR-01 | Predict a cataract test image | Cataract shown with confidence % | |
| TC-PR-02 | Predict each class (Group A) | Correct class for most images | |
| TC-PR-03 | Probability bars | All classes shown; total about 100% | |
| TC-PR-04 | Hand / face photo (Group D) | Rejection message; not saved to History | |
| TC-PR-05 | Blurry / black image (Group E) | Rejected or error message; no crash | |
| TC-PR-06 | Accepted result | Snackbar "Saved to History"; entry appears in History | |
| TC-PR-07 | Airplane mode, predict | Works offline | |
| TC-PR-08 | Rotate during prediction | No crash; result shown once | |
| TC-PR-09 | Disclaimer | Always visible on Result | |
| TC-PR-10 | Inference time (debug) | ≤ 1 s mid-range phone | |

### M11. Disease Information
| ID | Steps | Expected | Result |
|---|---|---|---|
| TC-DI-01 | Result = Glaucoma | Glaucoma about/symptoms/prevention/treatment shown | |
| TC-DI-02 | Result = Normal | Healthy-eye tips and checkup advice | |
| TC-DI-03 | Expand/collapse sections | Works smoothly | |

### M12. History
| ID | Steps | Expected | Result |
|---|---|---|---|
| TC-HS-01 | Open after 3 predictions | 3 items, newest first, correct date/time | |
| TC-HS-02 | Delete one → Cancel | Item stays | |
| TC-HS-03 | Delete one → Delete | Item removed; Snackbar with Undo | |
| TC-HS-04 | Undo after delete | Item restored | |
| TC-HS-05 | Clear All → confirm | List empty; empty state shown | |
| TC-HS-06 | Login as user B | User A's history not visible | |
| TC-HS-07 | Kill and reopen app | History still there | |
| TC-HS-08 | 100+ records | Smooth scrolling | |

### M13. History Detail
| ID | Steps | Expected | Result |
|---|---|---|---|
| TC-HD-01 | Tap a history item | Full saved result and date/time | |
| TC-HD-02 | Delete from detail | Returns to History; item gone | |

### M14. Profile & Change Password
| ID | Steps | Expected | Result |
|---|---|---|---|
| TC-PF-01 | Edit name | Name updated on Dashboard | |
| TC-PF-02 | Change password with wrong old password | Error | |
| TC-PF-03 | Change password correctly, re-login | New password works | |

### M15–M19. Library, Statistics, PDF, Settings, About
| ID | Steps | Expected | Result |
|---|---|---|---|
| TC-LB-01 | Open Library, tap each disease | Detail page with all sections | |
| TC-ST-01 | Statistics with history | Totals and charts match History | |
| TC-ST-02 | Statistics with no history | Empty state | |
| TC-RP-01 | Share Report | PDF created with image, result, date, disclaimer; share sheet opens | |
| TC-SE-01 | Toggle dark mode | Whole app switches; persists after restart | |
| TC-SE-02 | Switch to Urdu | Texts change; layout RTL correct | |
| TC-SE-03 | Clear history from Settings | History empty | |
| TC-AB-01 | Open About | Version, model, accuracy, classes visible | |

### M20. Disclaimer & Privacy
| ID | Steps | Expected | Result |
|---|---|---|---|
| TC-DC-01 | Register without accepting | Blocked | |
| TC-DC-02 | Open from Settings | Text readable, scrolls | |

### M21. Logout
| ID | Steps | Expected | Result |
|---|---|---|---|
| TC-LO-01 | Tap Logout → Cancel | Stays on Dashboard | |
| TC-LO-02 | Tap Logout → Logout | Login screen opens | |
| TC-LO-03 | Press Back after logout | Does not return to Dashboard | |
| TC-LO-04 | Reopen app after logout | Login screen (not Dashboard) | |

### M22–M25. Optional Modules
| ID | Steps | Expected | Result |
|---|---|---|---|
| TC-ND-01 | Find Eye Doctor | Maps opens with nearby eye clinics | |
| TC-RM-01 | Set reminder (short test interval) | Notification appears | |
| TC-HP-01 | Send feedback | Email app opens with subject filled | |
| TC-NI-01 | Login in airplane mode | No-internet screen; Retry works after reconnect | |

---

## 8. Non-Functional Tests

| ID | Area | Test | Target |
|---|---|---|---|
| NF-01 | Performance | Cold start to first screen (Macrobenchmark) | ≤ 1.5 s mid-range, ≤ 2.5 s low-end |
| NF-02 | Performance | First model load | ≤ 2 s |
| NF-03 | Performance | Inference (low / mid / high phones) | ≤ 2 s / ≤ 1 s / ≤ 0.5 s |
| NF-04 | Memory | 50 predictions in a row (Profiler) | No leak, no OOM |
| NF-05 | Size | Release APK size (Android Studio → Build → Analyze APK) | **≤ 20 MB (hard limit)** |
| NF-06 | Offline | Predict, History, Library in airplane mode | All work |
| NF-07 | Battery | 20 predictions | No noticeable drain/heat |
| NF-08 | Compatibility | API 24, 29, 33+ | All MVP tests pass |
| NF-09 | Rotation | Rotate on every screen | No crash, state kept |
| NF-10 | Interruptions | Incoming call / app to background during prediction | Resumes correctly |
| NF-11 | Smoothness | Profile HWUI rendering on every screen + History scroll (500 records) | 60 fps; janky frames < 5% (mid-range) |
| NF-12 | Screen open | Tap → next screen visible (all screens) | ≤ 300 ms |
| NF-13 | Touch feedback | Ripple / loader after every tap | ≤ 100 ms |
| NF-14 | Main thread | StrictMode (debug) through full flow | No disk/network on main thread; no block > 100 ms |
| NF-15 | Warm start | Reopen app from background | ≤ 0.5 s |
| NF-16 | ANR | Full regression run + stress (fast taps, rotate, 50 predictions) | 0 ANRs |
| NF-17 | Delete speed | Delete / Undo in History | List updates ≤ 100 ms |

---

## 9. Security and Privacy Tests

| ID | Test | Expected |
|---|---|---|
| SC-01 | Check source/APK for hard-coded secrets | None (only restricted Firebase config) |
| SC-02 | User A logs out, user B logs in | B cannot see A's history |
| SC-03 | Unverified account | Cannot reach Dashboard |
| SC-04 | Delete a record | Image file removed from storage |
| SC-05 | Images location | Only in app private storage, not in the public gallery |
| SC-06 | Release build | Minified; app works (keep rules correct) |

---

## 10. Accessibility Tests

| ID | Test | Expected |
|---|---|---|
| AC-01 | Accessibility Scanner on all screens | No critical issues |
| AC-02 | TalkBack through main flow | All buttons announced; result read aloud |
| AC-03 | Font size largest | No clipped/overlapping text |
| AC-04 | Contrast check | ≥ 4.5:1 for body text |
| AC-05 | Touch targets | All ≥ 48dp |

---

## 11. Regression Checklist (run before every release)

- [ ] Fresh install → Onboarding → Register → Verify → Dashboard
- [ ] Login / Logout / Forgot Password
- [ ] Camera and Gallery → Predict (one image per class)
- [ ] Rejection works for a hand photo
- [ ] Result shows info, disclaimer, saves to History
- [ ] History delete, undo, clear all
- [ ] Offline prediction
- [ ] Dark mode and rotation
- [ ] App vs Colab parity on 5 images
- [ ] No crashes in Logcat
- [ ] Release APK size ≤ 20 MB (Analyze APK)
- [ ] Performance targets PF-01 to PF-14 met (no lag, 60 fps, 0 ANR)

---

## 12. Bug Report Template

```
Bug ID:          BUG-###
Title:           Short description
Module:          e.g. M10 Prediction & Result
Severity:        Critical / High / Medium / Low
Device / OS:     e.g. Samsung A14, Android 14
Build:           e.g. 1.0 (debug)
Steps:           1. ... 2. ... 3. ...
Expected:        ...
Actual:          ...
Attachments:     screenshot / screen recording / logcat
Status:          Open / In progress / Fixed / Verified
```

**Severity guide:** Critical = crash or data loss; High = main feature broken (login, predict, history); Medium = wrong behaviour with workaround; Low = cosmetic.

---

## 13. Entry and Exit Criteria

**Entry (start testing):** build installs; model files in assets; Firebase project connected; test accounts and test images ready.

**Exit (ready to release):**
- 100% of MVP test cases executed; ≥ 95% passed.
- No open Critical or High bugs.
- ML-01 to ML-06 met (or documented with justification).
- Regression checklist passed on at least 2 real devices.

---

## 14. Test Summary Report (fill at the end)

| Item | Value |
|---|---|
| Total test cases | |
| Passed / Failed / Blocked | |
| Model test accuracy (Keras / TFLite) | |
| Rejection rate (not_fundus) | |
| Average inference time | |
| Open bugs (by severity) | |
| Devices tested | |
| Conclusion | |
