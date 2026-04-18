import SwiftUI

/// 家族通知ステータス画面（Apple審査対策: ongoing valueの証拠）
struct FamilyNotificationStatusView: View {
    @State private var notificationState = "active"
    @State private var lastTapAt: Date?
    @State private var isLoading = true

    var body: some View {
        List {
            Section {
                HStack {
                    Text("通知ステータス")
                        .font(.system(size: 18))
                    Spacer()
                    Text(stateDisplayText)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(stateColor)
                }

                HStack {
                    Text("最終タップ")
                        .font(.system(size: 18))
                    Spacer()
                    if let lastTap = lastTapAt {
                        Text(lastTap.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("まだタップしていません")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("通知状態")
                    .font(.system(size: 16))
            }

            Section {
                infoRow(icon: "clock", text: "24時間タップなし → 家族に1通")
                infoRow(icon: "clock.badge.exclamationmark", text: "72時間タップなし → 家族に1通")
                infoRow(icon: "heart.text.square", text: "体調不良3日連続 → 家族に1通")
                infoRow(icon: "arrow.clockwise", text: "再タップで通常運用に復帰")
            } header: {
                Text("通知ルール")
                    .font(.system(size: 16))
            }
        }
        .navigationTitle("家族通知ステータス")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadStatus()
        }
    }

    private var stateDisplayText: String {
        switch notificationState {
        case "active": return "通常運用"
        case "alerted_24h": return "24時間通知済み"
        case "alerted_72h": return "72時間通知済み"
        case "optimized": return "通知最適化中"
        default: return "通常運用"
        }
    }

    private var stateColor: Color {
        switch notificationState {
        case "active": return Color("AccentGreen")
        case "alerted_24h": return .orange
        case "alerted_72h": return .red
        case "optimized": return .secondary
        default: return Color("AccentGreen")
        }
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color("AccentGreen"))
                .frame(width: 24)
            Text(text)
                .font(.system(size: 16))
        }
        .padding(.vertical, 4)
    }

    private func loadStatus() async {
        do {
            let status = try await APIClient.shared.fetchFamilyStatus()
            notificationState = status.notificationState
            lastTapAt = status.lastTapAt
        } catch {
            // 通信エラー時はデフォルト表示
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        FamilyNotificationStatusView()
    }
}
