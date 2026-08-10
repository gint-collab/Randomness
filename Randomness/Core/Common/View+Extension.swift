//
//  View+Extension.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/10/26.
//

import SwiftUI

// MARK: - Liquid Glass helpers

extension View {
    /// Applies the Liquid Glass material when available, falling back to a grouped card.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(cornerRadius)
        }
    }

    /// Lets the content flow under the glass tab bar edge effect.
    @ViewBuilder
    func scrollEdgeEffectHiddenIfAvailable(_ hidden: Bool) -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectHidden(hidden)
        } else {
            self
        }
    }

    /// Minimizes the Liquid Glass tab bar while scrolling down.
    @ViewBuilder
    func liquidGlassTabBar() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}
