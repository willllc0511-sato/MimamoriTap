import SwiftUI
import SwiftData

/// アプリのエントリーポイント
@main
struct MimamoriTapApp: App {
    /// 通知マネージャー
    @StateObject private var notificationManager = NotificationManager.shared
    /// 課金管理マネージャー
    @StateObject private var storeManager = StoreManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notificationManager)
                .environmentObject(storeManager)
                .onAppear {
                    // 通知許可済みの場合のみスケジュールを更新（許可リクエストはサブスク購入完了後に行う）
                    notificationManager.checkAuthorizationStatus()
                }
        }
        .modelContainer(for: TapRecord.self)
    }
}
