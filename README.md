# Tanuki POC

Proves the loop: edit code from a phone → push → GitHub Actions builds the APK →
download and install on the phone. No Android Studio, no PC.

Get the APK: **Actions** tab → latest "Build APK" run → **Artifacts** →
`tanuki-poc-debug` (a zip containing `app-debug.apk`).

Builds are signed with the committed `app/debug.keystore`, so each new APK
installs as an update over the previous one. It's a debug key only — don't use
it for release builds.

## べく杯 (Bekuhai) — Godot drinking game

`bekuhai/` is a Godot 4.4 project: Tosa's drinking-game top. Flick the top (or
tap 回す！); whoever the spike points at drinks from the cup of the face that
lands on top — おかめ, ひょっとこ or 天狗. Faces, sounds and lanterns are all
drawn/synthesized in code; fonts are Dela Gothic One and Zen Maru Gothic (OFL).

Get the APK: **Actions** → latest "Build Bekuhai APK" run → **Artifacts** →
`bekuhai-debug`. It's signed with the same debug key, so updates install over
the previous build.
