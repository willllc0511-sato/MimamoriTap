import SwiftUI

/// 起動時に表示するフルスクリーン画面の種類
enum LaunchScreen: Identifiable {
    case onboarding
    /// サブスク画面（dismissable: 閉じるボタンの有無）
    case premium(dismissable: Bool)

    var id: String {
        switch self {
        case .onboarding: "onboarding"
        case .premium: "premium"
        }
    }
}

/// メインのタブビュー - 4つのタブで構成
/// 起動フロー:
///   初回 → ガイド → サブスク画面（あとでスキップ可） → ホーム
///   未登録で起動 → サブスク画面（あとでスキップ可） → ホーム
struct ContentView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.modelContext) private var modelContext
    /// ガイド表示済みフラグ（UserDefaultsに永続化）
    @AppStorage("hasSeenGuide") private var hasSeenGuide = false
    /// 現在表示中のフルスクリーン画面（nilならホーム表示）
    @State private var activeLaunchScreen: LaunchScreen?

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }

            ContactsView()
                .tabItem {
                    Label("連絡先", systemImage: "person.2.fill")
                }

            HistoryView()
                .tabItem {
                    Label("履歴", systemImage: "clock.fill")
                }

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
        }
        .modifier(TabBarOnlyModifier())
        .tint(Color("AccentGreen"))
        .onAppear {
            // タブバーの背景色を淡いグリーンに設定
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(named: "BackgroundGreen")
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance

            decideInitialScreen()
            #if DEBUG
            insertSampleDataIfNeeded()
            #endif
        }
        // サブスク登録完了を監視して自動でサブスク画面を閉じる
        .onChange(of: storeManager.isPremium) { _, isPremium in
            if isPremium, case .premium = activeLaunchScreen {
                activeLaunchScreen = nil
            }
        }
        // 単一のfullScreenCoverでガイド・サブスク画面を切り替え表示
        .fullScreenCover(item: $activeLaunchScreen) { screen in
            switch screen {
            case .onboarding:
                UsageGuideView(buttonLabel: "始める") {
                    // ガイド完了 → フラグ保存 → そのままホームへ
                    hasSeenGuide = true
                    activeLaunchScreen = nil
                }
            case .premium:
                PremiumView(dismissable: false)
                    .environmentObject(storeManager)
            }
        }
    }

    #if DEBUG
    /// スクリーンショット用ダミーデータ注入（-INSERT_SAMPLE_DATA引数で有効化）
    private func insertSampleDataIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-INSERT_SAMPLE_DATA") else { return }
        let sampleData: [(Int, MoodType, String?)] = [
            (0, .good, "今日も元気です"),
            (1, .good, nil),
            (2, .normal, "少し眠いです"),
            (3, .good, "散歩しました"),
            (4, .bad, "腰が痛い"),
            (5, .normal, nil),
            (6, .good, "お出かけ中"),
        ]
        for (daysAgo, mood, memo) in sampleData {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
            let timestamp = Calendar.current.date(bySettingHour: [8, 9, 10, 7, 11, 9, 8][daysAgo], minute: 30, second: 0, of: date)!
            let record = TapRecord(timestamp: timestamp, mood: mood, memo: memo)
            modelContext.insert(record)
        }
        try? modelContext.save()
    }
    #endif

    /// 起動時にどの画面を表示するか判定
    private func decideInitialScreen() {
        // UIテスト時は購入画面をスキップしてホーム直行
        if ProcessInfo.processInfo.arguments.contains("-UITEST_SKIP_PREMIUM") {
            return
        }
        if !hasSeenGuide {
            activeLaunchScreen = .onboarding
            return
        }
        if storeManager.isPremium { return }
        // 未登録：サブスク画面を表示（あとでスキップ可能）
        activeLaunchScreen = .premium(dismissable: true)
    }
}

/// iPadでタブバーをサイドバーではなく下部タブバーに強制する
struct TabBarOnlyModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.tabViewStyle(.tabBarOnly)
        } else {
            content
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TapRecord.self, inMemory: true)
        .environmentObject(NotificationManager.shared)
        .environmentObject(StoreManager.shared)
}
