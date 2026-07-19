import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var settingsChannel: FlutterMethodChannel?
  private var personalBackupChannel: FlutterMethodChannel?
  private let personalBackupKey = "personalDataSnapshotV1"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 로컬 일정 알림: 앱이 포그라운드일 때도 알림이 표시되도록 델리게이트 지정.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    registerSettingsChannel(messenger: messenger)
    registerPersonalBackupChannel(messenger: messenger)
  }

  private func registerSettingsChannel(messenger: FlutterBinaryMessenger) {
    settingsChannel = FlutterMethodChannel(
      name: "com.sidore.catholiccalendar/settings",
      binaryMessenger: messenger
    )
    settingsChannel?.setMethodCallHandler { call, result in
      if call.method == "openNotificationSettings" {
        let settingsURLString: String
        if #available(iOS 16.0, *) {
          settingsURLString = UIApplication.openNotificationSettingsURLString
        } else {
          settingsURLString = UIApplication.openSettingsURLString
        }
        if let url = URL(string: settingsURLString) {
          UIApplication.shared.open(url, options: [:])
        }
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func registerPersonalBackupChannel(messenger: FlutterBinaryMessenger) {
    personalBackupChannel = FlutterMethodChannel(
      name: "com.sidore.catholiccalendar/personal_backup",
      binaryMessenger: messenger
    )
    personalBackupChannel?.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "Backup channel unavailable", details: nil))
        return
      }

      switch call.method {
      case "loadSnapshot":
        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()
        result(store.string(forKey: self.personalBackupKey))
      case "saveSnapshot":
        guard
          let args = call.arguments as? [String: Any],
          let snapshotJson = args["snapshotJson"] as? String
        else {
          result(FlutterError(code: "invalid_arguments", message: "snapshotJson is required", details: nil))
          return
        }
        let store = NSUbiquitousKeyValueStore.default
        store.set(snapshotJson, forKey: self.personalBackupKey)
        result(store.synchronize())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
