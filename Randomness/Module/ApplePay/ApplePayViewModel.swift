//
//  ApplePayViewModel.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/13/26.
//

import SwiftUI
import Combine

@MainActor
protocol ApplePayViewModelProtocol: LoadableViewModel {
    var products: [DemoProduct] { get }
    var selectedIDs: Set<String> { get }
    var total: Decimal { get }
    var formattedTotal: String { get }
    var canMakePayments: Bool { get }
    var lastOutcome: PaymentOutcome? { get }

    func toggle(_ product: DemoProduct)
    func isSelected(_ product: DemoProduct) -> Bool
    func price(for product: DemoProduct) -> String
    func pay() async
    func dismissOutcome()
}

@MainActor
final class ApplePayViewModel: ApplePayViewModelProtocol {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var products: [DemoProduct]
    @Published private(set) var selectedIDs: Set<String> = []
    @Published private(set) var lastOutcome: PaymentOutcome?

    private let service: ApplePayServiceProtocol

    init(
        service: ApplePayServiceProtocol,
        products: [DemoProduct] = DemoProduct.catalog
    ) {
        self.service = service
        self.products = products
        if let first = products.first { selectedIDs = [first.id] }
    }

    var canMakePayments: Bool { service.canMakePayments }

    var selectedProducts: [DemoProduct] {
        products.filter { selectedIDs.contains($0.id) }
    }

    var total: Decimal {
        selectedProducts.reduce(Decimal.zero) { $0 + $1.price }
    }

    var formattedTotal: String { Self.format(total) }

    func isSelected(_ product: DemoProduct) -> Bool {
        selectedIDs.contains(product.id)
    }

    func price(for product: DemoProduct) -> String {
        Self.format(product.price)
    }

    func toggle(_ product: DemoProduct) {
        if selectedIDs.contains(product.id) {
            selectedIDs.remove(product.id)
        } else {
            selectedIDs.insert(product.id)
        }
    }

    func pay() async {
        guard !selectedProducts.isEmpty else {
            errorMessage = "Select at least one item."
            return
        }

        isLoading = true
        errorMessage = nil
        let outcome = await service.pay(for: selectedProducts)
        isLoading = false

        switch outcome {
        case .success:
            lastOutcome = outcome
        case .cancelled:
            lastOutcome = nil
        case .failed(let message):
            lastOutcome = nil
            errorMessage = message
        }
    }

    func dismissOutcome() {
        lastOutcome = nil
        errorMessage = nil
    }

    private static func format(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = ApplePayConfiguration.currencyCode
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }
}
