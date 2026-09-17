import Foundation
import Observation
import StoreKit
import os

@Observable
final class TipViewModel {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "wallino-reader", category: "TipViewModel")

    var tipProduct: Product?
    var paymentSuccess = false

    var canMakePayments: Bool {
        AppStore.canMakePayments
    }

    func loadProduct() async {
        for attempt in 1 ... 3 {
            do {
                let products = try await Product.products(for: ["wallino.tip1"])
                if let product = products.first {
                    tipProduct = product
                    return
                }
                Self.logger.warning("Attempt \(attempt): Product 'wallino.tip1' not found in returned products.")
            } catch {
                Self.logger.warning("Attempt \(attempt): Failed to fetch products: \(error.localizedDescription)")
            }
            try? await Task.sleep(for: .seconds(1))
        }
        Self.logger.error("Failed to load tip product after 3 attempts.")
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
