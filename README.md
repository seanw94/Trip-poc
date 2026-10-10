# べく杯 (Bekuhai)

A phone version of Tosa's (Kochi) drinking-game top, built with Godot 4.4 and
compiled to an Android APK by GitHub Actions — no PC needed.

## How to play

1. Sit in a circle with the phone in the middle.
2. Whoever's turn it is (番) flicks the hexagonal top. While it spins, everyone
   sings 「べろべろの神様」 — the lyrics scroll on screen with a clapping beat.
3. The top topples: whoever the shaft (軸) points at drinks from the cup of the
   face that comes up — おかめ (small, the only cup you can set down),
   ひょっとこ (hole in the mouth, cover it with a finger) or 天狗 (biggest, the
   nose won't let you put it down).
4. The drinker spins next.

Options: **指名モード** (name a target before spinning; miss and you drink
yourself), **向かい合わせ** (phone lies on the table: each cushion and the result
card face their own player — the default for **ふたりで差し向かい**, the
two-player mode). Rare events: 全員カンパイ and 道連れ. 番付 shows the night's
sumo-style ranking, and an お水タイム reminder pops up every few cups.

## Get the APK

**Actions** → latest **Build APK** run → **Artifacts** → `bekuhai-apk` (a zip
containing `bekuhai.apk`). Builds are signed with `signing/debug.keystore`, so
each new one installs as an update. The build number is shown on the title
screen.

## Development

- `scripts/` — the whole game is code: faces, the top, sounds (synthesized),
  lanterns and screens. `fonts/` holds Dela Gothic One and Zen Maru Gothic (OFL).
- `tests/smoke.tscn` plays several rounds headless in CI; `tests/shots.tscn`
  renders the main screens, which CI pushes to the `ci-screenshots` branch.
