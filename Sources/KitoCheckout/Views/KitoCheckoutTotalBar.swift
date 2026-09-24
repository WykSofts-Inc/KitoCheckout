//
//  KitoCheckoutTotalBar.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// What the bar's button is.
public enum KitoCheckoutBarButton: Equatable, Sendable {
    case standard(String)
    /// Apple's Apple Pay button.
    case applePay
}

/// The sticky bar at the bottom of the checkout: the live total, a caption, a hint when the
/// step isn't complete, and the primary button.
///
/// ```swift
/// KitoCheckoutTotalBar(total: totals.total, caption: "Includes VAT", button: .standard("Place order"),
///                      hint: issues.first?.message, isEnabled: issues.isEmpty) { place() }
/// ```
public struct KitoCheckoutTotalBar: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let total: Decimal
    let currencyCode: String
    let caption: String?
    let button: KitoCheckoutBarButton
    let hint: String?
    let isEnabled: Bool
    let isLoading: Bool
    let tint: Color?
    let action: () -> Void

    public init(
        total: Decimal,
        currencyCode: String = KitoCheckoutDefaults.currencyCode,
        caption: String? = nil,
        button: KitoCheckoutBarButton,
        hint: String? = nil,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.total = total
        self.currencyCode = currencyCode
        self.caption = caption
        self.button = button
        self.hint = hint
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        VStack(spacing: theme.spacing.md) {
            if let hint, !isEnabled {
                hintRow(hint)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            HStack(alignment: .center, spacing: theme.spacing.lg) {
                totalBlock
                buttonView
            }
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.top, theme.spacing.md)
        .padding(.bottom, theme.spacing.sm)
        .background(barBackground)
        .animation(KitoCheckoutMotion.spring(reduceMotion), value: hint)
        .animation(KitoCheckoutMotion.spring(reduceMotion), value: isEnabled)
    }

    private var totalBlock: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Total")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.onBackground.opacity(0.55))
            KitoMoneyText(amount: total, currencyCode: currencyCode, font: .system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colors.onBackground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(theme.colors.onBackground.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var buttonView: some View {
        switch button {
        case .applePay:
            KitoApplePayButton(type: .buy, action: action)
                .disabled(!isEnabled || isLoading)
                .opacity(isEnabled ? 1 : 0.4)
                .overlay { if isLoading { ProgressView().tint(theme.colors.onBackground) } }
        case .standard(let title):
            Button(action: action) {
                ZStack {
                    Text(title).opacity(isLoading ? 0 : 1)
                    if isLoading { ProgressView().tint(theme.checkoutOnAccent(tint)) }
                }
                .contentTransition(.opacity)
            }
            .buttonStyle(KitoCheckoutPrimaryButtonStyle(tint: tint))
            .disabled(!isEnabled || isLoading)
            .accessibilityHint(hint ?? "")
        }
    }

    private func hintRow(_ text: String) -> some View {
        HStack(spacing: theme.spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(theme.colors.warning)
            Text(text)
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colors.onBackground.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.sm)
        .background(Capsule().fill(theme.colors.warning.opacity(0.12)))
    }

    private var barBackground: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(alignment: .top) { Rectangle().fill(theme.colors.border.opacity(0.6)).frame(height: 0.5) }
            .shadow(color: Color.black.opacity(0.08), radius: 16, y: -4)
            .ignoresSafeArea(edges: .bottom)
    }
}
