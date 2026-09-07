# AniDash v1.11.1

This maintenance release fixes anime metadata, watched-episode presentation, DUB downloads, and extension repository visibility.

## Changes

- About now requests rich AniList metadata first and preserves fallback data when a response is incomplete.
- Fixed AniList studio parsing so studios, staff, relations, episode totals, links, and related details populate correctly.
- Fully watched episodes show their completion tick without an extra progress underline; partial progress remains visible.
- DUB downloads use the same synthetic DUB server route as successful playback when a provider returns no explicit server list.
- Yuzono repository loading now switches the visible screen to the AniYomi engine and opens Available Anime.
- Already-added repositories are actively refreshed and checked for usable sources instead of trusting the saved URL.
- Added `HNM` as a search alias for `hanime`.
- Replaced technical extension-engine wording with a plain-language AniYomi/MangaYomi explanation.

## Verification

- Dart static analysis: passed.
- Flutter tests: passed.
- Android release APK build: passed.

SHA-256: `9852CAC080DD15948CC82A545278567F6C89E77239A7F65BCCF29FDAB8770F7E`
