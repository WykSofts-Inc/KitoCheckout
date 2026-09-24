//
//  KitoTip.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation
import KitoCart

/// A tip for the rider or staff.
public enum KitoTip: Hashable, Sendable {
    case none
    /// A percentage of the subtotal: `.percent(10)` is 10%.
    case percent(Int)
    /// A set amount.
    case custom(Decimal)

    /// The usual choices.
    public static let standardPercents = [5, 10, 15]

    /// The tip on `subtotal`. Percentage tips are rounded to whole units when `wholeUnits` is on
    /// (nobody tips KES 12.35), otherwise to cents.
    public func amount(on subtotal: Decimal, wholeUnits: Bool = true) -> Decimal {
        switch self {
        case .none:
            return 0
        case .percent(let percent):
            let raw = KitoCheckoutMath.percent(Decimal(max(percent, 0)), of: max(subtotal, 0))
            return KitoCheckoutMath.round(raw, scale: wholeUnits ? 0 : 2)
        case .custom(let amount):
            return max(amount, 0)
        }
    }

    /// "No tip", "10%", "KES 150".
    public func label(currencyCode: String = KitoCheckoutDefaults.currencyCode) -> String {
        switch self {
        case .none: return "No tip"
        case .percent(let percent): return "\(percent)%"
        case .custom(let amount): return KitoCartMoney.string(amount, currencyCode: currencyCode)
        }
    }

    public var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }
}
