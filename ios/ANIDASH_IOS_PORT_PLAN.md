# AniDash iOS / iPadOS Port Plan

This file tracks the iOS-only work for AniDash. Android files must remain untouched while this port is prepared.

## Current goal

Prepare the existing Flutter iOS runner so AniDash can be built and tested on iPhone and iPad without changing the Android app.

## Changes already started

- Rename iOS app metadata from ShonenX to AniDash.
- Add `anidash://` as the iOS deep-link scheme for future OAuth redirects.
- Raise the Flutter iOS framework minimum OS version to iOS 13.0.

## Next iOS-only batches

### 1. Xcode project identity

- Update the iOS Runner bundle identifier from the old ShonenX value to an AniDash value.
- Recommended production bundle identifier: `com.anshdeepofficial1.anidash`.
- Keep one universal target for both iPhone and iPad.

### 2. Build compatibility

- Set the Runner iOS deployment target to at least iOS 13.0.
- Confirm plugin compatibility with the Flutter SDK used by the repository.
- Run `flutter pub get` and `pod install` from a macOS build environment.

### 3. iOS source support

- Keep Android-only Aniyomi/APK extension support disabled on iOS.
- Use Dart/Mangayomi-style sources first because they are more portable to iOS.
- Add platform guards wherever source code assumes Android-only extension behavior.

### 4. Player support

- Keep the current Flutter player UI.
- Verify `media_kit` playback on iPhone and iPad.
- Add an iOS-specific Picture-in-Picture implementation later; the current PiP controller is Android-only.

### 5. Downloads

- Save downloads inside the iOS app container.
- Disable Android storage-permission assumptions on iOS.
- Later evaluate native iOS background downloading if long episode downloads are required.

### 6. Updates

- Do not use APK self-update on iOS.
- iOS updates should go through TestFlight/App Store.
- The in-app update screen can show release notes and open the App Store/TestFlight page later.

### 7. iPad UI pass

- Keep the phone layout on narrow screens.
- Add a wider iPad layout with sidebar navigation and larger grids.
- Test portrait, landscape, split view, and external keyboard/mouse behavior.

## Do not touch in this port batch

- `android/`
- Android app package name
- Android updater/APK install flow
- Android extension bridge behavior
- Existing Android release process
