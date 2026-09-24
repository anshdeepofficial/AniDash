### What's New & Fixed in AniDash v1.15.3 🚀

#### 🧭 Navigation & Tab Fixes
- **Dynamic Navigation Bar Syncing**: Fixed an issue where disabling the Manga tab in UI Settings caused tapping "Downloads" or "Watchlist" to reset/jump directly back to Home. The bottom/side navigation bars and page view now dynamically map only visible tabs, ensuring immediate and smooth tab switching.

#### 🎙️ Hindi Dubbing & Source Management
- **Source Logos**: Fixed missing Hindi source icons in the episode source selector and settings by resolving the full remote favicon URL with proper fallback indicators.
- **Provider Mutual Exclusivity**: Extension sources and Hindi sources now reflect mutually exclusive active badges in the Episodes tab and player sheet.
- **Seamless Provider Fallback**: If a manually selected Hindi provider fails or lacks stream links for a specific episode, AniDash automatically falls through to other enabled Hindi providers.

#### 🔄 Update Scheduler & Reminders
- **Smart Update Snooze**: Fixed an issue where the 24-hour rate limit blocked the "Remind in 1 Hour" update reminder from appearing when due.

---
**Full Changelog**: https://github.com/anshdeepofficial/AniDash/compare/v1.15.2...v1.15.3
