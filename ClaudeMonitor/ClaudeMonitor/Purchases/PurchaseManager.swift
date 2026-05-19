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
    private(set) var purchasingProductID: String?   // Bug 3: track which product is purchasing
    private(set) var errorMessage: String?
    private(set) var productsLoadFailed = false      // Bug 2: distinguish load failure from loading
    private(set) var restoreMessage: String?         // Bug 4: explicit restore outcome feedback

    private let premiumKey = "isPremium"
    private var transactionListenerTask: Task<Void, Never>?
    private var l10n: L10n { L10n.shared }

    private init() {
        // Use cached value only as initial state; real check happens in updatePremiumStatus()
        isPremium = UserDefaults.standard.bool(forKey: premiumKey)
        transactionListenerTask = listenForTransactions()
        Task { await updatePremiumStatus() }
    }

    // MARK: - Load Products

    func loadProducts() async {
        // Reset per-session state each time the paywall appears
        purchaseInProgress = false
        purchasingProductID = nil
        errorMessage = nil
        restoreMessage = nil
        guard products.isEmpty else { return }
        productsLoadFailed = false
        do {
            let fetched = try await Product.products(for: [Self.monthlyID, Self.lifetimeID])
            products = fetched.sorted { a, _ in a.id == Self.monthlyID }
        } catch {
            // Bug 2: mark as failed so UI shows error + retry instead of infinite spinner
            productsLoadFailed = true
            errorMessage = error.localizedDescription
        }
    }

    // Bug 2: explicit retry — clears products so loadProducts() will re-fetch
    func retryLoadProducts() async {
        products = []
        productsLoadFailed = false
        await loadProducts()
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        purchaseInProgress = true
        purchasingProductID = product.id   // Bug 3: only this product shows spinner
        errorMessage = nil
        restoreMessage = nil
        defer {
            purchaseInProgress = false
            purchasingProductID = nil
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePremiumStatus()
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                errorMessage = l10n.str(.purchasePending)   // Bug 6: localized string
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
        errorMessage = nil
        restoreMessage = nil
        defer { purchaseInProgress = false }
        do {
            let wasPremiuBefore = isPremium
            try await AppStore.sync()
            await updatePremiumStatus()
            // Bug 4: provide explicit feedback about restore outcome
            if isPremium {
                restoreMessage = l10n.str(.purchaseRestoreSuccess)
            } else if !wasPremiuBefore {
                // Was free before and still free → no purchases found
                restoreMessage = l10n.str(.purchaseRestoreNotFound)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Entitlement Verification

    func updatePremiumStatus() async {
        var hasAccess = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            let isMonthly = transaction.productID == Self.monthlyID
            let isLifetime = transaction.productID == Self.lifetimeID
            guard isMonthly || isLifetime else { continue }
            guard transaction.revocationDate == nil else { continue }
            // For subscriptions, also check expiration date
            if let expDate = transaction.expirationDate, expDate < Date() { continue }
            hasAccess = true
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
