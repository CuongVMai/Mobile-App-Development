# Science Signal B (In-Class Activity 16)

A Flutter science quiz that uses Open Trivia Database, Firebase Authentication, and Cloud Firestore.

## Features
- Email/password sign-in using Firebase.
- Loads 5 Science & Nature True/False questions.
- Shows correct and incorrect answers.
- Saves quiz results to Firestore.
- Verifies saved results with "Cloud verified."
- Allows users to view previous attempts.
- Includes error handling and a debug testing panel.

## Setup and Run

1. Set up Firebase Authentication and Cloud Firestore.
2. Enable Email/Password sign-in.
3. Publish the rules from `firestore.rules`.
4. Run these commands:

```bash
flutter pub get
flutterfire configure --platforms=android
flutter run
```

## Testing

1. Sign in with a test account.
2. Complete all 5 questions.
3. Submit the results and check for "Cloud verified."
4. Sign out and restart the app.
5. Sign back in and check previous attempts using the cloud icon.

## APK

Build using:

```bash
flutter build apk --release
```

APK name: `ICA16_B_CuongMai.apk`

## AI Use

I used Claude to help fix errors when the app was not working or failed to launch.