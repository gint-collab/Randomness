//
//  ApplePayService.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/13/26.
//

import Foundation
import PassKit

/// Abstraction so the view model can be tested / previewed without PassKit.
@MainActor
protocol ApplePayServiceProtocol {
    /// `true` when the device (or simulator) can present an Apple Pay sheet.
    var canMakePayments: Bool { get }
    /// Presents the Apple Pay sheet and simulates a merchant authorization.
    func pay(for items: [DemoProduct]) async -> PaymentOutcome
}

/// Presents a real Apple Pay sheet but never contacts a payment processor.
/// The payment token is discarded and a fake transaction id is returned, which
/// is why this demo is intended for the Simulator only.
@MainActor
final class ApplePayService: NSObject, ApplePayServiceProtocol {

    private var continuation: CheckedContinuation<PaymentOutcome, Never>?
    private var outcome: PaymentOutcome = .cancelled

    var canMakePayments: Bool {
        PKPaymentAuthorizationController.canMakePayments()
    }

    func pay(for items: [DemoProduct]) async -> PaymentOutcome {
        guard !items.isEmpty else { return .failed("Your cart is empty.") }
        guard canMakePayments else {
            return .failed("Apple Pay is not available on this device.")
        }

        let request = Self.makeRequest(for: items)
        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = self

        outcome = .cancelled

        let presented = await controller.present()
        guard presented else {
            return .failed("Unable to present the Apple Pay sheet.")
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    // MARK: - Request

    static func makeRequest(for items: [DemoProduct]) -> PKPaymentRequest {
        let request = PKPaymentRequest()
        request.merchantIdentifier = ApplePayConfiguration.merchantIdentifier
        request.countryCode = ApplePayConfiguration.countryCode
        request.currencyCode = ApplePayConfiguration.currencyCode
        request.supportedNetworks = ApplePayConfiguration.supportedNetworks
        request.merchantCapabilities = ApplePayConfiguration.merchantCapabilities

        var summary = items.map {
            PKPaymentSummaryItem(label: $0.name, amount: NSDecimalNumber(decimal: $0.price))
        }
        let total = items.reduce(Decimal.zero) { $0 + $1.price }
        summary.append(
            PKPaymentSummaryItem(label: "Randomness", amount: NSDecimalNumber(decimal: total))
        )
        request.paymentSummaryItems = summary
        return request
    }

    private func finish(with outcome: PaymentOutcome) {
        continuation?.resume(returning: outcome)
        continuation = nil
    }
}

// MARK: - PKPaymentAuthorizationControllerDelegate

extension ApplePayService: PKPaymentAuthorizationControllerDelegate {

    nonisolated func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        // A production app would send `payment.token` to its backend here.
        let amount = payment.token.paymentMethod.displayName ?? "Simulated Card"
        Task { @MainActor in
            self.outcome = .success(
                transactionID: UUID().uuidString,
                amount: amount
            )
            completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
        }
    }

    nonisolated func paymentAuthorizationControllerDidFinish(
        _ controller: PKPaymentAuthorizationController
    ) {
        Task { @MainActor in
            controller.dismiss()
            self.finish(with: self.outcome)
        }
    }
}

/// Preview/test double that never touches PassKit.
@MainActor
struct MockApplePayService: ApplePayServiceProtocol {
    var canMakePayments: Bool = true
    var stubbedOutcome: PaymentOutcome = .success(
        transactionID: "PREVIEW-1234",
        amount: "Simulated Visa 1234"
    )

    func pay(for items: [DemoProduct]) async -> PaymentOutcome {
        try? await Task.sleep(nanoseconds: 400_000_000)
        return items.isEmpty ? .failed("Your cart is empty.") : stubbedOutcome
    }
}
