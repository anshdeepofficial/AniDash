# AniDash v1.15.9 — Adaptive Playback Engine

## 🚀 What's New

### Instant Playback on Fast Connections
Video now starts **instantly** on WiFi and 5G. The player measures your actual download
speed before opening each stream and picks the optimal buffering profile automatically.

| Connection | Behavior |
|-----------|----------|
| Fast (WiFi / 5G, ≥500 KB/s) | Plays immediately — no initial buffer wait, tiny probe |
| Medium (4G / good 3G, ≥150 KB/s) | 2-second buffer before first frame, balanced probe |
| Slow (2G / weak 3G) | 4-second buffer, larger probe window, 4-minute cache |

The speed probe fetches just **8 KB** from the actual CDN — on fast connections this
completes in under 50ms (invisible). Retries reuse the cached measurement.

---

## 🔧 Critical Fixes (v1.15.7 Regression Restored)

### 1. Buffering safeguards fully restored
The v1.15.7 update accidentally stripped key MPV settings that prevent the
**"plays 2 seconds → stalls → plays 2 seconds → stalls"** loop:

- Restored `cache-pause: yes` — MPV now pauses itself cleanly on buffer underrun
- Restored `cache-pause-wait: 2` — waits for ≥2s of data before resuming (stops stutter cycles)
- Restored `cache-pause-initial: yes` — ensures healthy buffer before the first frame (adaptive per connection)
- Restored `cache-secs: 180` — 3-minute forward cache window
- Restored `demuxer-readahead-secs: 60` — 60s continuous forward readahead (was wrongly reduced to 30s)
- Restored `network-timeout: 20` — prevents premature CDN drops (was wrongly reduced to 15s)
- Restored `demuxer-lavf-probesize: 2097152` — reliable HLS & multi-track detection
- Restored `demuxer-lavf-buffersize: 2097152` — smooth socket throughput
- Restored `demuxer-lavf-analyzeduration: 1.5` — accurate timestamp detection
- Restored `video-sync: audio` — prevents A/V drift on slow/congested segments

### 2. Stall watchdog — automatic mid-stream recovery
Previously, if a stream stalled **after** opening (buffer ran dry mid-episode),
playback would just keep spinning indefinitely with no auto-recovery.

Now: an 8-second watchdog monitors position. If buffering persists for 8s with no
position advance, the player automatically switches to the next available source URL.
Recovery is silent — playback resumes from where it stalled.

### 3. HTTP header deduplication
`User-Agent` and `Referer` were being sent three times to every CDN request
(dedicated MPV properties + `http-header-fields` + `Media(httpHeaders)`).
Some CDNs reject requests with duplicate headers, causing silent failures.

Fixed: UA and Referer now go only through MPV dedicated properties. `http-header-fields`
explicitly excludes `user-agent`, `referer`, and `origin`.

### 4. Per-quality auth headers
When switching video quality, all quality options were incorrectly using the primary
source's auth headers — even for URLs from different CDN servers. This caused 403
errors on quality switches.

Fixed: each quality option now stores its own source-specific headers.

---

## Summary of Changes

| File | Change |
|------|--------|
| `player_provider.dart` | Restored v1.15.6 MPV config; adaptive speed probe; stall watchdog; header deduplication |
| `episode_stream_provider.dart` | Stall callback wired to fallback pipeline; per-quality headers; quality switch fix |
| `pubspec.yaml` | Version 1.15.8 → 1.15.9 |
