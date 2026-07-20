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
        var bestJWS: String?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            guard PlusProducts.allIDs.contains(tx.productID) else { continue }
            if tx.revocationDate != nil { continue }
            if let exp = tx.expirationDate, exp < Date() { continue }
            entitled = true
            // `result.jwsRepresentation` is the raw StoreKit 2 signed
            // transaction (JWS) for THIS verification result — the same
            // string Apple's servers can independently verify. This, not
            // any locally-read field, is what we hand the server.
            bestJWS = result.jwsRepresentation
        }

        // Optimistic local UI state from StoreKit's own on-device
        // verification (fast, but not server-authoritative).
        isPlus = entitled
        recomputePlus()

        if let bestJWS {
            // Authoritative: the edge function re-verifies this JWS's
            // signature server-side (Apple root-CA chain) and writes
            // `subscriptions` from ITS decoded payload, never from any
            // client-supplied product/status/expiry. Overwrites `isPlus`
            // with the server's resolved entitlement once it responds.
            await verifyWithServer(signedTransaction: bestJWS)
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

    // MARK: - Server-authoritative verification (edge function)

    private struct VerifySubscriptionRequestBody: Encodable {
        let signedTransaction: String
    }

    private struct VerifySubscriptionResponse: Decodable {
        let isPlus: Bool
        let status: String
        let productId: String?
        let expiresAt: String?
    }

    private struct VerifySubscriptionErrorBody: Decodable {
        let error: String?
    }

    /// Hands a StoreKit 2 signed transaction (JWS) to the `verify_subscription`
    /// edge function, which independently re-verifies its signature against
    /// Apple's root CA server-side and writes `public.subscriptions` from the
    /// VERIFIED payload — the client can no longer self-grant entitlement
    /// (see migration 0044, which revoked client execute on the old
    /// `upsert_own_subscription` RPC). Updates `isPlus` from the server's
    /// response, which is authoritative over the optimistic on-device value.
    private func verifyWithServer(signedTransaction: String) async {
        guard let session = SupabaseService.shared.client.auth.currentSession else {
            // No signed-in Supabase session yet (e.g. app launch race) —
            // local StoreKit entitlement still applies for this run; the
            // next refreshEntitlements() (post sign-in) will sync it.
            return
        }

        let url = SupabaseConfig.url.appendingPathComponent("functions/v1/verify_subscription")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.key, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(
                VerifySubscriptionRequestBody(signedTransaction: signedTransaction)
            )
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                print("SubscriptionService: verify_subscription bad response")
                return
            }
            guard (200...299).contains(http.statusCode) else {
                let detail = (try? JSONDecoder().decode(VerifySubscriptionErrorBody.self, from: data))?.error
                print("SubscriptionService: verify_subscription failed (\(http.statusCode)): \(detail ?? "-")")
                return
            }
            let decoded = try JSONDecoder().decode(VerifySubscriptionResponse.self, from: data)
            isPlus = decoded.isPlus
            recomputePlus()
        } catch {
            // Server round-trip failed (offline, timeout, etc). Leave the
            // optimistic on-device `isPlus` as-is and leave the prior
            // server-side row untouched — never downgrade entitlement on a
            // transient network failure.
            print("SubscriptionService: verify_subscription request failed: \(error)")
        }
    }
}
