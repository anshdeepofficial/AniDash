## ⚡ What's New in v1.12.3

### 📑 Anime Details Tabs Overhaul (About, Episodes & Characters)
- **Guaranteed 3-Tab Ordering**: Every anime now opens with **About** first, followed by **Episodes** and **Characters**, with all three tabs guaranteed to load reliably together.
- **Synchronized Metadata Matching**: Coordinated details fetching and episode search so the episode matcher always has the complete English title, Romaji title, synonyms, and MyAnimeList ID, achieving 100% accurate match rates.
- **Fixed Episode Bleeding Bug**: Eliminated a bug where a previously opened anime's episodes temporarily or permanently appeared on a newly opened anime.
- **Characters Tab Fallback & 50-Cast Query**: Increased AniList character query to 50 characters and added an automatic Jikan fallback when AniList returns no character data. Added a clean loading spinner and an interactive **Retry** button.
- **Synopsis Formatting**: Cleaned up raw `<br>`, `<p>`, `</div>` tags and stripped AniList spoiler markup and BBCode for clean, readable paragraphs.

### 🖼️ Minimalist Picture-in-Picture (PiP) Redesign
- **Ultra-Clean Floating Window**: When entering PiP mode (either via the button or by swiping to Home), all cluttered player overlays, sliders, volume/brightness bars, gesture handlers, and drawer panels are stripped away.
- **Dedicated PiP Controls**: Shows **ONLY** the 5 essential controls:
  - **Close (`X`)**: Closes PiP and stops playback.
  - **Fullscreen**: Expands back to full app view.
  - **-10s**: Rewind 10 seconds.
  - **Play / Pause**: Center toggle button.
  - **+10s**: Forward 10 seconds.
- Controls auto-hide after 3 seconds of inactivity.

### 🎧 Sleek Audio & Subtitle Availability Bar
- **Compact Single-Line Design**: Replaced the bulky, space-consuming card in the About tab with a modern, compact, single-line horizontal bar.
- **Clean Pill Badges**: Features a subtle headphone icon and crisp `[✓ SUB]` / `[✓ DUB]` badges with zero wasted vertical space.

### 🛡️ Storage Permissions & Share Safety
- **Android 13+ Safe Backups**: Updated export functionality with safe exception guards and updated `SharePlus` implementation.

---

**Package:** com.anidash.anime  
**Version:** 1.12.3 (57)  
