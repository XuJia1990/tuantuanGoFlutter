import Flutter
import UIKit

@objc class StampAwareFlutterViewController: FlutterViewController {
  var disablesSystemEditingInteractions = false

  override var editingInteractionConfiguration: UIEditingInteractionConfiguration {
    disablesSystemEditingInteractions ? .none : super.editingInteractionConfiguration
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var editingInteractionChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "com.tuantuango/system_editing_interactions",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "setDisabled", let disabled = call.arguments as? Bool else {
        result(FlutterMethodNotImplemented)
        return
      }
      DispatchQueue.main.async {
        let viewController = UIApplication.shared.connectedScenes
          .compactMap { $0 as? UIWindowScene }
          .flatMap(\.windows)
          .first { $0.isKeyWindow }?
          .rootViewController as? StampAwareFlutterViewController
        viewController?.disablesSystemEditingInteractions = disabled
        result(nil)
      }
    }
    editingInteractionChannel = channel
  }
}
