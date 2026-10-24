# Together — Flutter expense tracker

A starter app for individual spending and shared group expenses, written in Dart and Flutter for Android, iOS, and web.

## Run the demo

```sh
flutter pub get
flutter run -d chrome
```

Demo mode requires no account. Create groups, add expenses, choose a payer, split equally or enter each member's custom amount. Custom shares must add up to the expense total. Balances show who owes money and who is owed money. Demo records are held in memory and disappear on restart. All amounts use USD and integer cents. Equal splits assign leftover cents to the first members, preserving the exact total.

## Connect Firebase

1. Create your Firebase project, enable Authentication → Email/Password, and create a Cloud Firestore database.
2. Register the platforms you intend to use. Follow https://firebase.google.com/docs/flutter/setup for the Firebase CLI and FlutterFire CLI setup. Run `flutterfire configure` in this directory to generate platform configuration. Use your own application identifiers before release (the generated native projects currently use example identifiers).
3. The existing main.dart accepts Firebase options using Dart defines. Create an uncommitted `firebase-config.json` in this directory with values from your Firebase app configuration:

```json
{
  "FIREBASE_ENABLED": true,
  "FIREBASE_API_KEY": "your-api-key",
  "FIREBASE_APP_ID": "your-platform-specific-app-id",
  "FIREBASE_SENDER_ID": "your-sender-id",
  "FIREBASE_PROJECT_ID": "your-project-id"
}
```

Use the Firebase app ID matching the target platform. Alternatively replace the options passed to Firebase.initializeApp with `DefaultFirebaseOptions.currentPlatform` from the FlutterFire-generated firebase_options.dart, retaining FIREBASE_ENABLED as the opt-in switch.

4. Deploy the included rules using `firebase deploy --only firestore:rules --project YOUR_PROJECT_ID`. The firebase.json in this project points to firestore.rules.
5. Run `flutter run -d chrome --dart-define-from-file=firebase-config.json`.
6. Register, verify your email using the email link, then select “I have verified my email”. Create a group using the other members' email addresses. Other members must register and verify the exact listed email. Group access appears automatically; email invitations are not sent. On web, add your deployed domain to Firebase Authentication's authorized domains as needed.

Personal expenses are stored under `users/{uid}/expenses`. Groups use `groups/{groupId}` with shared expenses in its `expenses` subcollection. Members can read groups containing their verified email and add expenses. Rules deny group membership changes, expense edits, and deletions; those flows are not implemented.

## Structure

- `lib/main.dart`: responsive Material 3 UI, email/password auth, expense and group forms.
- `lib/store.dart`: Firebase repository and temporary demo implementation.
- `lib/ledger.dart`: integer-cent parsing, equal splits, balance calculation.
- `test/widget_test.dart`: cent rounding, input validation, and UI save-flow checks.
- `firestore.rules`: access isolation for personal data and verified group members.

## Validation

```sh
flutter analyze
flutter test
flutter build web
```

## Before a public launch

This is a working starter, not a production accounting system. Firebase integration requires your project and has not been tested against a live backend. Firestore rules have not been emulator-tested. The UI and provided rules validate custom share totals, nonnegative integer shares, and payer membership, with a 20-member limit. Before public use, emulator-test these rules, including invalid shares, unauthorized access, and cross-user isolation. Consider a trusted callable Cloud Function for additional auditing and rate limits.

Further work: password reset, edit/delete audit trails, settlement payments, invitation acceptance/removal, currency selection, budgets, filtering, export, and receipt uploads. Firebase initialization errors currently surface as startup errors; production should present a retry/configuration screen. Android/iOS builds require their normal platform toolchains and have not been validated here.
