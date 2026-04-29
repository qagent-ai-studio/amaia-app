import UIKit
import Flutter
import workmanager

@UIApplicationMain

@objc class AppDelegate: FlutterAppDelegate {

    private var mkButtonChannel: MkButtoniOSChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        GeneratedPluginRegistrant.register(with: self)
        UNUserNotificationCenter.current().delegate = self

        if let controller = window?.rootViewController as? FlutterViewController {
            let flutterChannel = FlutterMethodChannel(
                name: MkButtoniOSChannel.channelName,
                binaryMessenger: controller.binaryMessenger
            )
            mkButtonChannel = MkButtoniOSChannel(channel: flutterChannel)
            flutterChannel.setMethodCallHandler { [weak self] call, result in
                self?.mkButtonChannel?.handle(call, result: result)
            }
        }

        WorkmanagerPlugin.setPluginRegistrantCallback { registry in
            GeneratedPluginRegistrant.register(with: registry)
        }

        WorkmanagerPlugin.registerPeriodicTask(
            withIdentifier: "com.amaia.alive.task.periodic",
            frequency: NSNumber(value: 240 * 60)
        )

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound])
    }
}