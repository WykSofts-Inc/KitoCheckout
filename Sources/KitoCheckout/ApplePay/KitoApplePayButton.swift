//
//  KitoApplePayButton.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import PassKit
import KitoCore

/// Apple's own Apple Pay button (`PKPaymentButton`), capsule-shaped by default.
///
/// ```swift
/// KitoApplePayButton(type: .buy) { Task { await pay() } }
/// ```
public struct KitoApplePayButton: View {
    let type: PKPaymentButtonType
    let style: PKPaymentButtonStyle
    let height: CGFloat
    let cornerRadius: CGFloat?
    let action: () -> Void

    /// - Parameters:
    ///   - style: `.automatic` is black in light mode and white in dark.
    ///   - cornerRadius: `nil` for a capsule.
    public init(type: PKPaymentButtonType = .buy, style: PKPaymentButtonStyle = .automatic, height: CGFloat = 52, cornerRadius: CGFloat? = nil, action: @escaping () -> Void) {
        self.type = type
        self.style = style
        self.height = height
        self.cornerRadius = cornerRadius
        self.action = action
    }

    public var body: some View {
        KitoPaymentButtonRepresentable(type: type, style: style, cornerRadius: cornerRadius ?? height / 2, action: action)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Pay with Apple Pay")
            .accessibilityAddTraits(.isButton)
    }
}

struct KitoPaymentButtonRepresentable: UIViewRepresentable {
    let type: PKPaymentButtonType
    let style: PKPaymentButtonStyle
    let cornerRadius: CGFloat
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> PKPaymentButton {
        let button = PKPaymentButton(paymentButtonType: type, paymentButtonStyle: style)
        button.cornerRadius = cornerRadius
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return button
    }

    func updateUIView(_ uiView: PKPaymentButton, context: Context) {
        uiView.cornerRadius = cornerRadius
        context.coordinator.action = action
    }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}

/// Explains why Apple Pay can't be used and what to do about it. Shows nothing when it can.
public struct KitoApplePayNotice: View {
    @Environment(\.kitoTheme) private var theme
    let availability: KitoApplePayAvailability
    let tint: Color?

    public init(availability: KitoApplePayAvailability, tint: Color? = nil) {
        self.availability = availability
        self.tint = tint
    }

    private var symbol: String {
        switch availability {
        case .notConfigured: return "wrench.and.screwdriver.fill"
        case .needsSetup: return "wallet.pass.fill"
        case .unsupported, .available: return "exclamationmark.triangle.fill"
        }
    }

    private var detail: String {
        switch availability {
        case .notConfigured: return "Choose M-Pesa or a card instead. Developers: add a merchant ID to the Apple Pay capability and pass it in KitoApplePayConfiguration."
        case .needsSetup: return "Open Wallet to add a card, or choose another way to pay."
        case .unsupported, .available: return "Choose M-Pesa, a card or cash on delivery instead."
        }
    }

    public var body: some View {
        if let message = availability.message {
            HStack(alignment: .top, spacing: theme.spacing.md) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint ?? theme.colors.warning)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill((tint ?? theme.colors.warning).opacity(0.15)))
                VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                    Text(message).font(theme.typography.label).foregroundStyle(theme.colors.onSurface)
                    Text(detail).font(theme.typography.caption).foregroundStyle(theme.colors.onSurface.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(theme.spacing.md)
            .background(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).fill(theme.colors.warning.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).strokeBorder(theme.colors.warning.opacity(0.3), lineWidth: 1))
            .accessibilityElement(children: .combine)
        }
    }
}
