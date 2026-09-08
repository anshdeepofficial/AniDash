# AniDash v1.11.2

## What changed

- Restored rich About information with a Jikan/MyAnimeList fallback while the AniList API is unavailable.
- Refined the available-language section to match the app's visual style.
- Added the selected audio type (English DUB or Japanese SUB) to download cards.
- Improved download reliability by handling servers that ignore resumed byte-range requests without corrupting or truncating episodes.
- Download failures now show the actual reason so retry and source problems are easier to diagnose.
- Adult titles now try installed adult extensions first, then regular installed extensions, and finally native sources.
- Kept AniYomi and MangaYomi as separate source engines and added guidance after extension installation for switching between them.
- Refreshed installed extension lists immediately after installation so existing and newly installed sources remain visible.

## Compatibility

- Existing downloads remain compatible; older entries display their audio type as Unknown.
- Package name remains `com.anidash.anime` for in-place updates.

## APK verification

- SHA-256: `1CD02B807B3AEB358FA463687369B6DD0093D61FD1D64919BA26A4DF23E1B648`
