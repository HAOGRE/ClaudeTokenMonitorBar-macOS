import StoreKit
import SwiftUI

// MARK: - LockedOverlay

struct LockedOverlay: View {
    let message: String
    let onUnlock: () -> Void
    private var l10n: L10n { L10n.shared }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .cornerRadius(8)
            VStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button(l10n.str(.unlockButton)) {
                    onUnlock()
                }
                .buttonStyle(.borderedProminent)
                .font(.caption)
                .controlSize(.small)
            }
            .padding(12)
        }
    }
}

// MARK: - PaywallView

struct PaywallView: View {
    @Environment(PurchaseManager.self) private var pm
    var onDismiss: () -> Void
    private var l10n: L10n { L10n.shared }

    var body: some View {
        VStack(spacing: 0) {
            // Dismiss button
            HStack {
                Spacer()
                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Hero
            VStack(spacing: 6) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.yellow)
                Text(l10n.str(.paywallTitle))
                    .font(.headline)
                Text(l10n.str(.paywallSubtitle))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 4)
            .padding(.bottom, 16)

            // Feature list
            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "sun.max.fill", color: .orange, text: l10n.str(.paywallFeatureToday))
                FeatureRow(icon: "chart.bar.fill", color: .purple, text: l10n.str(.paywallFeatureChart))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            Divider()

            // Products
            Group {
                if pm.products.isEmpty {
                    ProgressView()
                        .padding(.vertical, 20)
                } else {
                    VStack(spacing: 8) {
                        ForEach(pm.products, id: \.id) { product in
                            ProductRow(product: product)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }

            // Error
            if let err = pm.errorMessage {
                Text(err)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }

            // Restore
            Button(l10n.str(.paywallRestore)) {
                Task { await pm.restorePurchases() }
            }
            .font(.caption)
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
            .padding(.bottom, 12)
        }
        .frame(width: 300)
        .background(Color(.windowBackgroundColor))
        .task { await pm.loadProducts() }
    }
}

// MARK: - ProductRow

private struct ProductRow: View {
    @Environment(PurchaseManager.self) private var pm
    let product: Product
    private var isLifetime: Bool { product.id == PurchaseManager.lifetimeID }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.displayName)
                    .font(.callout).fontWeight(.semibold)
                Text(product.description)
                    .font(.caption2).foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                Task { await pm.purchase(product) }
            } label: {
                if pm.purchaseInProgress {
                    ProgressView().scaleEffect(0.7).frame(width: 50)
                } else {
                    Text(product.displayPrice)
                        .font(.callout).fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(pm.purchaseInProgress)
        }
        .padding(12)
        .background(isLifetime ? Color.accentColor.opacity(0.08) : Color(.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isLifetime ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - FeatureRow

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 16)
            Text(text).font(.caption)
            Spacer()
        }
    }
}
