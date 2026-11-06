# auth_lab_13

This is a Flutter Android app that uses Firebase Authentication (email/password). Users can register, sign in, view their profile, change their password, and sign out.

Features:

Register / Sign in on one screen, with email format and 6+ character password validation
Loading spinner + disabled buttons while requests run, so users can’t double-submit
Friendly error messages (wrong password, email already in use, no connection) with no raw exception text
AuthGate uses authStateChanges() to switch between the Sign in and Profile screens automatically, so signed-out users can’t reach Profile, even with the Back button
Session restoration: users stay signed in after restarting the app
Profile screen shows the current user’s email, with Sign out and Update password
Password update handles requires-recent-login by asking for the current password, re-authenticating, and retrying

Structure: all auth actions are centralized in AuthService (register, sign in, sign out, change password, reauthenticate, current user, auth stream). Firebase is initialized in main.dart before runApp().

Tested on the Android emulator: invalid inputs, registration, session restoration, sign-out access blocking, wrong password, duplicate account, password change (old password fails, new one works), and the recent-login re-authentication pop-up (observed after about 5 minutes).

Submitted: GitHub repo link, app-release.apk, and the reflection/evidence document.

AI use: ChatGPT for the flow/test comparison; Claude help in fixing the app when my code did not go through correctly by correcting the outline of the code.
