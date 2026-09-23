# AniDash v1.15.0: Hindi Anime Playback Subsystem, Instant Tap Controls & Resume Fixes

Welcome to **AniDash v1.15.0**! This milestone update introduces full native **Hindi anime playback** support with automatic multi-audio switching, eliminates video player double-tap delay for immediate responsiveness, and fixes critical playback progress and resume bugs.

---

### 🌟 What's New & Fixed in v1.15.0

#### 1. Instant Video Player Controls (Double-Tap Seeking Removed)
* **0ms Tap Latency**: Single taps to show or hide playback controls are now completely instantaneous with zero disambiguation delay.
* **Clean Player UI**: Eliminated double-tap forward/backward seek gestures and their overlay ripples for a smooth, distraction-free player experience.

#### 2. Continue Watching & Progress Resumption Fixes
* **Accurate Completion Tracking**: Fixed an issue where episodes with remaining watch time (such as 5 minutes remaining on Episode 126) were prematurely marked finished by external trackers (AniList/MAL at 80%) and advanced to the next episode. Progress is now preserved until truly completed (>=92% or last 45s).
* **Guaranteed Resume Position**: Resuming an episode from the Continue Watching card or details screen now seeks directly to the exact saved timestamp instead of resetting to 0:00.
* **Finished Anime Card**: The Continue Watching banner in anime details is now properly hidden when all episodes of an anime are completed.

#### 3. Native Hindi Playback Subsystem
* **Integrated Hindi Providers**:
  * **AnimeSalt**: Real-time catalog search and AJAX episode stream resolution.
  * **AnimixStream**: Fast anime indexing and multi-audio stream playback.
  * **AnimeDrive**: Domain resolution with HubCloud stream extraction.
  * **AnimeLok**: Direct stream resolution (experimental).
* **Multi-Audio Track Auto-Switching**: Automatically detects Hindi audio tracks on multi-audio HLS streams and switches playback to Hindi seamlessly via `media_kit`.
* **Episodes Tab Integration**: Added the **Hindi Sources** list in the episode bottom sheet with live latency and health metrics. Episodes exceeding the available Hindi episode count are clearly marked with a `[Hindi Soon]` badge.
* **Dedicated Source Management**: Manage, test, reorder, and toggle Hindi sources from Settings > Sources.
* **Hedged Resolver & Stream Caching**: Low-latency parallel resolution ensures fast playback start without blocking.

---

### 📦 Download & Verification
* **APK**: `AniDash-v1.15.0-Universal.apk`
* **Application ID**: `com.anidash.anime`
* **Target SDK**: Android 14+ (API 34/36)
