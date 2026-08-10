//
//  ViewModelProtocol.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/9/26.
//

import Foundation
import Combine

/// Base abstraction every view model conforms to.
@MainActor
protocol ViewModelProtocol: ObservableObject {
    /// Called by the view when it appears. Default implementation does nothing.
    func onAppear()
}

extension ViewModelProtocol {
    func onAppear() {}
}

/// Abstraction for view models that perform asynchronous work.
@MainActor
protocol LoadableViewModel: ViewModelProtocol {
    var isLoading: Bool { get set }
    var errorMessage: String? { get set }
}

extension LoadableViewModel {
    /// Wraps an async throwing operation with loading/error state handling.
    func perform(_ operation: @escaping () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await operation()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
