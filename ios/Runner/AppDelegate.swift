import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // TODO: Replace with a real key from Google Cloud Console (APIs &
    // Services > Credentials, "Maps SDK for iOS" enabled) before shipping.
    // Untracked by git the way .env/local.properties are — see README for
    // where to keep the real value (e.g. an untracked Config.xcconfig).
    //
    // TODO: 配布前にGoogle Cloud Console（APIとサービス > 認証情報、
    // "Maps SDK for iOS"を有効化）で取得した実際のキーに置き換える。
    // .env/local.propertiesと違いgit管理外にはなっていない。実際の値の
    // 保管先（例: 追跡対象外のConfig.xcconfig）はREADME参照。
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY_HERE")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
