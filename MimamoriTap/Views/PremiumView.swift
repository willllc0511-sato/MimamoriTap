import SwiftUI

/// サブスクリプション登録画面（高齢者向けに大きく見やすいUI）
struct PremiumView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    /// trueの場合「閉じる」「あとで」を表示（設定画面からのsheet表示用）
    var dismissable: Bool = true

    /// 有料機能の説明リスト
    private let features: [(icon: String, title: String, description: String)] = [
        ("bell.badge.fill", "家族へのLINE通知", "タップがない時や体調不良時に、家族のLINEに自動でお知らせします"),
        ("chart.line.uptrend.xyaxis", "体調トレンドグラフ", "日々の体調を見やすいグラフで確認できます"),
        ("person.2.fill", "複数の連絡先", "お知らせを届ける家族を複数登録できます"),
        ("headphones.circle.fill", "優先サポート", "お困りの際に優先的にサポートを受けられます"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    featuresSection
                    pricingSection
                    purchaseButton
                    restoreButton
                    if dismissable {
                        skipButton
                    }
                    legalLinks
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("ご利用について")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if dismissable {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("閉じる") { dismiss() }
                            .font(.system(size: 17))
                    }
                }
            }
        }
    }

    // MARK: - ヘッダー

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color("AccentGreen"))

            Text("みまもりタップを始める")
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - 機能一覧

    private var featuresSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color("AccentGreen").opacity(0.15))
                            .frame(width: 50, height: 50)
                        Image(systemName: feature.icon)
                            .font(.system(size: 22))
                            .foregroundStyle(Color("AccentGreen"))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(feature.title)
                            .font(.system(size: 20, weight: .semibold))
                        Text(feature.description)
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                    }

                    Spacer()
                }
                .padding(.vertical, 14)

                if index < features.count - 1 {
                    Divider()
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - 料金表示

    private var pricingSection: some View {
        VStack(spacing: 6) {
            Text("30日間無料")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color("AccentGreen"))

            if let product = storeManager.product {
                Text("その後 " + product.displayPrice + " / 月")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            } else {
                Text("その後 月額500円")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 購入ボタン

    private var purchaseButton: some View {
        VStack(spacing: 10) {
            Button {
                if storeManager.product == nil {
                    Task { await storeManager.loadProduct() }
                } else {
                    Task { await storeManager.purchase() }
                }
            } label: {
                if storeManager.isPurchasing {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                } else {
                    Text("始める")
                        .font(.system(size: 22, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                }
            }
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("AccentGreen"))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .disabled(storeManager.isPurchasing)

            VStack(spacing: 2) {
                Text("30日間無料でご利用いただけます。")
                Text("無料期間終了後、月額500円で自動更新されます。")
                Text("いつでも解約できます。")
            }
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            if let errorMessage = storeManager.errorMessage, storeManager.product != nil {
                Text(errorMessage)
                    .font(.system(size: 16))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .onAppear {
            if storeManager.product == nil {
                Task { await storeManager.loadProduct() }
            }
        }
    }

    // MARK: - 復元ボタン

    private var restoreButton: some View {
        Button {
            Task { await storeManager.restore() }
        } label: {
            Text("購入を復元")
                .font(.system(size: 18))
                .foregroundStyle(Color("AccentGreen"))
        }
        .disabled(storeManager.isPurchasing)
    }

    // MARK: - あとでボタン

    private var skipButton: some View {
        Button {
            dismiss()
        } label: {
            Text("あとで")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 利用規約・プライバシーポリシー

    private var legalLinks: some View {
        HStack(spacing: 16) {
            Link("利用規約", destination: URL(string: "https://willllc0511-sato.github.io/MimamoriTap/terms.html")!)
            Text("・")
            Link("プライバシーポリシー", destination: URL(string: "https://willllc0511-sato.github.io/MimamoriTap/privacy-policy.html")!)
        }
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
        .padding(.bottom, 8)
    }
}

#Preview {
    PremiumView()
        .environmentObject(StoreManager.shared)
}
