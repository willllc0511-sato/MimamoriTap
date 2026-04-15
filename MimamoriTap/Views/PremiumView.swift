import SwiftUI

/// サブスクリプション登録画面（高齢者向けに大きく見やすいUI）
/// dismissable: trueなら閉じるボタンあり（リマインド表示）、falseなら閉じられない（期限切れ）
struct PremiumView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    /// 閉じるボタンを表示するか（リマインド時はtrue、期限切れ時はfalse）
    var dismissable: Bool = false

    /// プレミアム機能の説明リスト
    private let features: [(icon: String, title: String, description: String)] = [
        ("chart.line.uptrend.xyaxis", "体調トレンドグラフ", "日々の体調を見やすいグラフで確認できます"),
        ("person.2.fill", "複数の連絡先", "お知らせを届ける家族を複数登録できます"),
        ("bell.badge.fill", "優先サポート", "お困りの際に優先的にサポートを受けられます"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    trialBanner
                    headerSection
                    featuresSection
                    pricingSection
                    purchaseButton
                    restoreButton
                    legalLinks
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
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
        // リマインド時はスワイプで閉じられる、期限切れ時は閉じられない
        .interactiveDismissDisabled(!dismissable)
    }

    // MARK: - トライアル期間バナー

    private var trialBanner: some View {
        Group {
            let remaining = storeManager.trialRemainingDays
            if remaining <= 0 {
                // 期限切れ
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.red)
                    Text("無料お試し期間が終了しました")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.red)
                    Text("引き続きご利用いただくには、\nプランへの登録をお願いします。")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.red.opacity(0.08))
                )
            } else if remaining <= 3 {
                // 残り3日以内リマインド
                VStack(spacing: 6) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 28))
                        .foregroundStyle(Color("AccentOrange"))
                    Text("あと\(remaining)日で無料お試し期間が終了します")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color("AccentOrange"))
                    Text("期間終了後は月額プランへの登録が必要です")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color("AccentOrange").opacity(0.08))
                )
            }
        }
    }

    // MARK: - ヘッダー

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
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
            // 通常価格（取り消し線付き）
            Text("月額290円")
                .font(.system(size: 18))
                .foregroundStyle(.gray)
                .strikethrough(true, color: .gray)

            // キャンペーン価格
            if let product = storeManager.product {
                Text(product.displayPrice + " / 月")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
            } else {
                Text("月額190円")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
            }

            Text("先着1,000名様 キャンペーン価格")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color("AccentOrange"))
        }
    }

    // MARK: - 購入ボタン

    private var purchaseButton: some View {
        VStack(spacing: 8) {
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
                } else if storeManager.product == nil {
                    Text("商品情報を読み込み中...")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                } else {
                    Text("15日間無料で試す")
                        .font(.system(size: 22, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                }
            }
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(storeManager.product == nil ? Color.gray : Color("AccentGreen"))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .disabled(storeManager.isPurchasing)

            Text("無料期間終了後、月額190円が課金されます")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            if let errorMessage = storeManager.errorMessage {
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
