import Foundation
import UserNotifications
import UIKit

// MARK: - APNs 推送通知服务
class NotificationService: NSObject {
    static let shared = NotificationService()

    private override init() {
        super.init()
        requestAuthorization()
    }

    // MARK: - 权限请求
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ 通知权限已获取")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("❌ 通知权限被拒绝: \(error?.localizedDescription ?? "")")
            }
        }
    }

    // MARK: - 发送本地通知（离线时使用）
    func sendLocalNotification(title: String, body: String, sender: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["sender": sender]
        content.badge = NSNumber(value: (UIApplication.shared.applicationIconBadgeNumber) + 1)

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 通知发送失败: \(error)")
            }
        }
    }

    // MARK: - 处理 Device Token
    func handleDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 Device Token: \(token)")
        // TODO: 将 token 发送到后端服务器
    }

    // MARK: - 更新 Badge
    func updateBadge(count: Int) {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }

    func clearBadge() {
        updateBadge(count: 0)
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let sender = userInfo["sender"] as? String {
            print("📱 用户点击了来自 \(sender) 的通知")
        }
        completionHandler()
    }
}
