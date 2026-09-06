import Foundation
import Observation
import StoreKit

@Observable
final class TipViewModel {
    var tipProduct: Product?
    var paymentSuccess = false

    var canMakePayments: Bool {
        AppStore.canMakePayments
    }

    func loadProduct() async {
        tipProduct = try? await Product.products(for: ["tips1"]).first
    }

    @MainActor
    func purchaseTip() async throws {
        guard let product = tipProduct else { return }

        let result = try await product.purchase()

        switch result {
        case let .success(verification):
            if case let .verified(transaction) = verification {
                paymentSuccess = true
                await transaction.finish()
            }
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }
}
