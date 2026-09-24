//
//  KitoOrderSummary.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore
import KitoCart

/// The order at a glance: items with thumbnails (folded after a few), then subtotal, promo,
/// discounts, delivery, service fee, VAT, tip and a total whose digits roll when it changes.
///
/// ```swift
/// KitoOrderSummary(totals: model.totals)
/// KitoOrderSummary(totals: model.totals) { item in MyRemoteImage(item.imageURL) }
/// ```
public struct KitoOrderSummary<Thumbnail: View>: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let totals: KitoCheckoutTotals
    let currencyCode: String
    let foldsAfter: Int
    let tint: Color?
    let thumbnail: (KitoCartItem) -> Thumbnail

    @State private var expanded = false

    public init(
        totals: KitoCheckoutTotals,
        currencyCode: String = KitoCheckoutDefaults.currencyCode,
        foldsAfter: Int = 3,
        tint: Color? = nil,
        @ViewBuilder thumbnail: @escaping (KitoCartItem) -> Thumbnail
    ) {
        self.totals = totals
        self.currencyCode = currencyCode
        self.foldsAfter = max(foldsAfter, 1)
        self.tint = tint
        self.thumbnail = thumbnail
    }

    private var visibleItems: [KitoCartItem] {
        expanded ? totals.items : Array(totals.items.prefix(foldsAfter))
    }

    private var hiddenCount: Int { max(totals.items.count - foldsAfter, 0) }

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.lg) {
            itemsHeader
            VStack(spacing: theme.spacing.md) {
                ForEach(visibleItems) { item in
                    itemRow(item)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            if hiddenCount > 0 {
                foldButton
            }
            KitoDashedDivider(color: theme.colors.border)
            VStack(spacing: theme.spacing.sm) {
                ForEach(totals.lines.filter { $0.kind != .total }) { line in
                    KitoSummaryLineRow(line: line, currencyCode: currencyCode)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            KitoDashedDivider(color: theme.colors.border)
            totalRow
        }
        .checkoutCard(accent: theme.checkoutAccent(tint))
        .animation(KitoCheckoutMotion.spring(reduceMotion), value: totals.lines)
        .animation(KitoCheckoutMotion.spring(reduceMotion), value: expanded)
    }

    private var itemsHeader: some View {
        HStack {
            Text("Your order")
                .font(theme.typography.titleMedium)
                .foregroundStyle(theme.colors.onSurface)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Text(totals.itemCount == 1 ? "1 item" : "\(totals.itemCount) items")
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colors.onSurface.opacity(0.55))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(theme.colors.surfaceMuted))
        }
    }

    private func itemRow(_ item: KitoCartItem) -> some View {
        HStack(spacing: theme.spacing.md) {
            thumbnail(item)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.md, style: .continuous))
                .overlay(alignment: .topTrailing) { quantityBadge(item.quantity) }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(theme.typography.label.weight(.semibold))
                    .foregroundStyle(theme.colors.onSurface)
                    .lineLimit(1)
                if let subtitle = item.subtitle {
                    Text(subtitle).font(theme.typography.caption).foregroundStyle(theme.colors.onSurface.opacity(0.55)).lineLimit(1)
                }
            }
            Spacer(minLength: theme.spacing.sm)
            KitoMoneyText(amount: item.lineTotal, currencyCode: currencyCode, font: theme.typography.label.weight(.semibold))
                .foregroundStyle(theme.colors.onSurface)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func quantityBadge(_ quantity: Int) -> some View {
        if quantity > 1 {
            Text("\(quantity)")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colors.background)
                .frame(minWidth: 20, minHeight: 20)
                .background(Circle().fill(theme.colors.onBackground))
                .overlay(Circle().strokeBorder(theme.colors.surface, lineWidth: 2))
                .offset(x: 6, y: -6)
                .accessibilityLabel("Quantity \(quantity)")
        }
    }

    private var foldButton: some View {
        Button {
            expanded.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(expanded ? "Show less" : "Show \(hiddenCount) more")
                Image(systemName: "chevron.down").rotationEffect(.degrees(expanded ? 180 : 0))
            }
            .font(theme.typography.caption.weight(.bold))
            .foregroundStyle(theme.colors.onSurface.opacity(0.7))
        }
        .buttonStyle(.plain)
    }

    private var totalRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Total").font(theme.typography.titleMedium).foregroundStyle(theme.colors.onSurface)
                if totals.isVATIncluded && totals.vat > 0 {
                    Text("Includes " + KitoCartMoney.string(totals.vat, currencyCode: currencyCode) + " VAT")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.onSurface.opacity(0.5))
                }
            }
            Spacer()
            KitoMoneyText(amount: totals.total, currencyCode: currencyCode, font: .system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colors.onSurface)
        }
        .accessibilityElement(children: .combine)
    }
}

public extension KitoOrderSummary where Thumbnail == KitoItemThumbnail {
    init(totals: KitoCheckoutTotals, currencyCode: String = KitoCheckoutDefaults.currencyCode, foldsAfter: Int = 3, tint: Color? = nil) {
        self.init(totals: totals, currencyCode: currencyCode, foldsAfter: foldsAfter, tint: tint) { KitoItemThumbnail($0) }
    }
}

struct KitoSummaryLineRow: View {
    let line: KitoCheckoutLine
    let currencyCode: String
    @Environment(\.kitoTheme) private var theme

    private var isSaving: Bool { line.kind == .promo || line.kind == .discount }

    var body: some View {
        HStack(spacing: theme.spacing.sm) {
            titleView
            Spacer()
            if let original = line.originalAmount, line.amount == 0 {
                Text(KitoCartMoney.string(original, currencyCode: currencyCode))
                    .strikethrough()
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.onSurface.opacity(0.4))
                Text("Free")
                    .font(theme.typography.label.weight(.bold))
                    .foregroundStyle(theme.colors.success)
            } else {
                KitoMoneyText(amount: line.amount, currencyCode: currencyCode, font: theme.typography.label)
                    .foregroundStyle(amountColor)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var amountColor: Color {
        if isSaving { return theme.colors.success }
        if line.isIncluded { return theme.colors.onSurface.opacity(0.5) }
        return theme.colors.onSurface
    }

    @ViewBuilder
    private var titleView: some View {
        if line.kind == .promo {
            HStack(spacing: 6) {
                Text("Promo").font(theme.typography.label).foregroundStyle(theme.colors.onSurface.opacity(0.7))
                Label(line.title.replacingOccurrences(of: "Promo ", with: ""), systemImage: "tag.fill")
                    .font(.caption2.weight(.heavy))
                    .labelStyle(KitoCompactLabelStyle())
                    .foregroundStyle(theme.colors.success)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(theme.colors.success.opacity(0.14)))
            }
        } else {
            Text(line.title)
                .font(theme.typography.label)
                .foregroundStyle(theme.colors.onSurface.opacity(line.isIncluded ? 0.5 : 0.7))
        }
    }
}

struct KitoDashedDivider: View {
    let color: Color

    var body: some View {
        Line()
            .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}
