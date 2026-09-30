import AVFoundation
import Flutter
import UIKit
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var audioFocusChannel: FlutterMethodChannel?
  private var securityChannel: FlutterMethodChannel?
  private var privacyView: UIView?
  private var privacyEnabled = false
  private var interruptionObserver: NSObjectProtocol?
  private var routeChangeObserver: NSObjectProtocol?

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
    observeAudioSession()
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
        if !self.privacyEnabled {
          self.removePrivacyCover()
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
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
    removePrivacyCover()
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
  }
}
