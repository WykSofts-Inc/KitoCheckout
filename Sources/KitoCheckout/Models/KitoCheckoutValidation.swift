//
//  KitoCheckoutValidation.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation
import KitoCart

/// Something that stops the customer moving on.
public enum KitoCheckoutIssue: Hashable, Sendable, Identifiable {
    case emptyBag
    case missingDeliveryOption
    case deliveryOptionUnavailable(String)
    case missingAddress
    case missingPickupPoint
    case missingSlot
    case slotUnavailable
    case missingPayment
    case paymentUnavailable(String)
    case applePayNotReady(String)
    case termsNotAccepted

    public var id: String { message }

    /// The step where it gets fixed.
    public var step: KitoCheckoutStep {
        switch self {
        case .emptyBag: return .bag
        case .missingDeliveryOption, .deliveryOptionUnavailable, .missingAddress, .missingPickupPoint, .missingSlot, .slotUnavailable: return .delivery
        case .missingPayment, .paymentUnavailable, .applePayNotReady: return .payment
        case .termsNotAccepted: return .review
        }
    }

    /// Short copy for the hint above the button.
    public var message: String {
        switch self {
        case .emptyBag: return "Your bag is empty."
        case .missingDeliveryOption: return "Choose how you'd like to get your order."
        case .deliveryOptionUnavailable(let reason): return reason
        case .missingAddress: return "Choose a delivery address."
        case .missingPickupPoint: return "Choose a pickup point."
        case .missingSlot: return "Choose a delivery time."
        case .slotUnavailable: return "That time is no longer available — pick another."
        case .missingPayment: return "Choose how you'd like to pay."
        case .paymentUnavailable(let reason): return reason
        case .applePayNotReady(let reason): return reason
        case .termsNotAccepted: return "Accept the terms to place your order."
        }
    }
}

/// The choices the validator looks at. `KitoCheckoutModel` builds one for you.
public struct KitoCheckoutSnapshot: Equatable, Sendable {
    public var items: [KitoCartItem]
    public var address: KitoAddress?
    public var deliveryOption: KitoDeliveryOption?
    public var pickupPoint: KitoPickupPoint?
    public var slot: KitoDeliverySlot?
    public var schedule: KitoDeliverySchedule?
    public var paymentMethod: KitoPaymentMethod?
    public var applePay: KitoApplePayAvailability
    public var total: Decimal
    public var currencyCode: String
    public var requiresTerms: Bool
    public var acceptedTerms: Bool

    public init(
        items: [KitoCartItem],
        address: KitoAddress? = nil,
        deliveryOption: KitoDeliveryOption? = nil,
        pickupPoint: KitoPickupPoint? = nil,
        slot: KitoDeliverySlot? = nil,
        schedule: KitoDeliverySchedule? = nil,
        paymentMethod: KitoPaymentMethod? = nil,
        applePay: KitoApplePayAvailability = .available,
        total: Decimal = 0,
        currencyCode: String = KitoCheckoutDefaults.currencyCode,
        requiresTerms: Bool = false,
        acceptedTerms: Bool = false
    ) {
        self.items = items
        self.address = address
        self.deliveryOption = deliveryOption
        self.pickupPoint = pickupPoint
        self.slot = slot
        self.schedule = schedule
        self.paymentMethod = paymentMethod
        self.applePay = applePay
        self.total = total
        self.currencyCode = currencyCode
        self.requiresTerms = requiresTerms
        self.acceptedTerms = acceptedTerms
    }
}

/// Which step can be left, and why not.
public enum KitoCheckoutValidator {
    /// What blocks leaving `step`. Review checks everything before it too, so an order can't be
    /// placed with a slot that filled up while the customer was paying.
    public static func issues(for step: KitoCheckoutStep, in snapshot: KitoCheckoutSnapshot, now: Date = Date()) -> [KitoCheckoutIssue] {
        switch step {
        case .bag: return bagIssues(snapshot)
        case .delivery: return deliveryIssues(snapshot, now: now)
        case .payment: return paymentIssues(snapshot, now: now)
        case .review:
            let terms: [KitoCheckoutIssue] = snapshot.requiresTerms && !snapshot.acceptedTerms ? [.termsNotAccepted] : []
            return bagIssues(snapshot) + deliveryIssues(snapshot, now: now) + paymentIssues(snapshot, now: now) + terms
        case .done: return []
        }
    }

    public static func canContinue(from step: KitoCheckoutStep, in snapshot: KitoCheckoutSnapshot, now: Date = Date()) -> Bool {
        issues(for: step, in: snapshot, now: now).isEmpty
    }

    /// The first of `steps` that still has a problem, for jumping straight to it.
    public static func firstIncompleteStep(of steps: [KitoCheckoutStep] = KitoCheckoutStep.standard, in snapshot: KitoCheckoutSnapshot, now: Date = Date()) -> KitoCheckoutStep? {
        steps.first { !canContinue(from: $0, in: snapshot, now: now) }
    }

    static func bagIssues(_ snapshot: KitoCheckoutSnapshot) -> [KitoCheckoutIssue] {
        snapshot.items.contains { $0.quantity > 0 } ? [] : [.emptyBag]
    }

    static func deliveryIssues(_ snapshot: KitoCheckoutSnapshot, now: Date) -> [KitoCheckoutIssue] {
        guard let option = snapshot.deliveryOption else { return [.missingDeliveryOption] }
        if let reason = option.unavailableReason { return [.deliveryOptionUnavailable(reason)] }
        var issues: [KitoCheckoutIssue] = []
        if option.requiresAddress && snapshot.address == nil { issues.append(.missingAddress) }
        if option.kind == .pickup && !option.pickupPoints.isEmpty && snapshot.pickupPoint == nil { issues.append(.missingPickupPoint) }
        if option.usesTimeSlots {
            if let slot = snapshot.slot {
                let open = snapshot.schedule?.isSelectable(slot, now: now) ?? (now < slot.end)
                if !open { issues.append(.slotUnavailable) }
            } else {
                issues.append(.missingSlot)
            }
        }
        return issues
    }

    static func paymentIssues(_ snapshot: KitoCheckoutSnapshot, now: Date) -> [KitoCheckoutIssue] {
        guard let method = snapshot.paymentMethod else { return [.missingPayment] }
        if method.isApplePay, let message = snapshot.applePay.message, !snapshot.applePay.isUsable {
            return [.applePayNotReady(message)]
        }
        if let reason = method.unavailableReason(total: snapshot.total, currencyCode: snapshot.currencyCode, now: now) {
            return [.paymentUnavailable(reason)]
        }
        return []
    }
}
