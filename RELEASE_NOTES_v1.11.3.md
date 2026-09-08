# AniDash v1.11.3

## Fixed

- Opens the Downloads tab automatically at startup when the device has no network connection.
- Retries stalled direct and HLS downloads, uses shorter request timeouts, and resumes partial files safely.
- Offline playback now saves watch position, completion state, and last-watched time to Continue Watching.
- Downloaded episodes resume from their saved position instead of restarting from zero.
- Continue Watching is sorted by the latest playback activity, keeping the most recently watched title first.
- The offline player's Episodes button now lists every downloaded episode from the same series and switches between them locally.
- Restored Browse and Search content with a MyAnimeList-backed Jikan fallback while AniList is unavailable.
- Restored search history suggestions when the search field is opened.

## Notes

- The MyAnimeList/Jikan fallback does not require a user API key.
- Package name remains `com.anidash.anime` for in-place updates.

## APK verification

- SHA-256: `EB629C1BB6DDD89F58F63D9D8870F412D978731244CA2AE001372271E11B381C`
