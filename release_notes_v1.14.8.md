## ⚡ What's New in v1.14.8

### 🇮🇳 Isolated Hindi Anime Playback Subsystem
- **Dedicated Hindi Audio Track**: Choose between **Japanese (SUB)**, **English (DUB)**, and **Hindi** in Player Settings and inside the active player's Audio Track menu.
- **Multiple High-Speed Hindi Providers**:
  - **AnimeSalt** (Primary): High stability, clean HLS streams with multi-quality resolution.
  - **AnimixStream** (Fast Backup): Multi-audio Hindi/English playback with robust stream discovery.
  - **AnimeDrive** (Secondary Backup & Downloads): High-speed HLS and direct MP4 downloads.
  - **AnimeLok** (Experimental): Disabled by default, safe sandbox.
- **Hedged Source Resolution**: Fast hedged parallel queries (T+0 on primary provider, followed by backup provider at T+800ms) ensuring fastest possible playback startup without waiting for failed providers.
- **Resilient 2-Tier Caching**: 24-hour title/ID mapping cache and 20-minute stream URL cache minimize latency to 0ms on repeat playbacks.
- **Safe Fallback**: If Hindi is unavailable for an episode, AniDash automatically falls back to your configured fallback audio (Japanese SUB or English DUB) with a discreet notice, never blocking playback or crashing the app.

### ⚙️ Manage Hindi Sources Screen
- Located in **Settings → Player → Manage Hindi Sources** and **Extensions → Hindi Sources**.
- **Interactive Provider Controls**: Easily toggle individual providers ON/OFF.
- **Drag-and-Drop Priority Reordering**: Custom order directly dictates the resolver's priority sequence.
- **Live Latency Ping**: Test latency and uptime for each provider in real time.
- **Auto Switch vs Manual Source**: Choose Auto resolution or lock in your preferred Hindi provider.
- **Reset to Defaults**: Safely restore default provider priorities and states anytime.

### 🔄 Continue Watching Long-Press Episode Alignment Fix
- **Unified Canonical Target**: Resolved an issue where long-pressing a Continue Watching card performed actions on the previous episode rather than the displayed target episode.
- All actions (Mark as Watched, Jump to Time, Download) now strictly target `nextEpisodeNum` and advance the card accurately.

### ⏩ Smooth Cumulative Double-Tap Seek (±10s)
- **Cumulative Seek Aggregation**: Rapid double taps now cleanly accumulate (-10s, -20s, -30s, etc. / +10s, +20s, +30s, etc.) from an anchored playback position without glitching, snapping back, or calculating against stale player positions.
- **Commit Debounce & Reset Window**: Keeps the seek sequence alive across rapid taps and commits the final seek cleanly with responsive visual indicators.

### 📊 Repository Total Downloads Badge
- Added an official dynamic shields.io total downloads badge to `README.md` tracking all GitHub releases.

---

**Package:** com.anidash.anime  
**Version:** 1.14.8 (82)
