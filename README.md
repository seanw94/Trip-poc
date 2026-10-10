# Tanuki POC

Proves the loop: edit code from a phone → push → GitHub Actions builds the APK →
download and install on the phone. No Android Studio, no PC.

Get the APK: **Actions** tab → latest "Build APK" run → **Artifacts** →
`tanuki-poc-debug` (a zip containing `app-debug.apk`).

Builds are signed with the committed `app/debug.keystore`, so each new APK
installs as an update over the previous one. It's a debug key only — don't use
it for release builds.
