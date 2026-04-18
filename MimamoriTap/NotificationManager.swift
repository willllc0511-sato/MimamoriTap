import Foundation
import UserNotifications
import SwiftData

/// 通知管理クラス - リマインド通知のスケジュールと許可リクエストを担当
@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    /// 通知許可状態
    @Published var isAuthorized = false

    // MARK: - UserDefaults キー

    private let enabledKey = "reminderNotificationEnabled"
    private let hourKey = "reminderHour"
    private let minuteKey = "reminderMinute"

    /// 通知ID
    private let reminderIdentifier = "daily_reminder"

    private init() {}

    // MARK: - 設定の読み書き

    /// リマインド通知が有効かどうか
    var isReminderEnabled: Bool {
        get {
            // 初回はデフォルトでON
            if UserDefaults.standard.object(forKey: enabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            objectWillChange.send()
        }
    }

    /// リマインド通知の時刻（時）
    var reminderHour: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: hourKey)
            // 初回はデフォルト朝9時
            return UserDefaults.standard.object(forKey: hourKey) == nil ? 9 : val
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hourKey)
            objectWillChange.send()
        }
    }

    /// リマインド通知の時刻（分）
    var reminderMinute: Int {
        get { UserDefaults.standard.integer(forKey: minuteKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: minuteKey)
            objectWillChange.send()
        }
    }

    /// 設定時刻をDateとして取得（DatePicker用）
    var reminderDate: Date {
        get {
            var components = DateComponents()
            components.hour = reminderHour
            components.minute = reminderMinute
            return Calendar.current.date(from: components) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reminderHour = components.hour ?? 9
            reminderMinute = components.minute ?? 0
        }
    }

    // MARK: - 通知許可リクエスト

    /// アプリ起動時に通知許可をリクエストし、スケジュールを更新
    func requestAuthorizationAndSchedule() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            Task { @MainActor in
                self.isAuthorized = granted
                if granted {
                    self.scheduleReminderIfNeeded()
                }
            }
        }
    }

    /// 現在の許可状態を確認
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - 通知スケジュール

    /// 設定に基づいてリマインド通知をスケジュール（既存の通知は置き換え）
    func scheduleReminderIfNeeded() {
        let center = UNUserNotificationCenter.current()

        // 既存のリマインド通知を削除
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])

        // 無効なら何もしない
        guard isReminderEnabled else { return }

        // 通知コンテンツ
        let content = UNMutableNotificationContent()
        content.title = "みまもりタップ"
        content.body = "今日のタップをお忘れなく🍀"
        content.sound = .default

        // 毎日指定時刻にトリガー
        var dateComponents = DateComponents()
        dateComponents.hour = reminderHour
        dateComponents.minute = reminderMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: reminderIdentifier,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    /// タップ済みの場合に当日の通知を取り消す
    func cancelTodayReminderIfTapped(modelContext: ModelContext) {
        // 今日のタップ記録があるか確認
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        let descriptor = FetchDescriptor<TapRecord>(
            predicate: #Predicate<TapRecord> { record in
                record.timestamp >= today && record.timestamp < tomorrow
            }
        )

        do {
            let todayRecords = try modelContext.fetch(descriptor)
            if !todayRecords.isEmpty {
                // タップ済みなら当日の配信予定を削除
                UNUserNotificationCenter.current()
                    .removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
                // 翌日分を再スケジュール
                scheduleReminderIfNeeded()
            }
        } catch {
            // フェッチ失敗時は何もしない
        }
    }
}
