import SwiftUI

@main
struct MyWeChatApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

// MARK: - AppDelegate（处理推送通知）
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 设置通知代理
        UNUserNotificationCenter.current().delegate = NotificationService.shared

        // 请求通知权限
        NotificationService.shared.requestAuthorization()

        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationService.shared.handleDeviceToken(deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ 推送注册失败: \(error)")
    }
}
