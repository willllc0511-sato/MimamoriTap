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
///   初回 → ガイド → ホーム（全機能使える、15日間無料）
///   12日目〜14日目 → サブスク画面（閉じられる）
///   15日経過後（未登録） → サブスク画面（閉じられない）
struct ContentView: View {
    @EnvironmentObject private var storeManager: StoreManager
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

            storeManager.recordFirstLaunchIfNeeded()
            decideInitialScreen()
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
            case .premium(let dismissable):
                PremiumView(dismissable: dismissable)
                    .environmentObject(storeManager)
            }
        }
    }

    /// 起動時にどの画面を表示するか判定
    private func decideInitialScreen() {
        if !hasSeenGuide {
            activeLaunchScreen = .onboarding
            return
        }
        // サブスク登録済みなら何も表示しない
        if storeManager.isPremium { return }

        let remaining = storeManager.trialRemainingDays
        if remaining <= 0 {
            // 無料期間終了：強制表示（閉じられない）
            activeLaunchScreen = .premium(dismissable: false)
        } else if remaining <= 3 {
            // 残り3日以内：リマインド表示（閉じられる）
            activeLaunchScreen = .premium(dismissable: true)
        }
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
