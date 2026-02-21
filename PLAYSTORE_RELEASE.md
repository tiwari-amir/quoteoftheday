# Play Store Release Prep

## 1) Create upload keystore (one-time)

Run from project root:

```powershell
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

## 2) Configure signing

1. Copy `android/key.properties.example` to `android/key.properties`.
2. Fill values in `android/key.properties`.
3. Keep both `android/key.properties` and `upload-keystore.jks` private.

## 3) Build release bundle (AAB)

```powershell
flutter clean
flutter pub get
flutter build appbundle --release
```

Output:

`build/app/outputs/bundle/release/app-release.aab`

## 4) Current Android identifiers

- Application ID: `com.hbp.quoteoftheday`
- App label: `QuoteFlow: Daily Scroll Quotes`
- Version: `1.3.0+4`

