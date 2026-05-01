# Chess Master — Flutter + Firebase

Production-ready chess app with offline, online, and bot play.

## Your Firebase Project
- **Project ID:** `chess-232e5`
- **Android Package:** `com.manjojuice.chess`
- **App ID:** `1:794632400427:android:c95f5a21d304acd1d2446e`

## Quick Start (Android)

```bash
# 1. Extract the zip
cd chess_master

# 2. Get Flutter dependencies
flutter pub get

# 3. Create android/local.properties (Flutter usually auto-creates this)
#    If it doesn't exist, copy the template:
cp android/local.properties.template android/local.properties
#    Edit it and set flutter.sdk=/your/flutter/path

# 4. Run
flutter run
```

## Firebase Console Setup

Go to [console.firebase.google.com/project/chess-232e5](https://console.firebase.google.com/project/chess-232e5) and enable:

1. **Authentication** → Sign-in methods → Enable *Anonymous* and *Email/Password*
2. **Firestore Database** → Create database → Start in production mode
3. **Realtime Database** → Create database
4. **Cloud Functions** → Upgrade to Blaze plan (required for Functions)
5. **Analytics** → Already enabled via google-services.json
6. **Crashlytics** → Enable

## Deploy Firebase Backend

```bash
firebase use chess-232e5
firebase deploy --only firestore:rules,firestore:indexes
```

## iOS Setup (optional)

1. Add iOS app in Firebase console (bundle ID: `com.manjojuice.chess`)
2. Download `GoogleService-Info.plist` → place in `ios/Runner/`
3. Update iOS section in `lib/firebase_options.dart` with real values
4. `cd ios && pod install && cd ..`
5. `flutter run`

## Architecture

```
lib/
├── firebase_options.dart       ← Generated from your google-services.json
├── main.dart                   ← App entry + Firebase init
├── app/
│   ├── router.dart             ← All routes (go_router with ShellRoute)
│   └── theme.dart              ← Light/dark themes with ChessThemeExtension
├── core/
│   └── providers.dart          ← All Riverpod providers
├── services/
│   ├── sound_service.dart      ← just_audio
│   ├── haptic_service.dart     ← Flutter built-in HapticFeedback
│   ├── analytics_service.dart  ← Firebase Analytics + Crashlytics
│   └── connectivity_service.dart
└── features/
    ├── auth/                   ← Splash, login (guest + email)
    ├── game/                   ← Board, clock, notifier, result sheet, dialogs
    ├── bot/                    ← Minimax AI in isolate
    ├── matchmaking/            ← Random queue, rooms (create/join), bot setup
    ├── home/                   ← Home screen with stats
    ├── profile/                ← Profile with XP, achievements
    ├── history/                ← Game history list
    ├── settings/               ← All toggles
    ├── puzzle/                 ← Daily puzzle + random puzzles
    └── achievements/           ← Achievement grid
```

## Version Specs

| Component | Version |
|-----------|---------|
| Flutter | 3.19+ |
| Dart | 3.3+ |
| Gradle | 8.11.1 |
| AGP | 8.9.1 |
| Kotlin | 2.1.0 |
| Java | 17 |
| Android compileSdk | 36 |
| Android targetSdk | 36 |
| Android minSdk | 21 |
| iOS deployment target | 13.0 |

## Key Design Decisions

**Online move validation via Cloud Functions** — Firestore rules block direct client writes to game documents. All online moves go through `submitMove` Cloud Function which validates the move server-side before updating Firestore. This prevents cheating.

**Timer state in RTDB, not Firestore** — Firebase Realtime Database has ~50ms latency vs Firestore's 200-400ms. Timer display is computed client-side as `remainingMs - (now - lastStartedAt)`, so it's pure math with zero reads during countdown.

**Bot runs in Dart Isolate** — Uses `Isolate.run()` with alpha-beta minimax. Depth scales by difficulty (1-5). Piece-square tables provide basic positional evaluation. Non-blocking UI.

**Snake_case in Firestore, camelCase in Dart** — Bridged by `GameStatusX.fromString` / `.toFirestore` extension helpers. Clean separation of wire format from domain model.

**Custom board widget** — No external `squares` package dependency. Parses FEN directly, renders 8×8 GridView with Unicode chess pieces. Full feature parity: flipping, last-move highlight, legal-move dots, promotion.

**Haptics via Flutter built-in** — Uses `HapticFeedback` from `package:flutter/services.dart` instead of the `vibration` package (which has v1 embedding incompatibility with modern Android).

## Troubleshooting

### Build fails with "flutter.sdk not set"
Create `android/local.properties` with `flutter.sdk=/your/flutter/sdk/path`

### Firebase throws "No Firebase App has been created"
Make sure `lib/firebase_options.dart` is in place (it is, in this zip).
Verify `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` is called in `main.dart` before `runApp`.

### Cloud Functions errors
You must upgrade the Firebase project to the Blaze (pay-as-you-go) plan. Functions won't deploy on the Spark (free) plan.

### "vibration package fails"
This project uses Flutter's built-in `HapticFeedback` — the vibration package is not in `pubspec.yaml`.

## License
Private project
# chess
