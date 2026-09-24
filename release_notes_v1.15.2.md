### What's New & Fixed in AniDash v1.15.2 🚀

#### 🥇 Distinct Trending Podium Ranking
- **Top 3 Visual Identity**: The Trending section now features distinct, polished metallic treatments for podium ranks: **#1 Gold**, **#2 Silver**, and **#3 Bronze**, while ranks #4+ retain clean standard typography.
- **Dynamic & Live**: Built strictly on live AniList trending order without hardcoding anime positions.

#### 📐 Dynamic Bottom Navigation Padding & Paging
- **Safe Floating Nav Clearance**: Section and Browse screens now dynamically compute bottom content padding (`MediaQuery.paddingOf(context).bottom + 88.0`), ensuring "Show More" and footer controls never overlap or get obscured behind the floating navigation bar.
- **Honest 50-Item Incremental Paging**: Complies cleanly with AniList's 50-item per-request ceiling with reliable incremental "Show More" batches.

#### 📱 Continue Watching Bottom Sheet Optimization
- **Full 6-Item Visibility**: Fixed the modal sheet height constraint on small and tall devices with `isScrollControlled: true` and scrollable bounds (`maxHeight: 0.85 * screenHeight`). All 6 options—including "Refresh source match" and "Remove from Continue Watching"—remain fully visible and accessible.

#### 🎛️ Customizable App Navigation
- **Navigation Bar Settings**: Added a new configuration section in **Settings → UI Settings → Navigation Bar**.
- **User Choice**: Toggle Browse, Manga, Downloads, or Watchlist tabs to suit your personal viewing habits (Home remains mandatory).
- **Responsive & Safe**: Changes apply immediately across both mobile bottom navigation and desktop/tablet side rail navigation. If you disable the active tab you are currently viewing, the router safely redirects to Home.

#### 🔔 Notification Inbox Overhaul
- **Human-Readable Timestamps**: Inbox notifications now display relative time indicators (e.g., "Just now", "5m ago", "2h ago", "Yesterday").
- **Single-Item Delete**: Added dedicated close/delete actions to remove individual notifications alongside existing "Mark all read" and "Clear inbox" options.
- **Unread Visual Badge**: Distinct unread dot indicator and immediate state sync upon tap and route navigation.

#### 🎧 Audio Preferences & Hindi Source Preservation
- **Non-Destructive Fallback**: Fixed an issue where single-episode fallback from Hindi to English/Japanese permanently altered user settings. AniDash now provides non-destructive playback notices for individual episodes while preserving your global audio language preference.
- **Provider State Reliability**: Hardened provider persistence across community extensions, Hindi sources, and native providers.
