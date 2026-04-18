import Foundation

/// Supabase REST API クライアント
/// LINE連携機能のバックエンド通信を担当
final class APIClient {
    static let shared = APIClient()

    private let supabaseURL = "https://esldunculksqlpwmqpom.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVzbGR1bmN1bGtzcWxwd21xcG9tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY0MDk3NzQsImV4cCI6MjA5MTk4NTc3NH0.WiWg5Vrv9yZbbODjamslzQJ7aZXwDqH0zCNpOgrb5-w"

    /// 端末識別UUID（初回起動時に生成し永続化）
    var deviceUUID: String {
        let key = "mimamoritap_device_uuid"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let newUUID = UUID().uuidString
        UserDefaults.standard.set(newUUID, forKey: key)
        return newUUID
    }

    private init() {}

    // MARK: - タップ記録送信

    /// 体調タップをSupabaseに送信（失敗しても無視、ローカル保存が優先）
    func sendTap(mood: String, memo: String?) async {
        guard isConfigured else { return }

        let body: [String: Any?] = [
            "device_uuid": deviceUUID,
            "mood": mood,
            "memo": memo,
        ]

        _ = try? await post(function: "record-tap", body: body)
    }

    // MARK: - 連携コード取得

    /// 新しい連携コードを生成してサーバーに保存、コードを返す
    func generateLinkCode() async throws -> String {
        guard isConfigured else { throw APIError.notConfigured }

        let code = Self.randomCode(length: 8)
        let expiresAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(24 * 60 * 60))

        // usersテーブルを直接更新（anon key + RLS）
        let url = URL(string: "\(supabaseURL)/rest/v1/users?device_uuid=eq.\(deviceUUID)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.addValue(deviceUUID, forHTTPHeaderField: "x-device-uuid")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "link_code": code,
            "link_code_expires_at": expiresAt,
        ])

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.serverError
        }

        return code
    }

    // MARK: - ユーザー登録（初回）

    /// デバイスUUIDでユーザーをサーバーに登録（初回のみ）
    func ensureUserExists() async {
        guard isConfigured else { return }

        let body: [String: Any?] = [
            "device_uuid": deviceUUID,
        ]

        // record-tapが自動でユーザー作成するため、空のタップ送信で代用しない
        // 直接usersテーブルにinsert（重複は無視）
        let url = URL(string: "\(supabaseURL)/rest/v1/users")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.addValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.addValue(deviceUUID, forHTTPHeaderField: "x-device-uuid")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - 家族通知ステータス取得

    struct FamilyStatus {
        let familyCount: Int
        let notificationState: String
        let lastTapAt: Date?
    }

    /// 現在のユーザー状態と連携家族数を取得
    func fetchFamilyStatus() async throws -> FamilyStatus {
        guard isConfigured else { throw APIError.notConfigured }

        // ユーザー情報取得
        let userURL = URL(string: "\(supabaseURL)/rest/v1/users?device_uuid=eq.\(deviceUUID)&is_deleted=eq.false&select=notification_state,last_tap_at")!
        var userReq = URLRequest(url: userURL)
        userReq.addValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        userReq.addValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        userReq.addValue(deviceUUID, forHTTPHeaderField: "x-device-uuid")

        let (userData, _) = try await URLSession.shared.data(for: userReq)
        guard let users = try JSONSerialization.jsonObject(with: userData) as? [[String: Any]],
              let user = users.first else {
            return FamilyStatus(familyCount: 0, notificationState: "active", lastTapAt: nil)
        }

        let state = user["notification_state"] as? String ?? "active"
        var lastTap: Date?
        if let tapStr = user["last_tap_at"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            lastTap = formatter.date(from: tapStr)
        }

        // 家族数取得
        // service_roleでないとfamiliesテーブルにアクセスできないため、
        // record-tapのレスポンスに含めるか、別のEdge Functionを用意する
        // 暫定: 0を返す（家族数は設定画面で不要であれば省略可能）
        return FamilyStatus(familyCount: 0, notificationState: state, lastTapAt: lastTap)
    }

    // MARK: - アカウント削除

    /// アカウントを削除（サーバー側の論理削除）
    func deleteAccount() async throws {
        guard isConfigured else { throw APIError.notConfigured }

        let body: [String: Any] = ["device_uuid": deviceUUID]
        let (_, response) = try await post(function: "delete-account", body: body)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.serverError
        }

        // ローカルのUUIDをリセット
        UserDefaults.standard.removeObject(forKey: "mimamoritap_device_uuid")
    }

    // MARK: - SOS通知送信

    /// SOS発信時に家族のLINEへ即時通知（失敗してもUIにエラー表示しない）
    func sendSOSNotification(sosType: String, userName: String) async {
        guard isConfigured else { return }

        let body: [String: Any] = [
            "device_uuid": deviceUUID,
            "sos_type": sosType,
            "user_name": userName,
        ]

        _ = try? await post(function: "send-sos-notification", body: body)
    }

    // MARK: - Private

    private var isConfigured: Bool {
        supabaseURL != "YOUR_SUPABASE_URL" && supabaseAnonKey != "YOUR_SUPABASE_ANON_KEY"
    }

    private func post(function: String, body: [String: Any?]) async throws -> (Data, URLResponse) {
        let url = URL(string: "\(supabaseURL)/functions/v1/\(function)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await URLSession.shared.data(for: request)
    }

    /// 紛らわしい文字（O/0/I/1）を除外した8桁英数字コード生成
    static func randomCode(length: Int) -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<length).map { _ in chars.randomElement()! })
    }

    enum APIError: LocalizedError {
        case notConfigured
        case serverError

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "サーバーが設定されていません"
            case .serverError: return "サーバーエラーが発生しました"
            }
        }
    }
}
