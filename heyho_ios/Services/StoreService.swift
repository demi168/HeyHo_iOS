import StoreKit

@MainActor
final class StoreService: ObservableObject {
    static let shared = StoreService()

    @Published private(set) var isPremium = false
    @Published private(set) var products: [Product] = []
    @Published var purchaseError: String?

    private var transactionListener: Task<Void, Never>?

    private init() {}

    // MARK: - 初期化

    /// アプリ起動時に呼ぶ。トランザクション監視を開始し、既存購入を復元する。
    func configure() {
        transactionListener = Task {
            for await result in Transaction.updates {
                await handleTransaction(result)
            }
        }
        Task {
            await checkCurrentEntitlements()
            await loadProducts()
        }
    }

    // MARK: - 商品取得

    func loadProducts() async {
        do {
            products = try await Product.products(for: [PremiumConfig.productId])
        } catch {
            print("[StoreService] 商品取得失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - 購入

    func purchase() async {
        guard let product = products.first else {
            purchaseError = "商品情報を取得できません"
            return
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handleTransaction(verification)
            case .userCancelled:
                break
            case .pending:
                purchaseError = "購入が保留中です"
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - 復元

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkCurrentEntitlements()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - エンタイトルメント確認

    private func checkCurrentEntitlements() async {
        var hasPremium = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == PremiumConfig.productId,
               transaction.revocationDate == nil {
                hasPremium = true
                break
            }
        }
        isPremium = hasPremium
    }

    // MARK: - デバッグ用

    #if DEBUG
    /// テスト用: プレミアム状態を即時リセット
    func debugRevokePremium() {
        isPremium = false
    }
    #endif

    // MARK: - トランザクション処理

    private func handleTransaction(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if transaction.productID == PremiumConfig.productId {
            isPremium = transaction.revocationDate == nil
        }
        await transaction.finish()
    }
}
