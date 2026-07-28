import StoreKit
import Combine

/// 개발자 후원(팁) — StoreKit 2 소모성(Consumable) IAP.
/// 상품은 App Store Connect에서 아래 제품 ID와 동일하게 생성해야 실제 동작한다.
@MainActor
final class TipStore: ObservableObject {

    /// 소모성 IAP 제품 ID (아이스크림 / 커피 / 한끼)
    static let productIDs = [
        "com.tonyne.ilgigom.tip.icecream",
        "com.tonyne.ilgigom.tip.coffee",
        "com.tonyne.ilgigom.tip.meal",
    ]

    static func emoji(for id: String) -> String {
        switch id {
        case "com.tonyne.ilgigom.tip.icecream": return "🍦"
        case "com.tonyne.ilgigom.tip.coffee":   return "☕️"
        case "com.tonyne.ilgigom.tip.meal":     return "🍚"
        default:                                return "💝"
        }
    }

    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var loadFailed = false
    @Published var purchasing: String? = nil
    @Published var showThanks = false

    func load() async {
        isLoading = true
        loadFailed = false
        do {
            let items = try await Product.products(for: Self.productIDs)
            products = items.sorted { $0.price < $1.price }
            loadFailed = products.isEmpty
        } catch {
            loadFailed = true
        }
        isLoading = false
    }

    func purchase(_ product: Product) async {
        purchasing = product.id
        defer { purchasing = nil }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    showThanks = true
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            // 실패는 조용히 무시
        }
    }
}
