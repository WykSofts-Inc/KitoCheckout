//
//  KitoCheckoutStyle.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore
import KitoCart

extension KitoTheme {
    /// The tint, or the text colour (black in light mode, white in dark).
    func checkoutAccent(_ tint: Color?) -> Color { tint ?? colors.onBackground }

    /// What reads on top of `checkoutAccent`.
    func checkoutOnAccent(_ tint: Color?) -> Color { tint == nil ? colors.background : colors.onPrimary }
}

/// A full-strength capsule.
struct KitoCheckoutPrimaryButtonStyle: ButtonStyle {
    var tint: Color?
    var fullWidth = true
    @Environment(\.kitoTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.typography.button)
            .foregroundStyle(theme.checkoutOnAccent(tint))
            .padding(.horizontal, theme.spacing.xl)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 52)
            .background(Capsule().fill(theme.checkoutAccent(tint).gradient))
            .shadow(color: theme.checkoutAccent(tint).opacity(isEnabled ? 0.25 : 0), radius: 12, y: 6)
            .opacity(isEnabled ? (configuration.isPressed ? 0.88 : 1) : 0.35)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.25, bounce: 0.4), value: configuration.isPressed)
    }
}

/// An outlined capsule for the second action.
struct KitoCheckoutSecondaryButtonStyle: ButtonStyle {
    var tint: Color?
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.typography.button)
            .foregroundStyle(theme.checkoutAccent(tint))
            .padding(.horizontal, theme.spacing.xl)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Capsule().fill(theme.colors.surface))
            .overlay(Capsule().strokeBorder(theme.colors.border, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.25, bounce: 0.4), value: configuration.isPressed)
    }
}

/// Press feedback for tappable cards.
struct KitoCheckoutPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.22, bounce: 0.35), value: configuration.isPressed)
    }
}

/// A raised surface card that picks up an accent border when selected.
struct KitoCheckoutCardModifier: ViewModifier {
    var isSelected = false
    var accent: Color
    var padding: CGFloat?
    @Environment(\.kitoTheme) private var theme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous)
        content
            .padding(padding ?? theme.spacing.lg)
            .background(shape.fill(theme.colors.surface))
            .overlay(shape.strokeBorder(isSelected ? accent : theme.colors.border.opacity(0.7), lineWidth: isSelected ? 2 : 1))
            .shadow(color: Color.black.opacity(isSelected ? 0.10 : 0.05), radius: isSelected ? 16 : 10, y: isSelected ? 8 : 4)
    }
}

extension View {
    func checkoutCard(selected: Bool = false, accent: Color, padding: CGFloat? = nil) -> some View {
        modifier(KitoCheckoutCardModifier(isSelected: selected, accent: accent, padding: padding))
    }
}

/// The round radio at the end of a selectable row.
struct KitoCheckoutRadio: View {
    let isSelected: Bool
    let accent: Color
    var onAccent: Color
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().strokeBorder(isSelected ? accent : theme.colors.border, lineWidth: 2)
            Circle().fill(accent).scaleEffect(isSelected ? 1 : 0.2).opacity(isSelected ? 1 : 0)
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(onAccent)
                .scaleEffect(isSelected ? 1 : 0.4)
                .opacity(isSelected ? 1 : 0)
        }
        .frame(width: 24, height: 24)
        .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.5), value: isSelected)
        .accessibilityHidden(true)
    }
}

/// A tinted tile holding a symbol.
struct KitoCheckoutIconTile: View {
    let systemImage: String
    let color: Color
    var size: CGFloat = 44
    var isFilled = false

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
            .fill(isFilled ? AnyShapeStyle(color.gradient) : AnyShapeStyle(color.opacity(0.14)))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(isFilled ? Color.white : color)
            }
            .accessibilityHidden(true)
    }
}

/// A section title with an optional trailing action.
struct KitoCheckoutSectionHeader: View {
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.typography.titleMedium)
                    .foregroundStyle(theme.colors.onBackground)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle).font(theme.typography.caption).foregroundStyle(theme.colors.onBackground.opacity(0.55))
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(theme.typography.label)
                    .foregroundStyle(theme.colors.onBackground)
            }
        }
    }
}

/// A money amount that rolls its digits when it changes.
struct KitoMoneyText: View {
    let amount: Decimal
    let currencyCode: String
    var font: Font?
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(KitoCartMoney.string(amount, currencyCode: currencyCode))
            .font(font ?? theme.typography.bodyEmphasized)
            .monospacedDigit()
            .contentTransition(reduceMotion ? .identity : .numericText(value: KitoCheckoutMath.double(amount)))
            .animation(reduceMotion ? nil : .snappy(duration: 0.35), value: amount)
    }
}

/// A small capsule label: "Default", "Fastest".
struct KitoCheckoutBadge: View {
    let text: String
    let color: Color
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.14)))
    }
}

enum KitoCheckoutMotion {
    static func spring(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.84)
    }
}
