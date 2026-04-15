import Foundation
import StoreKit

/// サブスクリプション課金管理クラス（StoreKit 2）
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    /// プレミアムプランのProduct ID
    static let premiumProductID = "com.willllc.mimamoritap.premium.campaign"

    /// プレミアム状態（購入済み or トライアル中）
    @Published var isPremium = false
    /// 商品情報（App Store Connectから取得）
    @Published var product: Product?
    /// 購入処理中フラグ
    @Published var isPurchasing = false
    /// エラーメッセージ（UI表示用）
    @Published var errorMessage: String?
    /// サブスクリプションの有効期限
    @Published var expirationDate: Date?
    /// 無料トライアル中かどうか
    @Published var isInTrial = false

    /// トランザクション監視タスク
    private var updateListenerTask: Task<Void, Never>?

    /// 無料お試し期間（日数）
    static let trialDays = 15
    /// 初回起動日のUserDefaultsキー
    private static let firstLaunchDateKey = "firstLaunchDate"

    /// 初回起動日を記録（未記録の場合のみ）
    func recordFirstLaunchIfNeeded() {
        if UserDefaults.standard.object(forKey: Self.firstLaunchDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: Self.firstLaunchDateKey)
        }
    }

    /// 初回起動日
    var firstLaunchDate: Date? {
        UserDefaults.standard.object(forKey: Self.firstLaunchDateKey) as? Date
    }

    /// 無料お試し期間の残り日数（0なら期限切れ）
    var trialRemainingDays: Int {
        guard let firstLaunch = firstLaunchDate else { return Self.trialDays }
        let elapsed = Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day ?? 0
        return max(0, Self.trialDays - elapsed)
    }

    /// アプリ側の無料期間内かどうか（StoreKit購入不要で使える）
    var isInFreeTrial: Bool {
        trialRemainingDays > 0
    }

    /// アプリが使える状態か（サブスク登録済み or 無料期間内）
    var canUseApp: Bool {
        isPremium || isInFreeTrial
    }

    private init() {
        // トランザクション更新の監視を開始
        updateListenerTask = listenForTransactions()
        // 起動時に商品情報と課金状態を取得
        Task {
            await loadProduct()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - 商品情報の取得

    /// App Store Connect / StoreKit Configurationから商品情報を取得
    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.premiumProductID])
            product = products.first
            if product == nil {
                errorMessage = "商品情報が見つかりません。しばらくしてからお試しください。"
            } else {
                errorMessage = nil
            }
        } catch {
            errorMessage = "商品情報の取得に失敗しました。通信環境をご確認ください。"
        }
    }

    // MARK: - 購入処理

    /// サブスクリプションを購入
    func purchase() async {
        guard let product else {
            errorMessage = "商品情報が取得できていません"
            return
        }

        isPurchasing = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateSubscriptionStatus()

                // サブスク購入完了後に通知許可をリクエストし、リマインド通知をスケジュール
                NotificationManager.shared.requestAuthorizationAndSchedule()

                // トライアル開始時に終了3日前のリマインド通知をスケジュール
                if isInTrial {
                    NotificationManager.shared.scheduleTrialExpiryReminder()
                }

            case .userCancelled:
                break

            case .pending:
                errorMessage = "購入が保留中です。しばらくお待ちください。"

            @unknown default:
                errorMessage = "予期しないエラーが発生しました"
            }
        } catch {
            errorMessage = "購入に失敗しました。もう一度お試しください。"
        }

        isPurchasing = false
    }

    // MARK: - 購入の復元

    /// 以前の購入を復元
    func restore() async {
        isPurchasing = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()

            if !isPremium {
                errorMessage = "復元できる購入が見つかりませんでした"
            }
        } catch {
            errorMessage = "復元に失敗しました。もう一度お試しください。"
        }

        isPurchasing = false
    }

    // MARK: - サブスクリプション状態の更新

    /// 現在のサブスクリプション状態を確認・更新
    func updateSubscriptionStatus() async {
        var foundActive = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }

            if transaction.productID == Self.premiumProductID {
                // 有効なサブスクリプションが存在
                foundActive = true
                expirationDate = transaction.expirationDate

                // トライアル判定
                if let offerType = transaction.offerType, offerType == .introductory {
                    isInTrial = true
                } else {
                    isInTrial = false
                }
            }
        }

        isPremium = foundActive
        if !foundActive {
            expirationDate = nil
            isInTrial = false
            // サブスク無効時はトライアル通知をキャンセル
            NotificationManager.shared.cancelTrialExpiryReminder()
        }
    }

    // MARK: - トランザクション監視

    /// バックグラウンドでトランザクション更新を監視
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let transaction = try? await self.checkVerified(result) {
                    await transaction.finish()
                    await self.updateSubscriptionStatus()
                }
            }
        }
    }

    // MARK: - 検証ヘルパー

    /// トランザクションの署名検証
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
}

/// StoreKit関連エラー
enum StoreError: LocalizedError {
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "購入の検証に失敗しました"
        }
    }
}
