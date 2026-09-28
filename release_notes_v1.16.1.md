# AniDash v1.16.1

## Playback stability

- Fixed competing stream-open attempts that could reset an episode to the beginning after playback had already started.
- Added a rolling 100-second MPV read-ahead target with a 110-second cache window for smoother playback and seeking.
- Improved initial and underrun buffering while retaining memory limits for older Android devices.
- Preserved the selected audio preference instead of silently switching streams during a slow connection.

## Notification accuracy

- Fixed disabled Japanese Sub release notifications continuing to arrive because of stale background preferences.
- Notification settings are now persisted before scheduled alerts are reconciled.
- New-episode alerts are sent only when the viewer is within 12 episodes of the release.
- Enlarged the AniDash monochrome status-bar notification icon across every Android density.

## Verification

- Flutter static analysis completed without issues.
- All 50 unit tests pass.
