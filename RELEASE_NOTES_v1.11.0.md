# AniDash v1.11.0

This release improves account recovery, playback-source reliability, anime details, downloads, and extensions.

## Security

- Prevented Android backup from restoring the old app-lock credential after uninstall/reinstall.
- Added biometric-backed **Forgot App Lock** recovery so an authenticated device owner can create a new credential.
- Kept PIN setup and verification dialogs below display cutouts and the status bar.

## Watching and details

- Continue Watching is ordered by the most recently watched episode, so the active title appears first.
- Slow or failed DUB lookups are no longer reported as proof that a DUB does not exist.
- DUB downloads use a verified DUB server and never silently save the SUB stream.
- Anime details now preserve existing description, episode count, duration, staff, studios, and relations when a partial refresh is returned.
- Poster viewing now uses the full display as its zoom canvas.

## Downloads

- Renamed Concurrent Segments to **Number of Downloads**, with a default of 2 and a supported range of 1–10.
- Default download folder structure is now **Anime**.
- Subtitle tracks are downloaded beside completed videos and their saved metadata points to the local sidecar files.
- HLS downloads retain segment completeness checks and bounded parallel fetching.

## Extensions

- Extensions are always enabled for episode source selection.
- Yuzono 18+ anime, Secozzi anime, and Keiyoushi manga repository indexes remain preloaded.
- Duplicate repository installation is blocked with a clear message.
- Added an in-app explanation of AniYomi and MangaYomi extension engines.
- Repository success messages clarify that users should select a source from the Available tab.

## Verification

- Flutter targeted static analysis: passed with no issues.
- Flutter tests: passed.
- Android release APK build: passed.

SHA-256: `F3DC7A9996E64B919B395234B61EE159903FB550BCAFCE2F73C31C8BF2E6E22F`
