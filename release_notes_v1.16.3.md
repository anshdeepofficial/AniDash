# AniDash v1.16.3 🎬

## ⚡ Streaming and playback

- Reworked online stream startup and recovery so a transient stall cannot repeatedly reopen the same URL or restart an episode from the beginning.
- Added a continuous forward cache window, safer network buffering, serialized same-language fallback, and resume from the latest stable position.
- Improved compatibility on devices affected by black or corrupted frames by using the stable software-decoding path.
- Preserved provider headers across HLS manifests, segments, quality changes, and recovery attempts.
- Player exit now saves progress and fully stops/unloads playback; offline playback uses the same progress lifecycle.

## ⬇️ Downloads and progress

- Downloads now verify all HLS segments before completion, retry transient network failures, resume queued work, and show clamped 0–100% progress with actual duration.
- Reduced parallel segment pressure to improve sustained throughput and avoid CDN throttling.
- Downloaded episodes retain anime identity and total-episode metadata, keeping Continue Watching synchronized.
- Subtitle failures are surfaced instead of silently producing an incomplete result.

## 🔔 Notifications, discovery, and details

- Notification categories respect their individual switches and scheduled checks no longer replace unrelated background tasks.
- Search ignores stale requests and handles pagination safely.
- Anime details and filler data use concurrent structured fallbacks without permanently caching empty failures.
- Continue Watching ordering and completed-series cleanup are more reliable.

## 🔐 Security and reliability

- Removed the embedded AniList client secret and switched mobile OAuth to the public-client flow.
- Added SHA-256 verification for downloaded app updates and stricter extension download validation.
- Hardened local authentication with PBKDF2-HMAC-SHA256, secure storage, and retry throttling.
- Disabled cleartext traffic and Android backups; removed broad storage, package-query, and battery-optimization permissions.
- Backups now include both Isar and Hive application data.
- Extension repositories remain in-process; AniYomi APK-style installation is no longer presented as an AniDash extension flow.

## 🧪 Validation

- Flutter analyzer: zero issues.
- 53 automated tests passed, including playback headers, rapid seeking, download progress, notification preferences, Continue Watching, and app startup.
- Live JustAnime validation confirmed both SUB and English DUB manifests and successful HLS segment delivery.

**Version:** 1.16.3 (100)
