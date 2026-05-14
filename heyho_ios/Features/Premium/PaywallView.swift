import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var storeService: StoreService
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: AppSpacing.spSmall)

            // ヘッダー
            ZStack {
                Text("PREMIUM")
                    .font(.system(size: AppTypography.body, weight: .bold))
                    .foregroundColor(AppColor.textPrimary)

                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: AppTypography.body, weight: .bold))
                            .foregroundColor(AppColor.iconInverse)
                            .frame(width: AppSize.buttonIcon, height: AppSize.buttonIcon)
                            .background(Color(white: 0.8))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, AppSpacing.spXlarge)
            .padding(.top, AppSpacing.spSmall)
            .padding(.bottom, AppSpacing.spLarge)

            ScrollView {
                VStack(spacing: AppSpacing.spXxlarge) {
                    // HeyBoyアイコン
                    HeyBoyIconView(bodyColor: AppColor.defaultIconColor, size: AppSize.iconLarge)
                        .padding(.top, AppSpacing.spLarge)

                    // 機能説明
                    VStack(alignment: .leading, spacing: AppSpacing.spMedium) {
                        featureRow(icon: "bolt.fill", text: String(localized: "Send LET'S GO"))
                        featureRow(icon: "paintpalette.fill", text: String(localized: "All 12 icon colors + gradients"))
                        featureRow(icon: "speaker.wave.2.fill", text: String(localized: "Custom sounds"))
                    }
                    .padding(.horizontal, AppSpacing.spXlarge)

                    // 価格 + 購入ボタン
                    VStack(spacing: AppSpacing.spMedium) {
                        if let product = storeService.products.first {
                            Text(product.displayPrice)
                                .font(.system(size: AppTypography.display, weight: .black))
                                .foregroundColor(AppColor.textPrimary)
                        }

                        Button(action: { purchasePremium() }) {
                            Text("UNLOCK PREMIUM")
                                .font(.system(size: AppTypography.body, weight: .bold))
                                .foregroundColor(AppColor.iconInverse)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.spLarge)
                                .background(AppColor.interactivePrimary)
                                .clipShape(Capsule())
                        }
                        .disabled(isPurchasing || storeService.products.isEmpty)
                        .opacity(isPurchasing || storeService.products.isEmpty ? 0.6 : 1)
                        .padding(.horizontal, AppSpacing.spXlarge)

                        Button(action: { restorePurchases() }) {
                            Text("RESTORE PURCHASES")
                                .font(.system(size: AppTypography.label, weight: .bold))
                                .foregroundColor(AppColor.textSecondary)
                        }
                        .disabled(isPurchasing)
                    }
                    .padding(.top, AppSpacing.spLarge)
                }
                .padding(.bottom, 40)
            }
        }
        .background(AppColor.backgroundSecondary)
        .onAppear {
            if storeService.products.isEmpty {
                Task { await storeService.loadProducts() }
            }
        }
        .errorAlert($storeService.purchaseError)
        .onChange(of: storeService.isPremium) {
            if storeService.isPremium { dismiss() }
        }
    }

    // MARK: - コンポーネント

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: AppSpacing.spMedium) {
            Image(systemName: icon)
                .font(.system(size: AppTypography.body))
                .foregroundColor(AppColor.interactivePrimary)
                .frame(width: AppSize.buttonIcon)
            Text(text)
                .font(.system(size: AppTypography.body, weight: .bold))
                .foregroundColor(AppColor.textPrimary)
        }
    }

    // MARK: - アクション

    private func purchasePremium() {
        isPurchasing = true
        Task {
            await storeService.purchase()
            await MainActor.run { isPurchasing = false }
        }
    }

    private func restorePurchases() {
        isPurchasing = true
        Task {
            await storeService.restorePurchases()
            await MainActor.run { isPurchasing = false }
        }
    }
}
