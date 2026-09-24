//
//  KitoDeliveryOptions.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore
import KitoCart

/// Standard, express, pickup and scheduled delivery as cards with price and ETA. Choosing pickup
/// opens the list of pickup points underneath.
///
/// ```swift
/// KitoDeliveryOptions([.standard(price: 250), .express(price: 450), .pickup(points: points)],
///                     selection: $optionID, pickupPoint: $pointID)
/// ```
public struct KitoDeliveryOptions: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let options: [KitoDeliveryOption]
    @Binding var selection: KitoDeliveryOption.ID?
    @Binding var pickupPoint: KitoPickupPoint.ID?
    let currencyCode: String
    let waivesFees: Bool
    let tint: Color?

    public init(
        _ options: [KitoDeliveryOption],
        selection: Binding<KitoDeliveryOption.ID?>,
        pickupPoint: Binding<KitoPickupPoint.ID?> = .constant(nil),
        currencyCode: String = KitoCheckoutDefaults.currencyCode,
        waivesFees: Bool = false,
        tint: Color? = nil
    ) {
        self.options = options
        _selection = selection
        _pickupPoint = pickupPoint
        self.currencyCode = currencyCode
        self.waivesFees = waivesFees
        self.tint = tint
    }

    private var accent: Color { theme.checkoutAccent(tint) }

    public var body: some View {
        VStack(spacing: theme.spacing.md) {
            ForEach(options) { option in
                card(option)
            }
        }
        .animation(KitoCheckoutMotion.spring(reduceMotion), value: selection)
    }

    private func card(_ option: KitoDeliveryOption) -> some View {
        let selected = option.id == selection
        return VStack(alignment: .leading, spacing: theme.spacing.md) {
            Button {
                selection = option.id
                if option.kind == .pickup, pickupPoint == nil { pickupPoint = option.pickupPoints.first?.id }
            } label: {
                KitoDeliveryOptionRow(option: option, isSelected: selected, waived: waivesFees, currencyCode: currencyCode,
                                      accent: accent, onAccent: theme.checkoutOnAccent(tint))
            }
            .buttonStyle(KitoCheckoutPressStyle())
            .disabled(!option.isAvailable)
            .accessibilityAddTraits(selected ? .isSelected : [])

            if selected && option.kind == .pickup && !option.pickupPoints.isEmpty {
                pickupList(option.pickupPoints)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .checkoutCard(selected: selected, accent: accent)
        .opacity(option.isAvailable ? 1 : 0.55)
    }

    private func pickupList(_ points: [KitoPickupPoint]) -> some View {
        VStack(spacing: 0) {
            ForEach(points) { point in
                Button {
                    pickupPoint = point.id
                } label: {
                    KitoPickupPointRow(point: point, isSelected: point.id == pickupPoint, accent: accent, onAccent: theme.checkoutOnAccent(tint))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(point.id == pickupPoint ? .isSelected : [])
                if point.id != points.last?.id {
                    Divider().padding(.leading, 40)
                }
            }
        }
        .padding(.horizontal, theme.spacing.md)
        .background(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).fill(theme.colors.surfaceMuted))
        .animation(KitoCheckoutMotion.spring(reduceMotion), value: pickupPoint)
    }
}

struct KitoDeliveryOptionRow: View {
    let option: KitoDeliveryOption
    let isSelected: Bool
    let waived: Bool
    let currencyCode: String
    let accent: Color
    let onAccent: Color
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isFree: Bool { option.price == 0 || waived }

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            KitoCheckoutIconTile(systemImage: option.kind.systemImage, color: iconColor, size: 44, isFilled: isSelected)
                .symbolEffect(.bounce, value: isSelected && !reduceMotion)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: theme.spacing.sm) {
                    Text(option.title)
                        .font(theme.typography.bodyEmphasized.weight(.bold))
                        .foregroundStyle(theme.colors.onSurface)
                    if let badge = option.badge {
                        KitoCheckoutBadge(text: badge, color: theme.colors.warning)
                    }
                }
                Label(option.eta.label, systemImage: "clock")
                    .font(theme.typography.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.onSurface.opacity(0.7))
                    .labelStyle(KitoCompactLabelStyle())
                if let reason = option.unavailableReason {
                    Text(reason).font(theme.typography.caption).foregroundStyle(theme.colors.danger)
                } else if let subtitle = option.subtitle {
                    Text(subtitle).font(theme.typography.caption).foregroundStyle(theme.colors.onSurface.opacity(0.55))
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: theme.spacing.sm)
            priceView
            KitoCheckoutRadio(isSelected: isSelected, accent: accent, onAccent: onAccent)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var iconColor: Color {
        switch option.kind {
        case .express: return isSelected ? accent : theme.colors.warning
        case .pickup: return isSelected ? accent : theme.colors.success
        case .standard, .scheduled: return accent
        }
    }

    @ViewBuilder
    private var priceView: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if isFree {
                Text("Free")
                    .font(theme.typography.label.weight(.heavy))
                    .foregroundStyle(theme.colors.success)
                if waived && option.price > 0 {
                    Text(KitoCartMoney.string(option.price, currencyCode: currencyCode))
                        .font(.caption2)
                        .strikethrough()
                        .foregroundStyle(theme.colors.onSurface.opacity(0.4))
                }
            } else {
                Text(KitoCartMoney.string(option.price, currencyCode: currencyCode))
                    .font(theme.typography.label.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(theme.colors.onSurface)
            }
        }
    }
}

struct KitoPickupPointRow: View {
    let point: KitoPickupPoint
    let isSelected: Bool
    let accent: Color
    let onAccent: Color
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            Image(systemName: isSelected ? "mappin.circle.fill" : "mappin.circle")
                .font(.title3)
                .foregroundStyle(isSelected ? accent : theme.colors.onSurface.opacity(0.4))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(point.name).font(theme.typography.label.weight(.semibold)).foregroundStyle(theme.colors.onSurface)
                Text(point.address).font(theme.typography.caption).foregroundStyle(theme.colors.onSurface.opacity(0.6))
                if !point.hours.isEmpty {
                    Text(point.hours).font(.caption2).foregroundStyle(theme.colors.onSurface.opacity(0.45))
                }
            }
            Spacer()
            if let distance = point.distanceText {
                Text(distance)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(theme.colors.onSurface.opacity(0.6))
            }
        }
        .padding(.vertical, theme.spacing.md)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
