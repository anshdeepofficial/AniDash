## ⚡ What's New in v1.12.0

### 🚀 Ultra-Fast Video Startup & 100-Second Forward Buffer
- **Instant Playback (< 1–3s Startup)**: Heavily tuned MPV demuxing and buffering properties so anime begins playing almost instantaneously even on slow travel or mobile data networks.
- **100-Second Pre-Fetch Buffer**: The player now actively preserves up to **100 seconds of future video stream** in high-speed RAM cache. You can jump ahead without running into buffering or loading spinners.
- **No More Stalling or Reload Loops**: Eliminated the 2–3 reload loop issue when starting an episode.

### ⏩ VLC-Style Instant Multi-Tap Seeking (+10s, +20s, +30s)
- **Rapid Tap Accumulation**: Double-tapping the left or right side now works just like VLC and YouTube. Consecutive taps instantly accumulate (+10s → +20s → +30s → +40s) without pausing or freezing between taps.
- **Optimistic Timecode & Seekbar Updates**: Timecodes and progress bars jump immediately upon tapping, eliminating all sluggishness and delays.

### 🖤 Zero Black Screen on Fast-Forward & Rewind
- **Crystal Clear Seeking**: Fixed the frustrating issue where seeking or scrubbing caused the screen to remain black until the next scene change while audio kept playing.
- **Precise Frame Decoding**: Video frames render cleanly the exact millisecond you seek.

### 🔒 Screen Lock & Phone Sleep Buffer Preservation
- **Preserve Buffer on Screen Lock**: Turning off your phone screen or locking the device while watching safely pauses playback without dumping your forward buffer from memory.
- **Data-Saving Resume**: When unlocking the phone, video resumes instantly right where you left off without wasting extra mobile data re-downloading the stream.

### ⏭️ Smart "Skip Filler Episodes" Mode
- **Skip Pure Fillers Seamlessly**: Added a new "Skip Filler" interactive toggle chip in the Anime Details episode section.
- **Binge Without Interruptions**: All episodes remain visible in the list, but auto‑play will automatically jump over filler episodes (e.g. Episode 50 smoothly advances directly to Episode 53).
- **Distinct Mixed vs Pure Filler Badges**: Filler episodes clearly show an orange `FILLER` tag, while mixed canon episodes display a purple `MIXED` tag.

### ⏭️ Skip Intro & Skip Outro Restored
- **Dual Detection Engine**: AniSkip timestamp lookup is now paired with instant stream‑provider timestamps (JustAnime & HiAnime fallback).
- **Timeline Highlights & Buttons**: Skip Intro and Skip Outro buttons appear right on time with visual highlights on the seekbar.

### 🔊 Hardware Volume & Screen Brightness Polish
- **In‑App Volume HUD**: Pressing your phone's physical volume up/down buttons while watching a video now displays the clean in‑app volume slider HUD.
- **Standard Android Volume Outside Player**: As soon as you exit the player, Android's normal system volume control takes over immediately.
- **Brightness Error Fixed**: Resolved the Android notification warning "You can't change the brightness" after leaving full screen.

### 📺 Picture‑in‑Picture (PiP) & VLC Stop Mode
- **Picture‑in‑Picture (PiP)**: Multitask while watching anime with Android native PiP support.
- **Stop After This Episode**: Added a VLC‑style option in player settings to stop playback after the current episode instead of auto‑playing the next one.

### 🔍 Jump to Episode Search Bar
- **Instant Search in Episodes Tab**: Tap the search icon in the episode list to quickly filter and jump straight to any episode number or title without endless scrolling.

### 📶 Bulletproof Offline Downloads
- **Smart Auto‑Retry**: Added exponential backoff retry for network drops, ensuring downloads don't fail when switching cell towers or Wi‑Fi networks.

---

**Package:** com.anidash.anime
**Version:** 1.12.0 (54)
**SHA‑256:** `127E17E83D92A370EFC10A98763BD7E231AA9A93DD5A3DA2DAA737D8255870ED`
