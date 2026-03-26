import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var storeService: StoreService
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: AppSpacing.inlineGap)

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
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.top, AppSpacing.inlineGap)
            .padding(.bottom, AppSpacing.pageVertical)

            ScrollView {
                VStack(spacing: AppSpacing.sectionGap) {
                    // HeyBoyアイコン
                    HeyBoyIconView(bodyColor: .yellow, size: AppSize.iconLarge)
                        .padding(.top, AppSpacing.pageVertical)

                    // 機能説明
                    VStack(alignment: .leading, spacing: AppSpacing.itemGap) {
                        featureRow(icon: "bolt.fill", text: "LET'S GO が送れる")
                        featureRow(icon: "paintpalette.fill", text: "アイコンカラー全12色 + グラデーション")
                        featureRow(icon: "speaker.wave.2.fill", text: "カスタムサウンド")
                    }
                    .padding(.horizontal, AppSpacing.pageHorizontal)

                    // 価格 + 購入ボタン
                    VStack(spacing: AppSpacing.itemGap) {
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
                                .padding(.vertical, AppSpacing.pageVertical)
                                .background(AppColor.interactivePrimary)
                                .clipShape(Capsule())
                        }
                        .disabled(isPurchasing || storeService.products.isEmpty)
                        .opacity(isPurchasing || storeService.products.isEmpty ? 0.6 : 1)
                        .padding(.horizontal, AppSpacing.pageHorizontal)

                        Button(action: { restorePurchases() }) {
                            Text("RESTORE PURCHASES")
                                .font(.system(size: AppTypography.label, weight: .bold))
                                .foregroundColor(AppColor.textSecondary)
                        }
                        .disabled(isPurchasing)
                    }
                    .padding(.top, AppSpacing.pageVertical)
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
        .onChange(of: storeService.isPremium) { newValue in
            if newValue { dismiss() }
        }
    }

    // MARK: - コンポーネント

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: AppSpacing.itemGap) {
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
