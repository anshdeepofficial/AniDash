# AniDash iOS / iPadOS Port Status

Android behavior must remain unchanged. iOS-specific work is isolated behind iOS configuration or platform checks.

## Completed

- iOS display name renamed from ShonenX to AniDash.
- Production bundle identifier set to `com.anshdeepofficial1.anidash`.
- RunnerTests bundle identifier updated.
- iOS deployment target aligned to iOS 13.0 across Flutter framework and Xcode configurations.
- One universal target remains enabled for iPhone and iPad (`TARGETED_DEVICE_FAMILY = "1,2"`).
- `anidash://` URL scheme registered for OAuth/deep-link callbacks.
- CocoaPods `Podfile` added for Flutter plugin integration.
- iOS entitlements file added and linked to Debug, Release and Profile Runner configurations.
- Audio session configured for video/media playback.
- Background Audio/AirPlay/Picture-in-Picture prerequisite enabled through the `audio` background mode.
- iOS local notifications are initialized and notification permission is requested correctly.
- Shared permission state now reflects actual iOS notification authorization.
- Downloads already use the app sandbox through `getApplicationSupportDirectory()/AniDash`; Android storage paths are not used on iOS.
- Android-only Aniyomi extensions remain Android-only. Non-Android platforms continue to use the portable Mangayomi/Dart extension path.
- iOS self-update no longer attempts APK installation; the update action opens the latest AniDash release externally.
- GitHub Actions macOS iOS build validation added.

## Requires real-device validation

These cannot be considered verified until a signed build is run on an iPhone/iPad:

- Hardware video decoding and all streaming providers.
- Picture in Picture behavior with the current media_kit texture/player path.
- Background playback transitions and lock-screen behavior.
- Long-running/background episode downloads.
- OAuth callbacks for each configured tracker provider.
- Notification presentation/tap behavior.
- iPad portrait, landscape, Split View and Stage Manager layouts.

## Distribution work

Before App Store/TestFlight distribution:

- Register `com.anshdeepofficial1.anidash` in the Apple Developer account.
- Configure signing team/certificates/provisioning in Xcode or CI secrets.
- Create the App Store Connect app record.
- Replace the temporary iOS update destination with the App Store product URL after an App Store ID exists.
- Review third-party streaming/content-source behavior against App Store content and rights requirements.

## Android protection

The iOS port does not change:

- Android package identity.
- Android APK updater/install flow.
- Android Aniyomi extension behavior.
- Android native activity/PiP implementation.
- Existing Android release artifacts.
