import AVFoundation
import Flutter
import MediaPlayer
import Photos
import UIKit
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var audioFocusChannel: FlutterMethodChannel?
  private var securityChannel: FlutterMethodChannel?
  private var mediaControlChannel: FlutterMethodChannel?
  private var backgroundExecutionChannel: FlutterMethodChannel?
  private var downloadBackgroundTask: UIBackgroundTaskIdentifier = .invalid
  private var remoteCommandTargets: [(MPRemoteCommand, Any)] = []
  private var privacyView: UIView?
  private var privacyEnabled = false
  private var interruptionObserver: NSObjectProtocol?
  private var routeChangeObserver: NSObjectProtocol?
  private var captureObserver: NSObjectProtocol?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    configureAudioSession()

    GeneratedPluginRegistrant.register(with: self)

    // Workmanager launches iOS background work in a separate Flutter engine.
    // Re-register plugins there so SharedPreferences, notifications and secure
    // storage used by AniDash background tasks remain available.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.anidash.anime.notification_refresh",
      frequency: NSNumber(value: 15 * 60)
    )

    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return launched
    }

    configureAudioFocusChannel(controller.binaryMessenger)
    configureSecurityChannel(controller.binaryMessenger)
    configureMediaControls(controller.binaryMessenger)
    configureBackgroundExecution(controller.binaryMessenger)
    configurePhotoLibrary(controller.binaryMessenger)
    observeAudioSession()
    observeScreenCapture()
    return launched
  }

  private func configureAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .moviePlayback, options: [])
      try session.setActive(true)
    } catch {
      NSLog("AniDash: failed to configure iOS audio session: \(error)")
    }
  }

  private func configureAudioFocusChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "shonenx/audio_focus", binaryMessenger: messenger)
    audioFocusChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(false)
        return
      }
      switch call.method {
      case "requestAudioFocus":
        do {
          try AVAudioSession.sharedInstance().setActive(true)
          result(true)
        } catch {
          NSLog("AniDash: failed to activate audio session: \(error)")
          result(false)
        }
      case "abandonAudioFocus":
        do {
          try AVAudioSession.sharedInstance().setActive(
            false,
            options: [.notifyOthersOnDeactivation]
          )
          result(nil)
        } catch {
          NSLog("AniDash: failed to deactivate audio session: \(error)")
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func observeAudioSession() {
    let center = NotificationCenter.default
    interruptionObserver = center.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
    ) { [weak self] notification in
      guard
        let self,
        let info = notification.userInfo,
        let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
        let type = AVAudioSession.InterruptionType(rawValue: rawType)
      else { return }

      switch type {
      case .began:
        self.audioFocusChannel?.invokeMethod("onAudioFocusLossTransient", arguments: nil)
      case .ended:
        let rawOptions = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
        if options.contains(.shouldResume) {
          do {
            try AVAudioSession.sharedInstance().setActive(true)
          } catch {
            NSLog("AniDash: failed to reactivate audio session: \(error)")
          }
          self.audioFocusChannel?.invokeMethod("onAudioFocusGain", arguments: nil)
        } else {
          self.audioFocusChannel?.invokeMethod("onAudioFocusLoss", arguments: nil)
        }
      @unknown default:
        break
      }
    }

    routeChangeObserver = center.addObserver(
      forName: AVAudioSession.routeChangeNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
    ) { [weak self] notification in
      guard
        let self,
        let info = notification.userInfo,
        let rawReason = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
        let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason)
      else { return }

      if reason == .oldDeviceUnavailable {
        self.audioFocusChannel?.invokeMethod("onAudioFocusLossTransient", arguments: nil)
      }
    }
  }




  private func configurePhotoLibrary(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "anidash/photo_library",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "saveImage" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String,
        !path.isEmpty
      else {
        result(
          FlutterError(
            code: "INVALID_PATH",
            message: "Image path is missing.",
            details: nil
          )
        )
        return
      }

      let fileURL = URL(fileURLWithPath: path)
      guard FileManager.default.fileExists(atPath: fileURL.path) else {
        result(
          FlutterError(
            code: "FILE_NOT_FOUND",
            message: "The downloaded poster file does not exist.",
            details: nil
          )
        )
        return
      }

      let save: () -> Void = {
        PHPhotoLibrary.shared().performChanges({
          PHAssetChangeRequest.creationRequestForAssetFromImage(
            atFileURL: fileURL
          )
        }) { success, error in
          DispatchQueue.main.async {
            if success {
              result(true)
            } else {
              result(
                FlutterError(
                  code: "PHOTO_SAVE_FAILED",
                  message: error?.localizedDescription
                    ?? "iOS could not save the image to Photos.",
                  details: nil
                )
              )
            }
          }
        }
      }

      let handleStatus: (PHAuthorizationStatus) -> Void = { status in
        if status == .authorized {
          save()
          return
        }
        if #available(iOS 14.0, *), status == .limited {
          save()
          return
        }

        switch status {
        case .denied, .restricted:
          DispatchQueue.main.async {
            result(
              FlutterError(
                code: "PHOTO_PERMISSION_DENIED",
                message: "Allow AniDash to add photos in iOS Settings.",
                details: nil
              )
            )
          }
        case .notDetermined:
          break
        default:
          DispatchQueue.main.async {
            result(
              FlutterError(
                code: "PHOTO_PERMISSION_UNKNOWN",
                message: "Photo permission is unavailable.",
                details: nil
              )
            )
          }
        }
      }

      if #available(iOS 14.0, *) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined {
          PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
            handleStatus(newStatus)
          }
        } else {
          handleStatus(status)
        }
      } else {
        let status = PHPhotoLibrary.authorizationStatus()
        if status == .notDetermined {
          PHPhotoLibrary.requestAuthorization { newStatus in
            handleStatus(newStatus)
          }
        } else {
          handleStatus(status)
        }
      }
    }
  }

  private func configureBackgroundExecution(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "anidash/background_execution",
      binaryMessenger: messenger
    )
    backgroundExecutionChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "beginDownload":
        if self.downloadBackgroundTask == .invalid {
          self.downloadBackgroundTask = UIApplication.shared.beginBackgroundTask(
            withName: "AniDash active download"
          ) { [weak self] in
            guard let self else { return }
            self.backgroundExecutionChannel?.invokeMethod(
              "onBackgroundTimeExpired",
              arguments: nil
            )
            self.endDownloadBackgroundTask()
          }
        }
        result(self.downloadBackgroundTask == .invalid ? nil : self.downloadBackgroundTask.rawValue)

      case "endDownload":
        self.endDownloadBackgroundTask()
        result(nil)

      case "remainingTime":
        result(UIApplication.shared.backgroundTimeRemaining)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func endDownloadBackgroundTask() {
    guard downloadBackgroundTask != .invalid else { return }
    UIApplication.shared.endBackgroundTask(downloadBackgroundTask)
    downloadBackgroundTask = .invalid
  }

  private func configureMediaControls(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "anidash/media_controls",
      binaryMessenger: messenger
    )
    mediaControlChannel = channel

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "updateNowPlaying":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing now-playing data", details: nil))
          return
        }
        let animeTitle = args["animeTitle"] as? String ?? "AniDash"
        let episodeTitle = args["episodeTitle"] as? String ?? ""
        let episodeNumber = args["episodeNumber"] as? Int ?? 0
        let duration = args["duration"] as? Double ?? 0
        let position = args["position"] as? Double ?? 0
        let isPlaying = args["isPlaying"] as? Bool ?? false
        let playbackRate = args["playbackRate"] as? Double ?? 1.0

        var info: [String: Any] = [
          MPMediaItemPropertyTitle: animeTitle,
          MPMediaItemPropertyArtist:
            episodeTitle.isEmpty ? "Episode \(episodeNumber)" : episodeTitle,
          MPNowPlayingInfoPropertyElapsedPlaybackTime: max(0, position),
          MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackRate : 0.0,
          MPNowPlayingInfoPropertyDefaultPlaybackRate: playbackRate,
        ]
        if duration > 0 {
          info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        result(nil)

      case "clearNowPlaying":
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let commands = MPRemoteCommandCenter.shared()
    addRemoteCommand(commands.playCommand, method: "play")
    addRemoteCommand(commands.pauseCommand, method: "pause")
    addRemoteCommand(commands.nextTrackCommand, method: "next")
    addRemoteCommand(commands.previousTrackCommand, method: "prev")

    commands.changePlaybackPositionCommand.isEnabled = true
    let seekTarget = commands.changePlaybackPositionCommand.addTarget {
      [weak self] event in
      guard let seekEvent = event as? MPChangePlaybackPositionCommandEvent else {
        return .commandFailed
      }
      self?.mediaControlChannel?.invokeMethod(
        "seek",
        arguments: ["seconds": seekEvent.positionTime]
      )
      return .success
    }
    remoteCommandTargets.append(
      (commands.changePlaybackPositionCommand, seekTarget)
    )
  }

  private func addRemoteCommand(_ command: MPRemoteCommand, method: String) {
    command.isEnabled = true
    let target = command.addTarget { [weak self] _ in
      self?.mediaControlChannel?.invokeMethod(method, arguments: nil)
      return .success
    }
    remoteCommandTargets.append((command, target))
  }

  private func configureSecurityChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "shonenx/security", binaryMessenger: messenger)
    securityChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "setSecureFlag":
        let args = call.arguments as? [String: Any]
        self.privacyEnabled = args?["enable"] as? Bool ?? false
        self.updateCapturePrivacy()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }


  private func observeScreenCapture() {
    captureObserver = NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification,
      object: UIScreen.main,
      queue: .main
    ) { [weak self] _ in
      self?.updateCapturePrivacy()
    }
    updateCapturePrivacy()
  }

  private func updateCapturePrivacy() {
    if privacyEnabled && UIScreen.main.isCaptured {
      installPrivacyCover()
    } else if UIApplication.shared.applicationState == .active {
      removePrivacyCover()
    }
  }

  private func installPrivacyCover() {
    guard privacyEnabled, privacyView == nil, let hostView = window else { return }
    let cover = UIView(frame: hostView.bounds)
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    cover.backgroundColor = .black
    cover.isUserInteractionEnabled = false
    hostView.addSubview(cover)
    privacyView = cover
  }

  private func removePrivacyCover() {
    privacyView?.removeFromSuperview()
    privacyView = nil
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    installPrivacyCover()
    super.applicationWillResignActive(application)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    updateCapturePrivacy()
    configureAudioSession()
    super.applicationDidBecomeActive(application)
  }

  deinit {
    if let interruptionObserver {
      NotificationCenter.default.removeObserver(interruptionObserver)
    }
    if let routeChangeObserver {
      NotificationCenter.default.removeObserver(routeChangeObserver)
    }
    if let captureObserver {
      NotificationCenter.default.removeObserver(captureObserver)
    }
    for (command, target) in remoteCommandTargets {
      command.removeTarget(target)
    }
    remoteCommandTargets.removeAll()
    endDownloadBackgroundTask()
  }
}
