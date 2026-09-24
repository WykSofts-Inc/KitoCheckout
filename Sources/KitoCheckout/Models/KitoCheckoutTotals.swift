//
//  KitoCheckoutTotals.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation
import KitoCart

/// Whether shelf prices already include VAT.
public enum KitoVATMode: String, Hashable, Sendable {
    /// Prices include VAT; the summary shows the VAT inside the total.
    case inclusive
    /// VAT is added on top at checkout.
    case exclusive
}

public struct KitoVAT: Hashable, Sendable {
    /// 16 means 16%.
    public var percent: Decimal
    public var mode: KitoVATMode
    /// Also charge VAT on the delivery and service fees.
    public var appliesToFees: Bool

    public init(percent: Decimal, mode: KitoVATMode = .inclusive, appliesToFees: Bool = false) {
        self.percent = max(percent, 0)
        self.mode = mode
        self.appliesToFees = appliesToFees
    }

    /// No VAT line at all.
    public static let none = KitoVAT(percent: 0, mode: .exclusive)
    /// Kenya's 16%, included in prices.
    public static let kenya = KitoVAT(percent: 16, mode: .inclusive)

    /// "VAT 16%" or "VAT 16% (included)".
    public var title: String {
        let rate = "VAT " + KitoCheckoutMath.string(percent) + "%"
        return mode == .inclusive ? rate + " (included)" : rate
    }

    /// The VAT in `base`: added on top when exclusive, the part already inside when inclusive.
    public func amount(on base: Decimal) -> Decimal {
        guard percent > 0, base > 0 else { return 0 }
        switch mode {
        case .exclusive: return KitoCheckoutMath.round(KitoCheckoutMath.percent(percent, of: base), scale: 2)
        case .inclusive: return KitoCheckoutMath.round(base * percent / (100 + percent), scale: 2)
        }
    }
}

/// A platform or service fee.
public enum KitoServiceFee: Hashable, Sendable {
    case none
    case fixed(Decimal)
    /// A percentage of the subtotal (5 = 5%), kept between an optional minimum and maximum.
    case percent(Decimal, minimum: Decimal? = nil, maximum: Decimal? = nil)

    public func amount(on subtotal: Decimal) -> Decimal {
        guard subtotal > 0 else { return 0 }
        switch self {
        case .none:
            return 0
        case .fixed(let fee):
            return max(fee, 0)
        case .percent(let percent, let minimum, let maximum):
            var fee = KitoCheckoutMath.round(KitoCheckoutMath.percent(percent, of: subtotal), scale: 2)
            if let minimum { fee = max(fee, minimum) }
            if let maximum { fee = min(fee, maximum) }
            return max(fee, 0)
        }
    }
}

/// A discount that isn't a promo code: loyalty points, a staff discount, a bundle deal.
public struct KitoCheckoutDiscount: Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var amount: Decimal

    public init(id: String = UUID().uuidString, title: String, amount: Decimal) {
        self.id = id
        self.title = title
        self.amount = max(amount, 0)
    }
}

/// How fees, VAT and rounding work for your shop.
public struct KitoCheckoutPricingRules: Hashable, Sendable {
    public var serviceFee: KitoServiceFee
    public var vat: KitoVAT
    /// Subtotal at which delivery becomes free; `nil` for never.
    public var freeDeliveryThreshold: Decimal?
    /// Round tips and the total to whole units — turn on for M-Pesa, which only takes whole shillings.
    public var roundsToWholeUnits: Bool

    public init(serviceFee: KitoServiceFee = .none, vat: KitoVAT = .none, freeDeliveryThreshold: Decimal? = nil, roundsToWholeUnits: Bool = true) {
        self.serviceFee = serviceFee
        self.vat = vat
        self.freeDeliveryThreshold = freeDeliveryThreshold
        self.roundsToWholeUnits = roundsToWholeUnits
    }
}

/// One line of the order summary.
public struct KitoCheckoutLine: Identifiable, Hashable, Sendable {
    public enum Kind: String, Hashable, Sendable {
        case subtotal, promo, discount, delivery, serviceFee, vat, tip, total
    }

    public let kind: Kind
    public let title: String
    /// Negative for discounts.
    public let amount: Decimal
    /// The fee before it was waived, for a struck-through "KES 250 Free".
    public let originalAmount: Decimal?
    /// VAT that's already inside the prices: shown, but not added.
    public let isIncluded: Bool

    public var id: String { kind.rawValue + title }

    public init(kind: Kind, title: String, amount: Decimal, originalAmount: Decimal? = nil, isIncluded: Bool = false) {
        self.kind = kind
        self.title = title
        self.amount = amount
        self.originalAmount = originalAmount
        self.isIncluded = isIncluded
    }
}

/// Everything the customer pays, worked out once from the items, fees, VAT, promo and tip.
///
/// Order of operations: subtotal → promo → other discounts → delivery (free past the threshold
/// or with a free-delivery code) → service fee on the subtotal → VAT on the discounted goods
/// (plus fees when configured) → tip on the subtotal → total, rounded when configured.
public struct KitoCheckoutTotals: Equatable, Sendable {
    public let items: [KitoCartItem]
    public let rules: KitoCheckoutPricingRules
    public let promo: KitoPromoCode?
    public let tip: KitoTip
    public let discounts: [KitoCheckoutDiscount]
    /// The delivery option's price before any free-delivery rule.
    public let deliveryPrice: Decimal

    public let subtotal: Decimal
    public let promoDiscount: Decimal
    public let isPromoEligible: Bool
    public let otherDiscounts: Decimal
    public let deliveryFee: Decimal
    public let waivedDeliveryFee: Decimal
    public let serviceFee: Decimal
    public let vat: Decimal
    public let tipAmount: Decimal
    public let total: Decimal

    public init(
        items: [KitoCartItem],
        rules: KitoCheckoutPricingRules = KitoCheckoutPricingRules(),
        deliveryFee: Decimal = 0,
        promo: KitoPromoCode? = nil,
        tip: KitoTip = .none,
        discounts: [KitoCheckoutDiscount] = []
    ) {
        self.items = items
        self.rules = rules
        self.promo = promo
        self.tip = tip
        self.discounts = discounts
        self.deliveryPrice = max(deliveryFee, 0)

        let subtotal = max(items.reduce(Decimal(0)) { $0 + $1.lineTotal }, 0)
        let cartRules = KitoCartPricingRules(deliveryFee: max(deliveryFee, 0), freeDeliveryThreshold: rules.freeDeliveryThreshold)
        let cartPricing = KitoCartPricing(subtotal: subtotal, rules: cartRules, promo: promo)
        let requested = discounts.reduce(Decimal(0)) { $0 + $1.amount }
        let other = min(requested, subtotal - cartPricing.discount)
        let goods = subtotal - cartPricing.discount - other
        let service = rules.serviceFee.amount(on: subtotal)
        let fees = cartPricing.deliveryFee + service
        let vatBase = goods + (rules.vat.appliesToFees ? fees : 0)
        let vat = rules.vat.amount(on: vatBase)
        let tipAmount = tip.amount(on: subtotal, wholeUnits: rules.roundsToWholeUnits)
        let added = rules.vat.mode == .exclusive ? vat : 0
        let raw = goods + fees + added + tipAmount

        self.subtotal = subtotal
        self.promoDiscount = cartPricing.discount
        self.isPromoEligible = cartPricing.isPromoEligible
        self.otherDiscounts = other
        self.deliveryFee = cartPricing.deliveryFee
        self.waivedDeliveryFee = cartPricing.waivedDeliveryFee
        self.serviceFee = service
        self.vat = vat
        self.tipAmount = tipAmount
        self.total = KitoCheckoutMath.round(raw, scale: rules.roundsToWholeUnits ? 0 : 2)
    }

    public var itemCount: Int { items.reduce(0) { $0 + $1.quantity } }
    public var discountTotal: Decimal { promoDiscount + otherDiscounts }
    public var isVATIncluded: Bool { rules.vat.mode == .inclusive }

    /// The lines to show, in order. Zero lines are left out except subtotal, delivery and total.
    public var lines: [KitoCheckoutLine] {
        var lines = [KitoCheckoutLine(kind: .subtotal, title: "Subtotal", amount: subtotal)]
        if let promo, promoDiscount > 0 {
            lines.append(KitoCheckoutLine(kind: .promo, title: "Promo " + promo.code, amount: -promoDiscount))
        }
        var budget = otherDiscounts
        for discount in discounts where discount.amount > 0 && budget > 0 {
            let applied = min(discount.amount, budget)
            budget -= applied
            lines.append(KitoCheckoutLine(kind: .discount, title: discount.title, amount: -applied))
        }
        let original: Decimal? = waivedDeliveryFee > 0 ? waivedDeliveryFee : nil
        lines.append(KitoCheckoutLine(kind: .delivery, title: "Delivery", amount: deliveryFee, originalAmount: original))
        if serviceFee > 0 { lines.append(KitoCheckoutLine(kind: .serviceFee, title: "Service fee", amount: serviceFee)) }
        if vat > 0 { lines.append(KitoCheckoutLine(kind: .vat, title: rules.vat.title, amount: vat, isIncluded: isVATIncluded)) }
        if tipAmount > 0 { lines.append(KitoCheckoutLine(kind: .tip, title: "Tip", amount: tipAmount)) }
        lines.append(KitoCheckoutLine(kind: .total, title: "Total", amount: total))
        return lines
    }

    /// The same maths with a different tip, for showing what each tip choice would cost.
    public func with(tip: KitoTip) -> KitoCheckoutTotals {
        KitoCheckoutTotals(items: items, rules: rules, deliveryFee: deliveryPrice, promo: promo, tip: tip, discounts: discounts)
    }
}
