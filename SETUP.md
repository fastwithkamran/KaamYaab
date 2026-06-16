# KaamYaab — Local Setup Guide

> Complete these steps **once** on every new development machine, or after cloning.
> None of these files are committed — they stay local only.

---

## 1. Firebase Config (`google-services.json`)

Download from **Firebase Console → Project Settings → General → Your apps → Android app**.

```
Place at: android/app/google-services.json
```

There is also a root-level copy required by some Firebase CLI commands:
```
Place at: google-services.json
```

---

## 2. FCM Service Account (`assets/fcm_service_account.json`)

> ⚠️ This file contains a **private RSA key** — never commit it.

1. Open **Firebase Console → Project Settings → Service Accounts**
2. Click **"Generate new private key"** → confirm → a JSON file downloads
   (filename looks like `kaamyaab-92-firebase-adminsdk-fbsvc-XXXXXXXX.json`)
3. Copy the **entire content** of that file into:

```
assets/fcm_service_account.json
```

The template placeholder already exists at that path — replace it entirely.

---

## 3. Android Local Properties (`android/local.properties`)

The file should look like this (update paths to match your machine):

```properties
sdk.dir=C:\\Users\\YOUR_USERNAME\\AppData\\Local\\Android\\Sdk
flutter.sdk=D:\\Flutter\\flutter
flutter.buildMode=release
flutter.versionName=1.0.0
flutter.versionCode=1
MAPS_API_KEY=YOUR_GOOGLE_MAPS_API_KEY
```

---

## 4. Environment / API Keys (build-time via `--dart-define`)

Supply these when running or building:

```bash
flutter run \
  --dart-define=COHERE_API_KEY=your_cohere_key \
  --dart-define=GOOGLE_MAPS_API_KEY=your_maps_key
```

Or add them to a **VS Code `launch.json`** (already gitignored):

```json
{
  "configurations": [
    {
      "name": "KaamYaab",
      "request": "launch",
      "type": "dart",
      "toolArgs": [
        "--dart-define=COHERE_API_KEY=your_key",
        "--dart-define=GOOGLE_MAPS_API_KEY=your_key"
      ]
    }
  ]
}
```

---

## 5. Functions `.env` (`functions/.env`)

```env
COHERE_API_KEY=your_cohere_key
```

---

## Verification Checklist

```bash
# All should return no output (files not tracked)
git ls-files android/local.properties
git ls-files google-services.json
git ls-files android/app/google-services.json
git ls-files assets/fcm_service_account.json
git ls-files lib/config/env_config.dart

# Should report no issues
flutter analyze
```
