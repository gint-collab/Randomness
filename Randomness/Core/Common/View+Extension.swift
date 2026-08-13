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

    /// Softens the bottom scroll edge so content stays legible as it passes
    /// under the glass tab bar. No-op before iOS 26, where the bar is opaque
    /// and content never scrolls beneath it.
    @ViewBuilder
    func softBottomScrollEdge() -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            self
        }
    }

    /// Prominent call-to-action button style: Liquid Glass on iOS 26,
    /// the classic bordered-prominent capsule before that.
    @ViewBuilder
    func prominentActionButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    
    /// Screen-level background matching native iOS grouped screens.
    /// Adapts automatically to light/dark mode.
    func defaultBackground() -> some View {
        self.background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    /// Surface for cards placed on top of ``defaultBackground()``, matching the
    /// native grouped-list cell background.
    func cardSurface(cornerRadius: CGFloat = 14) -> some View {
        self.background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
    
    @ViewBuilder
    func cardBackground() -> some View {
        if #available(iOS 26.0, *) {
            self.background(LinearGradient(colors: [Color.pink.opacity(0.8),
                                                    Color.red.opacity(0.8),
                                                    Color.purple.opacity(0.8)],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing))
        } else {
            self
        }
    }
}
