//
//  ApplePayModels.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/13/26.
//

import Foundation
import PassKit

/// A demo product that can be "purchased" with Apple Pay in the simulator.
struct DemoProduct: Identifiable, Hashable {
    let id: String
    let name: String
    let systemImage: String
    let price: Decimal

    static let catalog: [DemoProduct] = [
        DemoProduct(id: "cat-treats", name: "Cat Treats", systemImage: "pawprint.fill", price: 4.99),
        DemoProduct(id: "joke-book", name: "Chuck Norris Joke Book", systemImage: "book.fill", price: 12.50),
        DemoProduct(id: "dice", name: "Lucky Dice", systemImage: "dice.fill", price: 2.25),
        DemoProduct(id: "sticker", name: "Randomness Sticker Pack", systemImage: "sparkles", price: 1.99)
    ]
}

/// Result of a simulated payment authorization.
enum PaymentOutcome: Equatable {
    case success(transactionID: String, amount: String)
    case cancelled
    case failed(String)
}

/// Configuration shared by the view model and the payment request builder.
enum ApplePayConfiguration {
    /// Replace with a real merchant identifier when running on device.
    static let merchantIdentifier = "merchant.com.randomness.demo"
    static let countryCode = "US"
    static let currencyCode = "USD"
    static let supportedNetworks: [PKPaymentNetwork] = [.visa, .masterCard, .amex, .discover]
    static let merchantCapabilities: PKMerchantCapability = .capability3DS
}
