# AniDash v1.15.12 (Build 96) Release Notes

### 🎬 DUB Playback & Universal Stream Engine Fixes
- **Fixed Infinite Loading Loop in DUB Playback**: Resolved critical issue where the video player defaulted to an invalid AniNeko server ID and repeatedly triggered rapid server switching loops when opening English DUB episodes (such as *Welcome to Demon School! Iruma-kun Season 4* Episode 24 and *One Piece* Episode 156).
- **Megaplay & Zoko First-Class Prioritization**: Elevated high-performance Momo (Megaplay) and Zoko streams to the primary endpoints for both English DUB and Japanese SUB, resolving HLS streams in <500ms with full 1080p support.
- **Removed Silent SUB Fallback**: Respects user's English DUB preference without silently replacing the source with Japanese SUB.
- **Stall Watchdog Optimization**: Guarded the 8-second MPV stall watchdog from firing while videos are still performing initial startup (`isOpening`), eliminating server ping-pong loops on moderate or slow connections.
- **Fixed Origin & Referer Header Delivery**: Removed duplicate header handling and allowed `Origin` headers to pass cleanly to MPV, fixing CDN token handshakes across all servers.
- **Fallbacks Hardened**: Enhanced error recovery so alternate servers switch cleanly without triggering HTTP 429 rate limiting.
