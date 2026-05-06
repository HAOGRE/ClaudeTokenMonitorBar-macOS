import StoreKit
import Foundation

@Observable
@MainActor
final class PurchaseManager {
    static let shared = PurchaseManager()

    static let monthlyID  = "com.haogre.claudetokenmonitor.monthly"
    static let lifetimeID = "com.haogre.claudetokenmonitor.lifetime"

    private(set) var products: [Product] = []
    private(set) var isPremium: Bool = false
    private(set) var purchaseInProgress = false
    private(set) var errorMessage: String?

    private let premiumKey = "isPremium"
    private var transactionListenerTask: Task<Void, Never>?

    private init() {
        isPremium = UserDefaults.standard.bool(forKey: premiumKey)
        transactionListenerTask = listenForTransactions()
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: [Self.monthlyID, Self.lifetimeID])
            products = fetched.sorted { a, _ in a.id == Self.lifetimeID }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        purchaseInProgress = true
        errorMessage = nil
        defer { purchaseInProgress = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePremiumStatus()
                await transaction.finish()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            try await AppStore.sync()
            await updatePremiumStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Entitlement Verification

    func updatePremiumStatus() async {
        var hasAccess = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if (transaction.productID == Self.monthlyID || transaction.productID == Self.lifetimeID)
                && transaction.revocationDate == nil {
                hasAccess = true
            }
        }
        isPremium = hasAccess
        UserDefaults.standard.set(hasAccess, forKey: premiumKey)
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard let transaction = try? self.checkVerified(result) else { continue }
                await self.updatePremiumStatus()
                await transaction.finish()
            }
        }
    }

    // MARK: - JWS Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let value): return value
        }
    }
}
