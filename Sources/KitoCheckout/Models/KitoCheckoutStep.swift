//
//  KitoCheckoutStep.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// The stages of a checkout, in order. `done` is the confirmation screen after the order is placed.
public enum KitoCheckoutStep: String, CaseIterable, Identifiable, Comparable, Sendable {
    case bag, delivery, payment, review, done

    public var id: String { rawValue }

    /// The four steps shown in the progress header.
    public static let standard: [KitoCheckoutStep] = [.bag, .delivery, .payment, .review]

    public var title: String {
        switch self {
        case .bag: return "Bag"
        case .delivery: return "Delivery"
        case .payment: return "Payment"
        case .review: return "Review"
        case .done: return "Done"
        }
    }

    public var systemImage: String {
        switch self {
        case .bag: return "bag.fill"
        case .delivery: return "shippingbox.fill"
        case .payment: return "creditcard.fill"
        case .review: return "checklist"
        case .done: return "checkmark.seal.fill"
        }
    }

    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    public static func < (lhs: KitoCheckoutStep, rhs: KitoCheckoutStep) -> Bool { lhs.order < rhs.order }
}

/// How the progress header draws the steps.
public enum KitoCheckoutProgressStyle: String, CaseIterable, Identifiable, Sendable {
    /// Numbered dots joined by a line that fills as you go; finished steps show a tick.
    case dots
    /// One bar per step.
    case segmented
    /// "Step 2 of 4" with the step name and a thin bar.
    case text

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .dots: return "Dots"
        case .segmented: return "Segmented"
        case .text: return "Text"
        }
    }
}

/// Shared defaults: Kenyan shillings and Nairobi time.
public enum KitoCheckoutDefaults {
    public static let currencyCode = "KES"

    /// Gregorian, Africa/Nairobi, English (Kenya). Slot maths and order numbers use this unless
    /// you pass your own calendar.
    public static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Africa/Nairobi") ?? .current
        calendar.locale = Locale(identifier: "en_KE")
        calendar.firstWeekday = 2
        return calendar
    }
}

enum KitoCheckoutMath {
    static func round(_ value: Decimal, scale: Int) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, scale, .plain)
        return output
    }

    static func percent(_ percent: Decimal, of amount: Decimal) -> Decimal {
        amount * percent / 100
    }

    static func double(_ value: Decimal) -> Double {
        (value as NSDecimalNumber).doubleValue
    }

    static func string(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
