import SwiftUI
import StoreKit

struct PlusPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subs = SubscriptionService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    benefits
                    plans
                    if let err = subs.lastError {
                        Text(err)
                            .font(.coUI(13))
                            .foregroundColor(.coCrossRed)
                    }
                    restoreRow
                    footerLegal
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(Color.coPaper.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .font(.coUI(15, weight: .medium))
                        .foregroundColor(.coInkSecondary)
                }
            }
            .task { await subs.refreshProducts() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Crossed Out Plus")
                .font(.coDisplay(28, weight: .semibold))
                .foregroundColor(.coInk)
            Text("More room with Kyra — same gentle guide, without hitting today's wall so soon.")
                .font(.coUI(15))
                .foregroundColor(.coInkSecondary)
                .lineSpacing(4)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefit("Up to \(PlusProducts.plusKyraDailyLimit) Kyra messages / day", icon: .prayer)
            benefit("\(PlusProducts.freeKyraDailyLimit) / day stays free forever", icon: .leaf)
            benefit("Support the work that keeps Scripture personal", icon: .heart)
        }
    }

    private func benefit(_ text: String, icon: COIconName) -> some View {
        HStack(spacing: 12) {
            COIcon(icon, size: 18, color: .coOlive)
            Text(text)
                .font(.coUI(14))
                .foregroundColor(.coInk)
            Spacer(minLength: 0)
        }
    }

    /// True only when launched via the CO_SCREEN=plus debug route (used for
    /// capturing App Store review screenshots). Never true in a normal build.
    private var isReviewCapture: Bool {
        ProcessInfo.processInfo.environment["CO_SCREEN"] == "plus"
    }

    private func staticPlan(_ name: String, _ price: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.coUI(16, weight: .semibold)).foregroundColor(.white)
                Text(price).font(.coUI(13)).foregroundColor(.white.opacity(0.85))
            }
            Spacer()
        }
        .padding(16)
        .background(Color.coCrossRed)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var plans: some View {
        VStack(spacing: 12) {
            if isReviewCapture {
                staticPlan("Crossed Out Plus (Monthly)", "$7.99 / month")
                staticPlan("Crossed Out Plus (Annual)", "$59.99 / year")
            } else if subs.products.isEmpty {
                COCard {
                    Text("Plans load from the App Store. If you're testing locally, use the included StoreKit config file — or turn on Debug → Simulate Plus in Settings.")
                        .font(.coUI(13))
                        .foregroundColor(.coInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ForEach(subs.products, id: \.id) { product in
                    planButton(product)
                }
            }
        }
    }

    private func planButton(_ product: Product) -> some View {
        Button {
            Task {
                let ok = await subs.purchase(product)
                if ok { dismiss() }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName.isEmpty ? label(for: product.id) : product.displayName)
                        .font(.coUI(16, weight: .semibold))
                        .foregroundColor(.white)
                    Text(product.displayPrice + period(for: product))
                        .font(.coUI(13))
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                if subs.purchaseInFlight {
                    ProgressView().tint(.white)
                }
            }
            .padding(16)
            .background(Color.coCrossRed)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(subs.purchaseInFlight)
    }

    private var restoreRow: some View {
        Button {
            Task { await subs.restore() }
        } label: {
            Text("Restore purchases")
                .font(.coUI(14, weight: .medium))
                .foregroundColor(.coInkSecondary)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var footerLegal: some View {
        Text("Payment is charged to your Apple ID. Subscription renews unless canceled at least 24 hours before the period ends. Manage in Settings → Apple ID → Subscriptions.")
            .font(.coUI(11))
            .foregroundColor(.coInkTertiary)
            .lineSpacing(3)
    }

    private func label(for id: String) -> String {
        id == PlusProducts.annualID ? "Plus Annual" : "Plus Monthly"
    }

    private func period(for product: Product) -> String {
        guard let sub = product.subscription else { return "" }
        switch sub.subscriptionPeriod.unit {
        case .year: return " / year"
        case .month: return " / month"
        default: return ""
        }
    }
}
