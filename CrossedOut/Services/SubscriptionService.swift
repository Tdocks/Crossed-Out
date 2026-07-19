import Foundation
import StoreKit

/// StoreKit 2 entitlement listener for Crossed Out Plus.
@MainActor
final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    @Published private(set) var isPlus = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseInFlight = false
    @Published var lastError: String?

    /// DEBUG-only override so UI can be exercised without ASC products.
    @Published var debugForcePlus = false {
        didSet {
            UserDefaults.standard.set(debugForcePlus, forKey: "co.debug.forcePlus")
            recomputePlus()
        }
    }

    private var updatesTask: Task<Void, Never>?

    private init() {
        #if DEBUG
        debugForcePlus = UserDefaults.standard.bool(forKey: "co.debug.forcePlus")
        #endif
        updatesTask = Task { await listenForTransactions() }
    }

    deinit {
        updatesTask?.cancel()
    }

    var effectiveIsPlus: Bool {
        #if DEBUG
        if debugForcePlus { return true }
        #endif
        return isPlus
    }

    func start() async {
        await refreshProducts()
        await refreshEntitlements()
    }

    func refreshProducts() async {
        do {
            products = try await Product.products(for: PlusProducts.allIDs)
                .sorted { $0.price < $1.price }
        } catch {
            lastError = "Couldn't load Plus plans."
            print("SubscriptionService: products failed: \(error)")
        }
    }

    func refreshEntitlements() async {
        var entitled = false
        var bestProduct: String?
        var expires: Date?
        var originalID: String?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            guard PlusProducts.allIDs.contains(tx.productID) else { continue }
            if tx.revocationDate != nil { continue }
            if let exp = tx.expirationDate, exp < Date() { continue }
            entitled = true
            bestProduct = tx.productID
            expires = tx.expirationDate
            originalID = String(tx.originalID)
        }

        isPlus = entitled
        recomputePlus()

        if entitled, let bestProduct {
            await syncToSupabase(
                productID: bestProduct,
                status: "active",
                expiresAt: expires,
                originalTransactionID: originalID
            )
        } else if !entitled {
            // Don't wipe server row on transient StoreKit failures — only
            // mark expired when we positively know there is no entitlement.
            // (Keep prior row; edge `is_plus` checks expires_at.)
        }
    }

    func purchase(_ product: Product) async -> Bool {
        purchaseInFlight = true
        lastError = nil
        defer { purchaseInFlight = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let tx) = verification else {
                    lastError = "Purchase couldn't be verified."
                    return false
                }
                await tx.finish()
                await refreshEntitlements()
                AnalyticsService.shared.track("plus_purchase_success", ["product": product.id])
                return true
            case .userCancelled:
                return false
            case .pending:
                lastError = "Purchase is pending approval."
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = "Purchase failed. Try again."
            AnalyticsService.shared.track("plus_purchase_fail")
            print("SubscriptionService: purchase failed: \(error)")
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            AnalyticsService.shared.track("plus_restore")
        } catch {
            lastError = "Restore failed."
        }
    }

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            if case .verified(let tx) = update {
                await tx.finish()
                await refreshEntitlements()
            }
        }
    }

    private func recomputePlus() {
        // Published isPlus already set; observers also watch debugForcePlus.
        objectWillChange.send()
    }

    private func syncToSupabase(
        productID: String,
        status: String,
        expiresAt: Date?,
        originalTransactionID: String?
    ) async {
        struct Params: Encodable {
            let p_product_id: String
            let p_status: String
            let p_expires_at: String?
            let p_original_transaction_id: String?
            let p_environment: String?
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let exp = expiresAt.map { iso.string(from: $0) }
        do {
            try await SupabaseService.shared.client
                .rpc("upsert_own_subscription", params: Params(
                    p_product_id: productID,
                    p_status: status,
                    p_expires_at: exp,
                    p_original_transaction_id: originalTransactionID,
                    p_environment: nil
                ))
                .execute()
        } catch {
            // Fallback without fractional seconds
            let plain = ISO8601DateFormatter()
            do {
                try await SupabaseService.shared.client
                    .rpc("upsert_own_subscription", params: Params(
                        p_product_id: productID,
                        p_status: status,
                        p_expires_at: expiresAt.map { plain.string(from: $0) },
                        p_original_transaction_id: originalTransactionID,
                        p_environment: nil
                    ))
                    .execute()
            } catch {
                print("SubscriptionService: sync failed: \(error)")
            }
        }
    }
}
