//
//  ApplePayView.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/13/26.
//

import SwiftUI
import PassKit

struct ApplePayView<ViewModel: ApplePayViewModelProtocol>: View {
    @StateObject private var viewModel: ViewModel

    init(viewModel: @autoclosure @escaping () -> ViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        List {
            Section {
                ForEach(viewModel.products) { product in
                    Button {
                        viewModel.toggle(product)
                    } label: {
                        ProductRow(
                            product: product,
                            price: viewModel.price(for: product),
                            isSelected: viewModel.isSelected(product)
                        )
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Cart")
            } footer: {
                Text("Demo only — no payment is processed. Use the Simulator's Wallet test cards.")
            }

            Section {
                HStack {
                    Text("Total").font(.headline)
                    Spacer()
                    Text(viewModel.formattedTotal)
                        .font(.headline.monospacedDigit())
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if viewModel.canMakePayments {
                    ApplePayButton { Task { await viewModel.pay() } }
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .disabled(viewModel.isLoading)
                        .opacity(viewModel.isLoading ? 0.5 : 1)
                } else {
                    Label(
                        "Apple Pay is unavailable. Add a test card in the Simulator's Wallet app.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
            }
            .padding(16)
            .background(.bar)
        }
        .overlay {
            if viewModel.isLoading { ProgressView() }
        }
        .alert(
            "Payment complete",
            isPresented: Binding(
                get: { viewModel.lastOutcome != nil },
                set: { if !$0 { viewModel.dismissOutcome() } }
            )
        ) {
            Button("Done") { viewModel.dismissOutcome() }
        } message: {
            if case .success(let id, let method) = viewModel.lastOutcome {
                Text("Paid \(viewModel.formattedTotal) with \(method).\nTransaction: \(id.prefix(8))")
            }
        }
        .alert(
            "Payment failed",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.dismissOutcome() } }
            )
        ) {
            Button("OK") { viewModel.dismissOutcome() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .navigationTitle("Apple Pay")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.onAppear() }
    }
}

private struct ProductRow: View {
    let product: DemoProduct
    let price: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .imageScale(.large)

            Image(systemName: product.systemImage)
                .frame(width: 28)
                .foregroundStyle(.pink)

            Text(product.name)

            Spacer()

            Text(price)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

/// UIKit-backed `PKPaymentButton` so the demo uses the official Apple Pay mark.
struct ApplePayButton: UIViewRepresentable {
    var type: PKPaymentButtonType = .buy
    var style: PKPaymentButtonStyle = .automatic
    let action: () -> Void

    func makeUIView(context: Context) -> PKPaymentButton {
        let button = PKPaymentButton(paymentButtonType: type, paymentButtonStyle: style)
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.didTap),
            for: .touchUpInside
        )
        return button
    }

    func updateUIView(_ uiView: PKPaymentButton, context: Context) {
        context.coordinator.action = action
    }

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func didTap() { action() }
    }
}

#Preview {
    NavigationStack {
        ApplePayView(viewModel: ApplePayViewModel(service: MockApplePayService()))
    }
}
