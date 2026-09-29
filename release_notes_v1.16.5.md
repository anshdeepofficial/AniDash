# AniDash v1.16.5 — Sequential Playback Hotfix 🎬

## Fixed

- 🔄 Applies the complete MPV cache and demuxer profile before every episode, preventing later episodes from inheriting stale playback settings.
- ⏱️ Replaces the overly aggressive 12-second startup failure with a guarded 30-second watchdog.
- ✅ Clears a late startup error as soon as playback actually advances.
- 🧭 Prevents an old episode's timer from failing a newer episode after rapid episode switching.
- 📦 Keeps the 100 MiB+ forward-buffer configuration introduced in v1.16.4.

## Verification

- Episode 1 advanced with audio in the emulator.
- Distant sequential checks exposed false startup failures on Episodes 170 and 250 in v1.16.4; this release fixes the state/property race responsible for those failures.
- Updated player source passes targeted static analysis with zero issues.
