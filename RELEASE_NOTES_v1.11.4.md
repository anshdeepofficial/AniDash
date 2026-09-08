# AniDash v1.11.4

## Fixed

- Search and Browse now retry the MyAnimeList-backed Jikan fallback when its public API temporarily times out.
- Browse displays a clear retry action instead of an empty page when every catalog provider is unavailable.
- Leaving an offline video now waits for playback progress to be saved before returning to the app.
- Offline progress is merged into the existing online anime record whenever one is available.
- Continue Watching checks the persisted downloads database and plays a matching downloaded episode instead of fetching it again from the internet.
- Download matching works even when the Downloads screen has not yet been opened during the current app session.

## Notes

- No MyAnimeList API key is required for the Jikan fallback.
- Package name remains `com.anidash.anime` for in-place updates.

## APK verification

- SHA-256: `88C41E61002E68594F0658B6DA5D2F0C029B549DD6F53263CE34AC828290C33E`
