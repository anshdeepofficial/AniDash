# AniDash v1.15.1: Player UI Overhaul, Manga Book Mode & Notification Inbox

AniDash v1.15.1 brings major player interface cleanups, refined audio & source selection flows, an all-new Manga Book reading mode with landscape two-page spreads and volume button controls, a persistent in-app notification inbox, and comprehensive performance and visual polish.

---

### What's New in v1.15.1

#### 1. Onboarding Refinements
- **Page 1 (App Showcase)**: Features an engaging introduction highlighting fast streaming, progress tracking, and community extension capabilities.
- **Page 2 (Account & Benefits)**: Optional AniList connect with clear benefit cards explaining tracking sync and personalized recommendations, plus a seamless "Skip for now" option.
- **Page 3 (Source & Audio Setup)**: Clearly labeled audio preferences (`SUB — Japanese Audio`, `DUB — English Audio`, `HINDI — Hindi Audio / Multi-Audio`) with synchronized initial source configuration.

#### 2. Hindi & Audio Integration
- **Audio & Subs Card**: Real-time availability badges across episodes, accurately checking active Hindi sources alongside SUB and DUB.
- **Source Logos & Visuals**: Hindi source providers now display high-resolution website favicons with smooth fallback to styled initial avatars.
- **Dynamic Header Synchronization**: Episodes tab dynamically reflects the active provider name (`MATCHED ( by AnimeSalt )` or extension name) across both tabs without conflicts.
- **Provider Persistence**: Selected preferred provider persists across sessions and falls back safely if disabled or unavailable.

#### 3. Player UI & Gesture Enhancements
- **Clean Landscape Layout**: Streamlined bottom toolbar removing obsolete HQ buttons, providing direct access to Audio & Subtitle modal selection and clean server selection.
- **Server Switching**: Changing servers preserves the current episode and playback position seamlessly.
- **Episode Number Display**: Top control bar explicitly shows `E<number> — <Title>`.
- **Double-Tap Seek**: Re-implemented with complete double-tap pair tracking (10s, 20s, 30s, etc.) with animated seek ripple feedback and zero false triggers.
- **Precision Seek & Jump**: Removed confusing "VLC-style" wording in favor of "Swipe to Seek" and "Jump to Time" dialog.
- **Continue Watching Long-Press**: Long-press on Continue Watching cards triggers quick progress refresh without cluttering the main UI.

#### 4. Manga Reader & Experience
- **Unified Manga Browsing**: Normal manga browsing is unified with prominent 18+ badges displayed directly on mature content cards, removing redundant top-level filter banners.
- **Book / Page-Turn Mode**: Smooth horizontal page-by-page book reader alongside classic vertical continuous scrolling.
- **Landscape 2-Page Spread**: Automatically pairs adjacent pages side-by-side in landscape orientation with correct odd-page handling.
- **Volume Key Navigation**: Turn pages effortlessly using physical Volume Up (Next) and Volume Down (Previous) buttons while reading.
- **Precise Progress Persistence**: Saves current chapter, page index, and preferred reading mode across app restarts.

#### 5. Ranked Trending & Notification Inbox
- **Podium-Style Ranked Trending**: Trending anime browse page displays stylized top 1, 2, and 3 podium rankings with smooth pagination.
- **Notification Inbox**: Dedicated inbox sheet accessible directly from the Home header bell icon, complete with unread count badges, dismiss-all, and direct episode navigation.
- **System Sound Alignment**: Removed non-functional custom notification tone settings in favor of system-default sound and vibration channels.
- **Reliable Background Updates**: Automated background task checking GitHub releases with actionable notifications (Update Now, Remind in 1h, Skip).

#### 6. UI & Visual Rendering Polish
- **Subpixel Gradient Seam Fix**: Solidified bottom card gradient stops and container foundations across Default, Compact, Minimal, and Cover-Only card modes, eliminating white and light artifact lines completely.

---

### Verification & Quality
- **Static Analysis**: Zero errors, zero warnings (`flutter analyze lib` passed cleanly).
- **Package ID**: Preserved standard `com.anidash.anime`.
- **Architecture**: Native player, extensions, and database layers fully preserved.
