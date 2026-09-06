# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

GamaWaste (`gamaresik`) is a Flutter mobile app for waste classification, built for Universitas Gadjah Mada. Users sign in with Google, scan an item with the camera, and Gemini (via a Cloud Function) classifies it into one of three UGM waste categories with bin-colour disposal guidance. Scan history, per-category totals, milestone achievements, and a "Laporan Hasil Tidak Tepat" correction loop are all persisted per-user in Firestore.

## Commands

```bash
flutter pub get                 # install Flutter dependencies
flutter run                     # run on a connected device/simulator
flutter analyze                 # static analysis (flutter_lints)
flutter test                    # Dart unit + widget tests
flutter build apk               # Android release build
flutter build ios               # iOS release build (requires macOS + Xcode)

cd functions && npm install     # install Cloud Functions dependencies
cd functions && npm test        # classifier unit tests (offline, no Gemini quota needed)
firebase deploy --only functions,firestore,storage   # deploy backend
firebase functions:log --only classifyWaste          # tail function logs
```

There is no CI config and no code generation step (no build_runner/freezed).

## Architecture

MVVM with `provider`; navigation is plain `Navigator.push`/`pop` (no routing package). The backend is Firebase (Auth, Firestore, Storage) plus two Cloud Functions. **The Flutter app never calls Gemini directly** and never writes classification data itself — all privileged writes happen server-side.

### Flutter (`lib/`)

- **`main.dart`** — initializes Firebase, registers `AuthViewModel` + `HomeViewModel`, applies `AppTheme.lightTheme`, and defines `AuthWrapper`: a `StreamBuilder` on `authStateChanges()` that swaps between `AuthView` and `HomeView`. This is the only auth gate.
  - Because `AuthWrapper` already swaps in `HomeView` on sign-in, `AuthView` *pushes* `OnboardingView` on top and onboarding simply pops. Using `pushReplacement` there stacks two `HomeView`s.
- **`services/firebase_service.dart`** — the single data-access layer (Auth, Firestore, Storage, Functions). Throws `ScanException` carrying user-ready Indonesian copy. Key methods: `newScanRequestId`, `validateImage`, `uploadScanImage`, `classifyWaste`, `submitCorrection`, `getUserStats`, `getScanHistory`.
  - The callable region (`asia-southeast2`) **must** match `REGION` in `functions/index.js`; the client SDK defaults to `us-central1` and silently 404s if these drift.
- **`viewmodels/`** — `AuthViewModel`, `HomeViewModel` (aggregate stats + achievements; global), `ScanViewModel` (camera lifecycle; local to `ScanView`), `HistoryViewModel` (local to `HistoryView`).
- **`views/`** — one folder per feature: `auth`, `home`, `history`, `profile`, `result`, `scan`.
  - `ResultView` owns the scan pipeline: upload → classify → display, with loading/error/retry states. It generates a scan id **once** in `initState` and reuses it across retries so the backend can treat a retry as idempotent.
- **`models/`**
  - `WasteCategory` — enum, single source of truth for the 3 categories. `id` is the Firestore value; `classificationLabel` is the exact string Gemini returns and **must stay in sync with `CATEGORIES` in `functions/classifier.js`** (a test asserts this).
  - `ClassificationResult`, `ScanRecord`, `UserStats`, `Achievement`/`AchievementProgress`.
- **`widgets/gama_header.dart`** — shared `GamaHeader` (SafeArea-aware gradient header) and `StateMessage` (empty/error states).
- **`utils/app_theme.dart`** — `AppTheme.lightTheme` is the real Material 3 theme (colour scheme, text theme, component themes). Prefer `Theme.of(context).textTheme.*` and the `AppTheme` tokens over inline styles.

### Backend (`functions/`, Node 22, region `asia-southeast2`)

- **`classifier.js`** — pure, dependency-injected classification logic (`normalizeConfig`, `classify`). No Firebase or Gemini imports, so `classifier.test.js` verifies the zero-shot/few-shot/selective rules offline.
- **`index.js`** — Firebase plumbing plus the Gemini call:
  - `classifyWaste` (callable): validates that `storagePath` belongs to the caller, short-circuits on a repeated `clientRequestId`, reads `app_config/settings`, runs Gemini, then writes the scan log **and** increments the user's counters in one transaction.
  - `submitCorrection` (callable): records a correction, writes/updates the few-shot example, and moves the per-category counter (never `totalScans`).

### Firestore schema

- `app_config/settings` — `classification_mode` (`zero-shot` | `few-shot` | `selective`), `confidence_threshold` (default 0.5), `few_shot_count` (default 3). **Edit in the Firebase console to change behaviour with no rebuild.** Invalid values fall back to defaults and are logged loudly, never silently bypassed.
- `users/{uid}` — `totalScans`, `categoryCounts` map, `lastScanAt`, profile fields. Server-written only; this is what powers achievements.
- `users/{uid}/classifications/{scanId}` — one doc per scan. Doc id **is** the client's scan request id, which is what makes retries idempotent. Stores the prediction, final confidence, mode, `usedFewShot`/`escalated`/`zeroShotConfidence` trace, and correction fields.
- `few_shot_data/{uid}_{scanId}` — human-validated corrections feeding few-shot prompts. Deterministic id means re-correcting a scan updates one entry instead of polluting the pool.

### Security model

Clients may only **read** their own `users/{uid}/**` and their own `scans/{uid}/**` images. Every write that matters (scan logs, counters, few-shot pool) goes through a Cloud Function's Admin SDK. Users cannot inflate their own achievement counters — this is enforced by rules and covered by a live rules test.

Classification runs on **Vertex AI**, not the Gemini Developer API: `functions/index.js` builds `new GoogleGenAI({ vertexai: true, project, location })` and authenticates with the function's own Application Default Credentials. There is no API key to store, rotate, or leak. **Never add `.env` (or any credential) to the `flutter: assets:` list in pubspec.yaml** — assets are packaged into the shipped APK/IPA and trivially extractable. This previously shipped a live key to every install.

Android release builds are signed from `android/key.properties` + `android/gamaresik-release.jks`, both gitignored. The release SHA-1 and SHA-256 are registered on the Firebase Android app alongside the debug SHA-1 — Google Sign-In fails with `ApiException: 10` on any build whose signing certificate is not registered.

### Known gaps / gotchas

- **Vertex AI is billed to the project's Blaze billing account.** A `resource-exhausted` from `classifyWaste` (surfaced as "Kuota layanan AI sedang habis…") means a project quota ceiling or an inactive billing account — not a prepaid balance. `functions/index.js` also maps a `403` to a reminder that `aiplatform.googleapis.com` must stay enabled.
- The model id in `functions/index.js` is hardcoded (`gemini-3.6-flash`) and served from the `global` Vertex location, which is where Gemini 3.x publisher models are exposed. If classification starts 404ing on the model, check the Vertex model garden rather than the AI Studio docs.
- `few_shot_data` starts empty, so few-shot/selective escalation has nothing to draw on until real corrections accumulate. Selective mode degrades gracefully to the zero-shot result and records `escalated: true`.
- Firebase config (`lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`) is committed and tied to the `gamaresik` project — do not regenerate casually.
- The `firebase` MCP server in `.mcp.json` authenticates with the repo-root service-account key: fine for Firestore/Storage/Auth reads, but it lacks IAM/Secret Manager/deploy permissions. **Use the `firebase` CLI directly for anything that deploys, manages secrets, or touches IAM.**

## UI language

All user-facing copy is Indonesian ("Ambil Gambar", "Hasil Scan", "Laporan Hasil Tidak Tepat"). Keep new strings consistent.
