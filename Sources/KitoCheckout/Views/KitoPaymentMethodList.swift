//
//  KitoPaymentMethodList.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// M-Pesa, saved cards, Apple Pay, cash on delivery and wallet balance, with an "Add a card" row.
/// Methods that can't pay this total (a wallet that's too low, an expired card, Apple Pay without
/// a merchant ID) are shown switched off with the reason.
///
/// ```swift
/// KitoPaymentMethodList([.mpesa(phone: "0712345678"), .card(.visa, last4: "4242", expiry: "08/28"),
///                        .applePay, .cashOnDelivery(limit: 10_000), .wallet(balance: 850)],
///                       selection: $methodID, total: totals.total,
///                       applePay: KitoApplePay.availability(for: applePayConfig)) { showAddCard = true }
/// ```
public struct KitoPaymentMethodList: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let methods: [KitoPaymentMethod]
    @Binding var selection: KitoPaymentMethod.ID?
    let total: Decimal
    let currencyCode: String
    let applePay: KitoApplePayAvailability
    let now: Date
    let tint: Color?
    let onAddCard: (() -> Void)?

    public init(
        _ methods: [KitoPaymentMethod],
        selection: Binding<KitoPaymentMethod.ID?>,
        total: Decimal,
        currencyCode: String = KitoCheckoutDefaults.currencyCode,
        applePay: KitoApplePayAvailability = .available,
        now: Date = Date(),
        tint: Color? = nil,
        onAddCard: (() -> Void)? = nil
    ) {
        self.methods = methods
        _selection = selection
        self.total = total
        self.currencyCode = currencyCode
        self.applePay = applePay
        self.now = now
        self.tint = tint
        self.onAddCard = onAddCard
    }

    private var accent: Color { theme.checkoutAccent(tint) }

    private func reason(for method: KitoPaymentMethod) -> String? {
        if method.isApplePay, let message = applePay.message { return message }
        return method.unavailableReason(total: total, currencyCode: currencyCode, now: now)
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(methods) { method in
                row(method)
                Divider().padding(.leading, 74)
            }
            if let onAddCard {
                addCardRow(onAddCard)
            }
        }
        .background(RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous).fill(theme.colors.surface))
        .overlay(RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous).strokeBorder(theme.colors.border.opacity(0.7), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
        .animation(KitoCheckoutMotion.spring(reduceMotion), value: selection)
    }

    private func row(_ method: KitoPaymentMethod) -> some View {
        let unavailable = reason(for: method)
        let selected = method.id == selection && unavailable == nil
        return Button {
            selection = method.id
        } label: {
            HStack(spacing: theme.spacing.md) {
                KitoPaymentMethodIcon(kind: method.kind)
                VStack(alignment: .leading, spacing: 2) {
                    Text(method.title)
                        .font(theme.typography.bodyEmphasized.weight(.semibold))
                        .foregroundStyle(theme.colors.onSurface)
                    Text(unavailable ?? method.subtitle(currencyCode: currencyCode))
                        .font(theme.typography.caption)
                        .foregroundStyle(unavailable == nil ? theme.colors.onSurface.opacity(0.55) : theme.colors.danger.opacity(0.9))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: theme.spacing.sm)
                KitoCheckoutRadio(isSelected: selected, accent: accent, onAccent: theme.checkoutOnAccent(tint))
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.vertical, theme.spacing.md)
            .background(selected ? accent.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(unavailable != nil)
        .opacity(unavailable == nil ? 1 : 0.6)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func addCardRow(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.md) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .foregroundStyle(theme.colors.border)
                    .frame(width: 46, height: 32)
                    .overlay(Image(systemName: "plus").font(.caption.weight(.bold)).foregroundStyle(accent))
                Text("Add a card")
                    .font(theme.typography.bodyEmphasized.weight(.semibold))
                    .foregroundStyle(accent)
                Spacer()
                Image(systemName: "chevron.forward").font(.caption.weight(.bold)).foregroundStyle(theme.colors.onSurface.opacity(0.3))
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.vertical, theme.spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A small card-shaped mark for each way to pay. Drawn with shapes and type — no logos bundled.
public struct KitoPaymentMethodIcon: View {
    let kind: KitoPaymentKind

    public init(kind: KitoPaymentKind) {
        self.kind = kind
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(background)
            .frame(width: 46, height: 32)
            .overlay { mark }
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
            .shadow(color: Color.black.opacity(0.12), radius: 3, y: 2)
            .accessibilityHidden(true)
    }

    private var background: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var colors: [Color] {
        switch kind {
        case .mpesa: return [Color(red: 0.20, green: 0.72, blue: 0.29), Color(red: 0.05, green: 0.52, blue: 0.20)]
        case .card(let brand, _, _):
            switch brand {
            case .visa: return [Color(red: 0.10, green: 0.20, blue: 0.62), Color(red: 0.05, green: 0.10, blue: 0.40)]
            case .mastercard: return [Color(red: 0.16, green: 0.16, blue: 0.18), Color(red: 0.05, green: 0.05, blue: 0.06)]
            case .amex: return [Color(red: 0.18, green: 0.47, blue: 0.80), Color(red: 0.09, green: 0.32, blue: 0.62)]
            case .other: return [Color(red: 0.45, green: 0.47, blue: 0.52), Color(red: 0.30, green: 0.32, blue: 0.36)]
            }
        case .applePay: return [Color(white: 0.12), Color.black]
        case .cashOnDelivery: return [Color(red: 0.93, green: 0.72, blue: 0.25), Color(red: 0.80, green: 0.55, blue: 0.10)]
        case .wallet: return [Color(red: 0.49, green: 0.34, blue: 0.93), Color(red: 0.33, green: 0.20, blue: 0.75)]
        }
    }

    @ViewBuilder
    private var mark: some View {
        switch kind {
        case .mpesa:
            HStack(spacing: 1) {
                Image(systemName: "iphone.gen2").font(.system(size: 10, weight: .bold))
                Text("M").font(.system(size: 13, weight: .black, design: .rounded))
            }
            .foregroundStyle(.white)
        case .card(let brand, _, _):
            cardMark(brand)
        case .applePay:
            HStack(spacing: 1) {
                Image(systemName: "apple.logo").font(.system(size: 11, weight: .semibold))
                Text("Pay").font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.white)
        case .cashOnDelivery:
            Image(systemName: "banknote.fill").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
        case .wallet:
            Image(systemName: "wallet.pass.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func cardMark(_ brand: KitoCardBrand) -> some View {
        switch brand {
        case .visa:
            Text("VISA").font(.system(size: 12, weight: .black)).italic().foregroundStyle(.white)
        case .mastercard:
            HStack(spacing: -7) {
                Circle().fill(Color(red: 0.92, green: 0.10, blue: 0.14)).frame(width: 15, height: 15)
                Circle().fill(Color(red: 0.97, green: 0.62, blue: 0.11).opacity(0.9)).frame(width: 15, height: 15)
            }
        case .amex:
            Text("AMEX").font(.system(size: 10, weight: .black)).foregroundStyle(.white)
        case .other:
            Image(systemName: "creditcard.fill").font(.system(size: 14)).foregroundStyle(.white)
        }
    }
}
