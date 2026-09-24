//
//  KitoPaymentMethod.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation
import KitoCart

public enum KitoPaymentCardBrand: String, CaseIterable, Hashable, Sendable {
    case visa, mastercard, amex, other

    public var title: String {
        switch self {
        case .visa: return "Visa"
        case .mastercard: return "Mastercard"
        case .amex: return "Amex"
        case .other: return "Card"
        }
    }

    /// Guesses the brand from the first digits of a card number.
    public static func detect(number: String) -> KitoPaymentCardBrand {
        let digits = number.filter(\.isNumber)
        if digits.hasPrefix("34") || digits.hasPrefix("37") { return .amex }
        if digits.hasPrefix("4") { return .visa }
        let two = Int(digits.prefix(2)) ?? 0
        let four = Int(digits.prefix(4)) ?? 0
        if (51...55).contains(two) || (2221...2720).contains(four) { return .mastercard }
        return .other
    }
}

/// How the customer pays.
public enum KitoPaymentKind: Hashable, Sendable {
    /// An M-Pesa prompt (STK push) to this phone.
    case mpesa(phone: String)
    /// A saved card. `expiry` is "MM/YY".
    case card(brand: KitoPaymentCardBrand, last4: String, expiry: String?)
    case applePay
    /// Pay the rider on arrival. `limit` caps the order value accepted in cash.
    case cashOnDelivery(limit: Decimal?)
    /// Store credit.
    case wallet(balance: Decimal)
}

/// A row in the payment method list.
public struct KitoPaymentMethod: Identifiable, Hashable, Sendable {
    public let id: String
    public var kind: KitoPaymentKind
    /// Replaces the default title ("M-Pesa", "Visa •••• 4242").
    public var customTitle: String?
    /// Set to switch the method off with your own reason.
    public var unavailableNote: String?

    public init(id: String, kind: KitoPaymentKind, title: String? = nil, unavailableNote: String? = nil) {
        self.id = id
        self.kind = kind
        self.customTitle = title
        self.unavailableNote = unavailableNote
    }

    public static func mpesa(phone: String, id: String = "mpesa") -> KitoPaymentMethod {
        KitoPaymentMethod(id: id, kind: .mpesa(phone: phone))
    }

    public static func card(_ brand: KitoPaymentCardBrand, last4: String, expiry: String? = nil, id: String? = nil) -> KitoPaymentMethod {
        KitoPaymentMethod(id: id ?? "card-\(last4)", kind: .card(brand: brand, last4: String(last4.suffix(4)), expiry: expiry))
    }

    public static var applePay: KitoPaymentMethod { KitoPaymentMethod(id: "apple-pay", kind: .applePay) }

    public static func cashOnDelivery(limit: Decimal? = nil) -> KitoPaymentMethod {
        KitoPaymentMethod(id: "cash", kind: .cashOnDelivery(limit: limit))
    }

    public static func wallet(balance: Decimal) -> KitoPaymentMethod {
        KitoPaymentMethod(id: "wallet", kind: .wallet(balance: balance))
    }

    public var title: String {
        if let customTitle { return customTitle }
        switch kind {
        case .mpesa: return "M-Pesa"
        case .card(let brand, let last4, _): return "\(brand.title) •••• \(last4)"
        case .applePay: return "Apple Pay"
        case .cashOnDelivery: return "Cash on delivery"
        case .wallet: return "Wallet"
        }
    }

    public var isApplePay: Bool { kind == .applePay }

    public var isMpesa: Bool {
        if case .mpesa = kind { return true }
        return false
    }

    /// The second line of the row.
    public func subtitle(currencyCode: String = KitoCheckoutDefaults.currencyCode) -> String {
        switch kind {
        case .mpesa(let phone):
            return "Prompt sent to " + (KitoKenyanPhone.masked(phone) ?? phone)
        case .card(_, _, let expiry):
            return expiry.map { "Expires \($0)" } ?? "Saved card"
        case .applePay:
            return "Pay with Face ID or Touch ID"
        case .cashOnDelivery:
            return "Pay the rider when it arrives"
        case .wallet(let balance):
            return "Balance " + KitoCartMoney.string(balance, currencyCode: currencyCode)
        }
    }

    /// Why this method can't pay `total` right now, or `nil` when it can.
    public func unavailableReason(total: Decimal, currencyCode: String = KitoCheckoutDefaults.currencyCode, now: Date = Date(), calendar: Calendar = KitoCheckoutDefaults.calendar) -> String? {
        if let unavailableNote { return unavailableNote }
        switch kind {
        case .wallet(let balance):
            guard balance < total else { return nil }
            return "Balance too low — top up " + KitoCartMoney.string(total - balance, currencyCode: currencyCode)
        case .cashOnDelivery(let limit):
            guard let limit, total > limit else { return nil }
            return "Cash is accepted up to " + KitoCartMoney.string(limit, currencyCode: currencyCode)
        case .card(_, _, let expiry):
            guard let expiry, Self.isExpired(expiry, now: now, calendar: calendar) else { return nil }
            return "This card has expired"
        case .mpesa(let phone):
            return KitoKenyanPhone.normalize(phone) == nil ? "Add a valid M-Pesa number" : nil
        case .applePay:
            return nil
        }
    }

    /// "MM/YY" — a card is valid to the end of its expiry month.
    public static func isExpired(_ expiry: String, now: Date, calendar: Calendar = KitoCheckoutDefaults.calendar) -> Bool {
        let parts = expiry.split(separator: "/").map { String($0).trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, let month = Int(parts[0]), let rawYear = Int(parts[1]), (1...12).contains(month) else { return false }
        let year = rawYear < 100 ? 2000 + rawYear : rawYear
        let today = calendar.dateComponents([.year, .month], from: now)
        let nowYear = today.year ?? 0
        let nowMonth = today.month ?? 0
        return year < nowYear || (year == nowYear && month < nowMonth)
    }
}
