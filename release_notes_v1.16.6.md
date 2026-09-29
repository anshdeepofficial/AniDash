# AniDash v1.16.6 — Reliable Episode Transitions 🎬

## Fixed

- 🚀 Prevents intro/outro auto-skip from seeking before a new stream is ready, avoiding the endless “Starting video” loop.
- 📺 Adds a guarded HLS variant fallback when a valid master playlist fails to produce its first frame.
- 🔄 Stops stale skip data and previous-episode state from affecting the next episode.
- ⏭️ Keeps the manual Skip Intro/Outro control available and prevents the next-episode prompt from jumping ahead twice.
- 🖼️ Uses episode artwork in Continue Watching when the source provides it, with safe cover-art fallback.

## Verification

- ✅ Full Flutter test suite: 56/56 passed.
- ✅ Full static analysis: no issues found.
- ✅ Live JustAnime source and manifest checks passed for One Piece Episodes 1, 170, 250, 550 and 700.
- ✅ Live SUB and DUB source and manifest checks passed for Welcome to Demon School! Iruma-kun Season 4 Episode 24.
- 🛡️ Existing v1.16.5 buffering behavior remains unchanged for streams that already open normally.
