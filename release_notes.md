# AniDash v1.15.6

AniDash v1.15.6 delivers a comprehensive stability, playback, and visual polish pass across the entire app.

### 🌟 What's New & Fixed in v1.15.6

#### 🚀 Onboarding & Source Selection
- **Official Brand Logo**: Restored the high-resolution AniDash app logo on the fresh-install welcome screen.
- **Categorized Source Selection**: Clearly divided sources into **Extensions & Canonical** and **Hindi Sources** sections.
- **Independent Provider Persistence**: Global canonical and Hindi source selections are now preserved independently across reboots and source fallbacks.
- **High-Resolution Provider Icons**: Added dedicated brand icons for AnimeSalt, AnimixStream, AnimeDrive, and AnimeLok across Onboarding, Details, and Settings.

#### 🎬 Video Player & Playback Engine
- **JustAnime Momo (Megaplay) Server Priority**: Default streaming server prioritizes Momo with full Intro and Outro skip support.
- **Strict Media Matching & Season Isolation**: Enforced zero-tolerance title matching to prevent mismatched seasons or spin-offs (e.g., Re:ZERO, MHA, Iruma-kun).
- **Fail-Closed Playback**: Hindi providers fail closed safely to canonical sources instead of playing incorrect episodes or seasons.
- **Optimized Slow-Connection Buffering**: Enhanced media_kit cache buffer and readahead settings for seamless playback on constrained network connections.
- **Jump-to-Time Parsing**: Improved input parsing and formatting to intuitively accept raw digits (`607`, `0607` -> `06:07`, `1234` -> `12:34`).

#### 🔔 Notification Pipeline & Inbox
- **Zero-Latency Reactive Badge**: The home notification bell badge updates synchronously (`0ms`) without requiring a manual pull-to-refresh.
- **Granular Threshold Tracking**: Distinct deduplication tracking for 24-hour, 1-hour, and Released notifications.
- **Automatic Read Reconciliation**: Opening an anime from notifications or watching the latest episode immediately marks the corresponding notifications as read.

#### 🧭 Franchise & Watch Order Hierarchy
- **Chronological Franchise Traversal**: Recursive graph resolution correctly links prequels and sequels across multi-season anime (e.g., *Welcome to Demon School! Iruma-kun* S1–S4).
- **Accurate Season Chips**: Explicit labeling for final arcs and seasons (e.g., *My Hero Academia: Final Season* / Season 8).
- **Refined Extras & Specials**: Clean separation of OVAs/specials from main canon storylines with expandable lists.

#### 📊 Continue Watching & Progress Sync
- **Instant Completion Removal**: Fully watched anime (e.g., episode 1/1, 2/2, 12/12) are instantly removed from Continue Watching without latency.
- **Sync Protection**: Remote cloud/tracker synchronizations preserve local completion states and prevent re-adding completed media.

---

**Release Details:**
- **Package**: `com.anidash.anime`
- **Version Name**: `1.15.6`
- **Version Code**: `90`
- **Build Artifact**: `AniDash-v1.15.6-Universal.apk`
