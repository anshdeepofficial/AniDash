# AniDash Beta v1.14.8-beta.1

### 🚀 Highlights & Corrective Fixes

#### 1. Instant Video Player Response (Double-Tap Seeking Removed)
- Completely removed double-tap seeking (±10s forward/backward) and all associated overlay ripple indicators.
- Player single-tap responsiveness is now immediate with 0ms delay.

#### 2. Continue Watching & Resume Progress Fixes
- **Fixed Premature Episode Advancement**: Prevented an issue where an episode with several minutes remaining (e.g., Episode 126) would prematurely advance to the next episode (Episode 127) on the home screen when external trackers (AniList/MAL) marked progress.
- **Fixed Resume Position**: Resuming an episode from Continue Watching or episode cards now reliably seeks to the exact saved timestamp instead of resetting to 0:00.
- **Completed Series Cleanup**: Continue Watching banner in anime details is now properly hidden once all episodes are finished.

#### 3. Full Hindi Anime Playback Subsystem
- Added isolated Hindi playback architecture without disturbing standard SUB/DUB sources or community extensions.
- **Providers**: AnimeSalt, AnimixStream, AnimeDrive, and AnimeLok (experimental).
- **Hedged Resolver**: Fast parallel resolution with health tracking, error cool-downs, and LRU stream caching.
- **Multi-Audio Track Selection**: Automatically detects and locks Hindi audio streams on multi-audio HLS streams.
- **Details Screen Integration**: Replaced built-in tab with "Hindi Sources", displaying source health, latency, and graying out unreleased Hindi episodes with `[Hindi Soon]` badges.
- **Source Management**: Dedicated Hindi Sources settings to reorder, toggle, and test providers.

#### 4. Dedicated Beta Release Channel
- Package Name: `com.anidash.anime.beta`
- Allows side-by-side installation with stable release without data conflicts.
