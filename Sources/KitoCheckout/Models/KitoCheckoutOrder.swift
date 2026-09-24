//
//  KitoCheckoutOrder.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation
import KitoCart

/// Everything chosen during checkout, handed to your `onPlaceOrder` closure to send to the server.
public struct KitoCheckoutOrder: Equatable, Sendable {
    public let items: [KitoCartItem]
    public let address: KitoAddress?
    public let deliveryOption: KitoDeliveryOption
    public let pickupPoint: KitoPickupPoint?
    public let slot: KitoDeliverySlot?
    /// "Today, 2–4 PM" or "Arrives in 30–45 min".
    public let deliveryText: String
    public let paymentMethod: KitoPaymentMethod
    /// The encrypted Apple Pay token (`PKPaymentToken.paymentData`) when paid with Apple Pay —
    /// send it to your payment provider.
    public let applePayToken: Data?
    public let totals: KitoCheckoutTotals
    public let giftNote: String?
    public let currencyCode: String

    public init(
        items: [KitoCartItem],
        address: KitoAddress?,
        deliveryOption: KitoDeliveryOption,
        pickupPoint: KitoPickupPoint? = nil,
        slot: KitoDeliverySlot? = nil,
        deliveryText: String,
        paymentMethod: KitoPaymentMethod,
        applePayToken: Data? = nil,
        totals: KitoCheckoutTotals,
        giftNote: String? = nil,
        currencyCode: String = KitoCheckoutDefaults.currencyCode
    ) {
        self.items = items
        self.address = address
        self.deliveryOption = deliveryOption
        self.pickupPoint = pickupPoint
        self.slot = slot
        self.deliveryText = deliveryText
        self.paymentMethod = paymentMethod
        self.applePayToken = applePayToken
        self.totals = totals
        self.giftNote = giftNote
        self.currencyCode = currencyCode
    }

    /// The confirmation to show once your server has accepted the order.
    public func confirmed(number: String, placedAt: Date = Date(), eta: String? = nil) -> KitoPlacedOrder {
        let destination = pickupPoint.map { "\($0.name), \($0.address)" } ?? address?.formatted(.singleLine)
        return KitoPlacedOrder(
            number: number,
            placedAt: placedAt,
            eta: eta ?? deliveryText,
            destination: destination,
            deliveryTitle: deliveryOption.title,
            paymentTitle: paymentMethod.title,
            items: items,
            lines: totals.lines,
            total: totals.total,
            currencyCode: currencyCode
        )
    }
}

/// A placed order, for the confirmation screen and the shared receipt.
public struct KitoPlacedOrder: Identifiable, Equatable, Sendable {
    public let number: String
    public let placedAt: Date
    public let eta: String?
    public let destination: String?
    public let deliveryTitle: String?
    public let paymentTitle: String?
    public let items: [KitoCartItem]
    public let lines: [KitoCheckoutLine]
    public let total: Decimal
    public let currencyCode: String

    public var id: String { number }

    public init(
        number: String,
        placedAt: Date = Date(),
        eta: String? = nil,
        destination: String? = nil,
        deliveryTitle: String? = nil,
        paymentTitle: String? = nil,
        items: [KitoCartItem] = [],
        lines: [KitoCheckoutLine] = [],
        total: Decimal,
        currencyCode: String = KitoCheckoutDefaults.currencyCode
    ) {
        self.number = number
        self.placedAt = placedAt
        self.eta = eta
        self.destination = destination
        self.deliveryTitle = deliveryTitle
        self.paymentTitle = paymentTitle
        self.items = items
        self.lines = lines
        self.total = total
        self.currencyCode = currencyCode
    }

    /// A plain-text receipt for the share sheet.
    public var receiptText: String {
        var rows = ["Order \(number)"]
        if let eta { rows.append(eta) }
        rows.append("")
        for item in items {
            rows.append("\(item.quantity) × \(item.name) — " + KitoCartMoney.string(item.lineTotal, currencyCode: currencyCode))
        }
        if !items.isEmpty { rows.append("") }
        for line in lines where line.kind != .total {
            rows.append(line.title + ": " + KitoCartMoney.string(line.amount, currencyCode: currencyCode))
        }
        rows.append("Total: " + KitoCartMoney.string(total, currencyCode: currencyCode))
        if let paymentTitle { rows.append("Paid with " + paymentTitle) }
        if let destination { rows.append("To: " + destination) }
        return rows.joined(separator: "\n")
    }
}
