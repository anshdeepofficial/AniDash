# AniDash v1.8.3 🚀

## 👁️ Episode Tracking & Batch "Mark as Watched"
- **Multi-Select Watch Tracking**: Select any range of episodes in the anime details screen and mark them as watched or unwatched in bulk.
- **Persistent Selection**: Selections are preserved across screen navigation, preventing accidental resets when pressing back.

## 📥 Audio Language & Download Updates
- **English (Dub) Default**: English (Dub) is now the default and first option in the download selector, followed by Japanese (Sub) and Hindi.
- **Active Download Notifications**: Real-time download progress and percentage notifications in Android notification shade.

## 🔄 Check for Updates — Live Progress & Themed UI
- **Live Streaming Download Progress**: Download progress bar with live percentage and MB counter (`32.1 MB / 71.3 MB`).
- **Themed Update Modal**: Sleek bottom sheet matching the navigation bar green accent with formatted point-by-point changelog and full-width install action.

## 🔔 Notification Center & Settings
- **Notification Preferences**: New **Settings > Notifications** page with granular toggles for News, Episode Releases (Sub & Dub), Continue Watching reminders, and Downloads.
- **Fixed Notification Icon**: Fixed Android status bar icon to use the transparent AniDash logo rather than a black square.
- **Continue Watching Reminders**: Background notification reminders for in-progress anime you haven't finished yet.

## 🎬 Video Player & Orientation Improvements
- **Full Sensor Auto-Rotation**: Video player seamlessly rotates to any orientation (portrait, landscape left, landscape right) regardless of system orientation lock, with a dedicated rotation toggle button on the toolbar.
- **Accurate Quality Label**: Player bottom bar displays the active stream quality (`1080P`, `720P`, `AUTO`) instead of "DEFAULT".
- **Enhanced M3U8 Parsing**: Improved parser with case-insensitive tags and bandwidth-based resolution fallback.

## 📱 Offline Download Player
- **Immersive Full-Bleed Player**: Replaced standard vertical player for downloaded videos with an immersive landscape-ready player featuring gesture controls (volume, brightness, seek) and integrated top header.

## 📚 Manga Trending & Stability
- **Manga Trending / Popular**: MangaDex and MangaKakalot automatically load popular/trending titles by default without search failures.
- **Continue Watching Details Fix**: Long-press on Continue Watching cards now smoothly opens the anime details page without 404 route errors.
