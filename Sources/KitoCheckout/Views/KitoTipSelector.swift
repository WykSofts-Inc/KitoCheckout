//
//  KitoTipSelector.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore
import KitoCart

/// No tip, 5 / 10 / 15 % (each showing what it comes to) or a custom amount.
///
/// ```swift
/// KitoTipSelector(tip: $tip, subtotal: totals.subtotal, title: "Tip your rider")
/// ```
public struct KitoTipSelector: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var tip: KitoTip
    let subtotal: Decimal
    let percents: [Int]
    let currencyCode: String
    let wholeUnits: Bool
    let title: String
    let message: String?
    let tint: Color?

    @State private var customText = ""
    @FocusState private var customFocused: Bool
    @Namespace private var namespace

    public init(
        tip: Binding<KitoTip>,
        subtotal: Decimal,
        percents: [Int] = KitoTip.standardPercents,
        currencyCode: String = KitoCheckoutDefaults.currencyCode,
        wholeUnits: Bool = true,
        title: String = "Tip your rider",
        message: String? = "Every shilling goes to your rider.",
        tint: Color? = nil
    ) {
        _tip = tip
        self.subtotal = subtotal
        self.percents = percents
        self.currencyCode = currencyCode
        self.wholeUnits = wholeUnits
        self.title = title
        self.message = message
        self.tint = tint
    }

    private var accent: Color { theme.checkoutAccent(tint) }
    private var choices: [KitoTip] { [.none] + percents.map { KitoTip.percent($0) } + [.custom(customAmount)] }
    private var customAmount: Decimal { Decimal(string: customText.filter { $0.isNumber || $0 == "." }) ?? 0 }
    private var tipAmount: Decimal { tip.amount(on: subtotal, wholeUnits: wholeUnits) }

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            header
            HStack(spacing: 6) {
                ForEach(Array(choices.enumerated()), id: \.offset) { _, choice in
                    chip(choice)
                }
            }
            .padding(4)
            .background(Capsule().fill(theme.colors.surfaceMuted))
            if tip.isCustom {
                customField
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .checkoutCard(accent: accent)
        .animation(KitoCheckoutMotion.spring(reduceMotion), value: tip)
    }

    private var header: some View {
        HStack(spacing: theme.spacing.md) {
            Image(systemName: tipAmount > 0 ? "heart.fill" : "heart")
                .font(.title3)
                .foregroundStyle(tipAmount > 0 ? theme.colors.danger : theme.colors.onSurface.opacity(0.4))
                .symbolEffect(.bounce, value: tipAmount)
                .contentTransition(.symbolEffect(.replace))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(theme.typography.bodyEmphasized.weight(.bold)).foregroundStyle(theme.colors.onSurface)
                if let message {
                    Text(message).font(theme.typography.caption).foregroundStyle(theme.colors.onSurface.opacity(0.55))
                }
            }
            Spacer()
            if tipAmount > 0 {
                KitoMoneyText(amount: tipAmount, currencyCode: currencyCode, font: theme.typography.label.weight(.bold))
                    .foregroundStyle(theme.colors.onSurface)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func isSelected(_ choice: KitoTip) -> Bool {
        switch (choice, tip) {
        case (.custom, .custom): return true
        default: return choice == tip
        }
    }

    private func chip(_ choice: KitoTip) -> some View {
        let selected = isSelected(choice)
        return Button {
            select(choice)
        } label: {
            VStack(spacing: 1) {
                Text(chipTitle(choice))
                    .font(.subheadline.weight(.bold))
                if case .percent = choice {
                    Text(KitoCartMoney.string(choice.amount(on: subtotal, wholeUnits: wholeUnits), currencyCode: currencyCode))
                        .font(.system(size: 9, weight: .semibold))
                        .opacity(0.7)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .foregroundStyle(selected ? theme.checkoutOnAccent(tint) : theme.colors.onSurface)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background {
                if selected {
                    Capsule().fill(accent.gradient)
                        .matchedGeometryEffect(id: "tip", in: namespace)
                        .shadow(color: accent.opacity(0.25), radius: 6, y: 3)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityTitle(choice))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func chipTitle(_ choice: KitoTip) -> String {
        switch choice {
        case .none: return "None"
        case .percent(let percent): return "\(percent)%"
        case .custom: return "Other"
        }
    }

    private func accessibilityTitle(_ choice: KitoTip) -> String {
        switch choice {
        case .none: return "No tip"
        case .percent(let percent): return "\(percent) percent, " + KitoCartMoney.string(choice.amount(on: subtotal, wholeUnits: wholeUnits), currencyCode: currencyCode)
        case .custom: return "Custom tip"
        }
    }

    private func select(_ choice: KitoTip) {
        if case .custom = choice {
            tip = .custom(customAmount)
            customFocused = true
        } else {
            customFocused = false
            tip = choice
        }
    }

    private var customField: some View {
        HStack(spacing: theme.spacing.sm) {
            Text(currencyCode)
                .font(theme.typography.label.weight(.bold))
                .foregroundStyle(theme.colors.onSurface.opacity(0.5))
            TextField("Amount", text: $customText)
                .keyboardType(.decimalPad)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .focused($customFocused)
                .onChange(of: customText) { _, _ in tip = .custom(customAmount) }
        }
        .padding(.horizontal, theme.spacing.md)
        .frame(height: 48)
        .background(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).fill(theme.colors.surfaceMuted))
        .overlay(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).strokeBorder(customFocused ? accent : Color.clear, lineWidth: 1.5))
    }
}
