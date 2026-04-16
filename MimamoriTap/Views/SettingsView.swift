import SwiftUI

// MARK: - 設定画面

/// 設定画面 - アプリの各種設定（高齢者向けに大きく見やすいUI）
struct SettingsView: View {
    @EnvironmentObject private var notificationManager: NotificationManager
    @EnvironmentObject private var storeManager: StoreManager
    @AppStorage("soundEnabled") private var soundEnabled = true
    /// アニメーション設定（HomeViewと共有）
    @AppStorage("animationEnabled") private var animationEnabled = true
    /// SOSボタン表示設定（HomeViewと共有）
    @AppStorage("sosVisible") private var sosVisible = true
    /// 使い方ガイド表示フラグ
    @State private var showGuide = false
    /// プレミアム画面表示フラグ
    @State private var showPremium = false

    /// ご利用プランのステータス表示テキスト
    private var planStatusText: String {
        if storeManager.isPremium {
            return storeManager.isInTrial ? "無料トライアル中" : "ご利用中"
        }
        let remaining = storeManager.trialRemainingDays
        if remaining > 0 {
            return "無料お試し中（残り\(remaining)日）"
        }
        return "お試し期間終了"
    }

    /// DatePicker用のバインディング（変更時に通知を再スケジュール）
    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { notificationManager.reminderDate },
            set: { newValue in
                notificationManager.reminderDate = newValue
                notificationManager.scheduleReminderIfNeeded()
            }
        )
    }

    /// 通知ON/OFFのバインディング（変更時に通知を再スケジュール）
    private var reminderEnabledBinding: Binding<Bool> {
        Binding(
            get: { notificationManager.isReminderEnabled },
            set: { newValue in
                notificationManager.isReminderEnabled = newValue
                notificationManager.scheduleReminderIfNeeded()
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                // プランセクション
                Section {
                    VStack(spacing: 12) {
                        if storeManager.isPremium {
                            // サブスク購入済み
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Color("AccentGreen"))
                                Text("月額200円で利用中")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.primary)
                            }
                        } else if storeManager.trialRemainingDays > 0 {
                            // 無料お試し中
                            Text("無料お試し中")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("残り \(storeManager.trialRemainingDays) 日")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(Color("AccentGreen"))
                            Button {
                                showPremium = true
                            } label: {
                                Text("すべての機能を使う")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color("AccentGreen"))
                                    )
                            }
                        } else {
                            // お試し期間終了・未購入
                            Text("お試し期間が終了しました")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.red)
                            Button {
                                showPremium = true
                            } label: {
                                Text("すべての機能を使う")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color("AccentGreen"))
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // お知らせ設定セクション
                Section {
                    Toggle(isOn: reminderEnabledBinding) {
                        Label {
                            Text("お知らせ")
                                .font(.system(size: 20))
                        } icon: {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(Color("AccentOrange"))
                                .font(.system(size: 20))
                        }
                    }
                    .padding(.vertical, 4)

                    if notificationManager.isReminderEnabled {
                        DatePicker(
                            selection: reminderTimeBinding,
                            displayedComponents: .hourAndMinute
                        ) {
                            Label {
                                Text("お知らせ時刻")
                                    .font(.system(size: 20))
                            } icon: {
                                Image(systemName: "alarm.fill")
                                    .foregroundStyle(Color("AccentOrange"))
                                    .font(.system(size: 20))
                            }
                        }
                        .padding(.vertical, 4)

                        Text("毎日この時刻に、確認のお知らせが届きます")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }

                    // 通知が未許可の場合の案内
                    if !notificationManager.isAuthorized {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.system(size: 18))
                            Text("お知らせが許可されていません。\n設定アプリから許可してください。")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("お知らせ設定")
                        .font(.system(size: 16))
                }

                // 画面の演出セクション
                Section {
                    Toggle(isOn: $animationEnabled) {
                        Label {
                            Text("アニメーション")
                                .font(.system(size: 20))
                        } icon: {
                            Image(systemName: "sparkles")
                                .foregroundStyle(Color("AccentOrange"))
                                .font(.system(size: 20))
                        }
                    }
                    .padding(.vertical, 4)

                    Text("オンにすると、体調ボタンをタップした時に花びらが舞います")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)

                    Toggle(isOn: $soundEnabled) {
                        Label {
                            Text("タップ音")
                                .font(.system(size: 20))
                        } icon: {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(Color("AccentOrange"))
                                .font(.system(size: 20))
                        }
                    }
                    .padding(.vertical, 4)

                    Toggle(isOn: $sosVisible) {
                        Text("SOSボタン")
                            .font(.system(size: 20))
                    }
                    .padding(.vertical, 4)

                    Text("オフにすると、ホーム画面のSOSボタンを非表示にします")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                } header: {
                    Text("画面の演出")
                        .font(.system(size: 16))
                }

                // アプリ情報セクション
                Section {
                    // 使い方ガイドボタン
                    Button {
                        showGuide = true
                    } label: {
                        Label {
                            Text("使い方ガイド")
                                .font(.system(size: 20))
                        } icon: {
                            Image(systemName: "book.fill")
                                .foregroundStyle(Color("AccentGreen"))
                                .font(.system(size: 20))
                        }
                    }
                    .padding(.vertical, 4)

                    // 家族にすすめるボタン（共有シート）
                    ShareLink(
                        item: URL(string: "https://apps.apple.com/app/mimamoritap")!,
                        subject: Text("みまもりタップ"),
                        message: Text("みまもりタップ - 毎日1タップで安否確認。離れて暮らす家族の安心に。15日間無料でお試しできます")
                    ) {
                        Label {
                            Text("家族にすすめる")
                                .font(.system(size: 20, weight: .semibold))
                        } icon: {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.pink)
                                .font(.system(size: 20))
                        }
                    }
                    .padding(.vertical, 8)

                    HStack {
                        Text("バージョン")
                            .font(.system(size: 20))
                        Spacer()
                        Text("1.0.0")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("アプリ情報")
                        .font(.system(size: 16))
                }

                // 法的情報セクション
                Section {
                    Link(destination: URL(string: "https://willllc0511-sato.github.io/MimamoriTap/privacy-policy.html")!) {
                        Label {
                            Text("プライバシーポリシー")
                                .font(.system(size: 20))
                        } icon: {
                            Image(systemName: "hand.raised.fill")
                                .foregroundStyle(Color("AccentGreen"))
                                .font(.system(size: 20))
                        }
                    }
                    .padding(.vertical, 4)

                    Link(destination: URL(string: "https://willllc0511-sato.github.io/MimamoriTap/terms.html")!) {
                        Label {
                            Text("利用規約")
                                .font(.system(size: 20))
                        } icon: {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(Color("AccentGreen"))
                                .font(.system(size: 20))
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("法的情報")
                        .font(.system(size: 16))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color("BackgroundGreen"))
            .navigationTitle("設定")
            .onAppear {
                notificationManager.checkAuthorizationStatus()
            }
            .sheet(isPresented: $showGuide) {
                UsageGuideView()
            }
            .sheet(isPresented: $showPremium) {
                PremiumView()
                    .environmentObject(storeManager)
            }
        }
    }
}

// MARK: - 使い方ガイド画面

/// 使い方ガイド - シンプルな4ステップで説明
/// buttonLabel で下部ボタンのテキストをカスタマイズ可能（初回オンボーディング時は「次へ」等）
struct UsageGuideView: View {
    @Environment(\.dismiss) private var dismiss

    /// 下部ボタンのラベル（デフォルト「閉じる」）
    var buttonLabel: String = "閉じる"
    /// ボタンタップ時のコールバック（nilの場合はdismiss）
    var onComplete: (() -> Void)?

    /// ガイドの各ステップ
    private let steps: [(icon: String, iconColor: Color, title: String, description: String)] = [
        (
            "hand.tap.fill",
            Color("AccentGreen"),
            "毎日1回タップ",
            "毎日1回、今日の調子をタップしてください。\n「元気」「ふつう」「調子悪い」から選ぶだけです。"
        ),
        (
            "bell.badge.fill",
            Color("AccentOrange"),
            "自動でお知らせ",
            "一定時間タップがないと、\n登録した家族に自動でお知らせが届きます。"
        ),
        (
            "sos",
            .red,
            "緊急時はSOS",
            "緊急時はSOSボタンを使ってください。\nタップで家族に連絡、長押しで119番に発信できます。"
        ),
        (
            "person.2.fill",
            Color("AccentGreen"),
            "家族を登録",
            "連絡先タブから、\nお知らせを届ける家族を登録してください。"
        ),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // タイトル
                    Text("みまもりタップの使い方")
                        .font(.system(size: 26, weight: .bold))
                        .padding(.top, 32)
                        .padding(.bottom, 28)

                    // 4ステップ
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        stepRow(number: index + 1, step: step)

                        if index < steps.count - 1 {
                            // ステップ間の点線
                            Rectangle()
                                .fill(Color(.separator))
                                .frame(width: 2, height: 24)
                                .padding(.leading, 36)
                        }
                    }

                    Spacer().frame(height: 40)

                    Button {
                        if let onComplete {
                            onComplete()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Text(buttonLabel)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color("AccentGreen"))
                            )
                    }
                    .padding(.horizontal, 32)

                    Spacer().frame(height: 32)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .interactiveDismissDisabled(onComplete != nil)
    }

    /// ステップ1行分の表示
    private func stepRow(number: Int, step: (icon: String, iconColor: Color, title: String, description: String)) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // 番号付きアイコン
            ZStack {
                Circle()
                    .fill(step.iconColor.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: step.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(step.iconColor)
            }

            // テキスト
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("\(number).")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(step.iconColor)
                    Text(step.title)
                        .font(.system(size: 20, weight: .bold))
                }
                Text(step.description)
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
}

#Preview("設定画面") {
    SettingsView()
        .environmentObject(NotificationManager.shared)
}

#Preview("使い方ガイド") {
    UsageGuideView()
}
