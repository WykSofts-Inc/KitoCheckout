//
//  KitoCheckoutModel.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation
import Observation
import KitoCore
import KitoCart

/// Where placing the order has got to.
public enum KitoCheckoutPhase: Equatable, Sendable {
    case editing
    case placing
    case failed(String)
}

/// The whole checkout's state: the bag (a `KitoCartViewModel`), delivery, payment, extras, the
/// current step and the live totals. `KitoCheckoutFlow` draws it; you can also drive your own UI.
@MainActor
@Observable
public final class KitoCheckoutModel: KitoViewModel {
    public let cart: KitoCartViewModel
    /// The steps before the confirmation, in order. Drop `.bag` to start at delivery.
    public let steps: [KitoCheckoutStep]
    public private(set) var step: KitoCheckoutStep
    /// Which way the last move went, for the slide direction.
    public var isMovingForward = true

    public var addresses: [KitoAddress]
    public var selectedAddressID: KitoAddress.ID? = nil

    public var deliveryOptions: [KitoDeliveryOption]
    private var storedDeliveryOptionID: KitoDeliveryOption.ID? = nil
    /// Changing it keeps the pickup point valid and picks the first open slot when the option uses slots.
    public var selectedDeliveryOptionID: KitoDeliveryOption.ID? {
        get { storedDeliveryOptionID }
        set {
            guard newValue != storedDeliveryOptionID else { return }
            storedDeliveryOptionID = newValue
            deliveryOptionChanged()
        }
    }
    public var selectedPickupPointID: KitoPickupPoint.ID? = nil
    public var schedule: KitoDeliverySchedule? = nil
    public var selectedSlot: KitoDeliverySlot? = nil

    public var paymentMethods: [KitoPaymentMethod]
    public var selectedPaymentMethodID: KitoPaymentMethod.ID? = nil
    public var applePayConfiguration: KitoApplePayConfiguration? = nil
    public var applePayAvailability: KitoApplePayAvailability

    public var rules: KitoCheckoutPricingRules
    public var currencyCode: String
    public var promo: KitoPromoCode? = nil
    public var promoValidator: KitoPromoValidator? = nil
    public var discounts: [KitoCheckoutDiscount]
    /// Show the tip selector on the payment step.
    public var offersTip: Bool
    public var tip: KitoTip

    public var offersGiftNote: Bool
    public var isGift = false
    public var giftNote = ""
    /// Markdown for the checkbox, e.g. "I agree to the [Terms](https://…)"; `nil` for no checkbox.
    public var termsText: String? = nil
    public var acceptedTerms = false

    public private(set) var phase: KitoCheckoutPhase = .editing
    public private(set) var placedOrder: KitoPlacedOrder? = nil
    /// Injected for tests and previews; the slot rules and card expiry use it.
    @ObservationIgnored public var now: () -> Date

    public init(
        cart: KitoCartViewModel,
        steps: [KitoCheckoutStep] = KitoCheckoutStep.standard,
        addresses: [KitoAddress] = [],
        deliveryOptions: [KitoDeliveryOption],
        schedule: KitoDeliverySchedule? = nil,
        paymentMethods: [KitoPaymentMethod],
        applePay: KitoApplePayConfiguration? = nil,
        rules: KitoCheckoutPricingRules = KitoCheckoutPricingRules(),
        currencyCode: String = KitoCheckoutDefaults.currencyCode,
        promoValidator: KitoPromoValidator? = nil,
        discounts: [KitoCheckoutDiscount] = [],
        offersTip: Bool = false,
        offersGiftNote: Bool = false,
        termsText: String? = nil,
        now: @escaping () -> Date = { Date() }
    ) {
        let visible = steps.filter { $0 != .done }
        self.cart = cart
        self.steps = visible.isEmpty ? KitoCheckoutStep.standard : visible
        self.step = self.steps.first ?? .bag
        self.addresses = addresses
        self.selectedAddressID = (addresses.first { $0.isDefault } ?? addresses.first)?.id
        self.deliveryOptions = deliveryOptions
        self.storedDeliveryOptionID = deliveryOptions.first { $0.isAvailable }?.id
        self.schedule = schedule
        self.paymentMethods = paymentMethods
        self.applePayConfiguration = applePay
        self.applePayAvailability = KitoApplePay.availability(for: applePay)
        self.rules = rules
        self.currencyCode = currencyCode
        self.promoValidator = promoValidator
        self.discounts = discounts
        self.offersTip = offersTip
        self.tip = .none
        self.offersGiftNote = offersGiftNote
        self.termsText = termsText
        self.now = now
        self.selectedPickupPointID = selectedDeliveryOption?.pickupPoints.first?.id
        if selectedDeliveryOption?.usesTimeSlots == true { self.selectedSlot = schedule?.firstAvailableSlot(now: now()) }
        self.selectedPaymentMethodID = firstUsablePaymentMethod()?.id
    }

    /// Starts from a plain list of items.
    public convenience init(
        items: [KitoCartItem],
        steps: [KitoCheckoutStep] = KitoCheckoutStep.standard,
        addresses: [KitoAddress] = [],
        deliveryOptions: [KitoDeliveryOption],
        schedule: KitoDeliverySchedule? = nil,
        paymentMethods: [KitoPaymentMethod],
        applePay: KitoApplePayConfiguration? = nil,
        rules: KitoCheckoutPricingRules = KitoCheckoutPricingRules(),
        currencyCode: String = KitoCheckoutDefaults.currencyCode,
        promoValidator: KitoPromoValidator? = nil,
        offersTip: Bool = false,
        offersGiftNote: Bool = false,
        termsText: String? = nil,
        now: @escaping () -> Date = { Date() }
    ) {
        self.init(cart: KitoCartViewModel(items: items), steps: steps, addresses: addresses, deliveryOptions: deliveryOptions,
                  schedule: schedule, paymentMethods: paymentMethods, applePay: applePay, rules: rules, currencyCode: currencyCode,
                  promoValidator: promoValidator, offersTip: offersTip, offersGiftNote: offersGiftNote, termsText: termsText, now: now)
    }

    // MARK: Selections

    public var selectedAddress: KitoAddress? { addresses.first { $0.id == selectedAddressID } }
    public var selectedDeliveryOption: KitoDeliveryOption? { deliveryOptions.first { $0.id == selectedDeliveryOptionID } }
    public var selectedPickupPoint: KitoPickupPoint? { selectedDeliveryOption?.pickupPoints.first { $0.id == selectedPickupPointID } }
    public var selectedPaymentMethod: KitoPaymentMethod? { paymentMethods.first { $0.id == selectedPaymentMethodID } }

    public var needsAddress: Bool { selectedDeliveryOption?.requiresAddress ?? true }
    public var needsSlot: Bool { selectedDeliveryOption?.usesTimeSlots ?? false }

    /// Adds (or replaces, by id) an address and selects it. A new default clears the old one.
    public func save(_ address: KitoAddress) {
        if address.isDefault {
            for index in addresses.indices { addresses[index].isDefault = false }
        }
        if let index = addresses.firstIndex(where: { $0.id == address.id }) {
            addresses[index] = address
        } else {
            addresses.append(address)
        }
        selectedAddressID = address.id
    }

    public func makeDefault(_ id: KitoAddress.ID) {
        for index in addresses.indices { addresses[index].isDefault = addresses[index].id == id }
    }

    public func removeAddress(_ id: KitoAddress.ID) {
        addresses.removeAll { $0.id == id }
        if selectedAddressID == id { selectedAddressID = (addresses.first { $0.isDefault } ?? addresses.first)?.id }
    }

    private func deliveryOptionChanged() {
        let points = selectedDeliveryOption?.pickupPoints ?? []
        if !points.contains(where: { $0.id == selectedPickupPointID }) { selectedPickupPointID = points.first?.id }
        if needsSlot, selectedSlot == nil, let schedule { selectedSlot = schedule.firstAvailableSlot(now: now()) }
    }

    private func firstUsablePaymentMethod() -> KitoPaymentMethod? {
        let total = totals.total
        return paymentMethods.first { method in
            if method.isApplePay && !applePayAvailability.isUsable { return false }
            return method.unavailableReason(total: total, currencyCode: currencyCode, now: now()) == nil
        }
    }

    // MARK: Totals and validation

    public var totals: KitoCheckoutTotals {
        KitoCheckoutTotals(items: cart.items, rules: rules, deliveryFee: selectedDeliveryOption?.price ?? 0,
                           promo: promo, tip: offersTip ? tip : .none, discounts: discounts)
    }

    public var snapshot: KitoCheckoutSnapshot {
        KitoCheckoutSnapshot(
            items: cart.items,
            address: selectedAddress,
            deliveryOption: selectedDeliveryOption,
            pickupPoint: selectedPickupPoint,
            slot: selectedSlot,
            schedule: schedule,
            paymentMethod: selectedPaymentMethod,
            applePay: applePayAvailability,
            total: totals.total,
            currencyCode: currencyCode,
            requiresTerms: termsText != nil,
            acceptedTerms: acceptedTerms
        )
    }

    public var issues: [KitoCheckoutIssue] { KitoCheckoutValidator.issues(for: step, in: snapshot, now: now()) }
    public var canContinue: Bool { issues.isEmpty }

    /// "Today, 2–4 PM", "Arrives in 30–45 min" or "Ready in 2–4 hours".
    public var deliveryText: String {
        if needsSlot, let slot = selectedSlot, let schedule { return schedule.label(for: slot, now: now()) }
        guard let option = selectedDeliveryOption else { return "" }
        return option.kind == .pickup ? "Ready in " + option.eta.label : option.eta.arrivalText
    }

    // MARK: Steps

    public var stepIndex: Int { steps.firstIndex(of: step) ?? steps.count }
    public var isFirstStep: Bool { stepIndex == 0 }
    public var isReviewStep: Bool { step == steps.last }

    /// The step after this one, or `nil` on the last one.
    public var nextStep: KitoCheckoutStep? {
        guard let index = steps.firstIndex(of: step), index + 1 < steps.count else { return nil }
        return steps[index + 1]
    }

    public var previousStep: KitoCheckoutStep? {
        guard let index = steps.firstIndex(of: step), index > 0 else { return nil }
        return steps[index - 1]
    }

    /// Moves on when the current step is complete. Returns whether it moved.
    @discardableResult
    public func advance() -> Bool {
        guard canContinue, let next = nextStep else { return false }
        isMovingForward = true
        step = next
        return true
    }

    /// Goes back one step. Returns `false` on the first step (close the checkout instead).
    @discardableResult
    public func goBack() -> Bool {
        guard step != .done, let previous = previousStep else { return false }
        isMovingForward = false
        step = previous
        return true
    }

    /// Jumps to an earlier step, or a later one when every step before it is complete.
    @discardableResult
    public func go(to target: KitoCheckoutStep) -> Bool {
        guard target != step, step != .done, steps.contains(target) else { return false }
        if target > step {
            let before = steps.prefix { $0 < target }
            let moment = now()
            let current = snapshot
            guard before.allSatisfy({ KitoCheckoutValidator.canContinue(from: $0, in: current, now: moment) }) else { return false }
        }
        isMovingForward = target > step
        step = target
        return true
    }

    /// The order as it stands, or `nil` when something is still missing.
    public func makeOrder(applePayToken: Data? = nil) -> KitoCheckoutOrder? {
        guard KitoCheckoutValidator.issues(for: .review, in: snapshot, now: now()).isEmpty,
              let option = selectedDeliveryOption, let payment = selectedPaymentMethod else { return nil }
        let note = giftNote.trimmingCharacters(in: .whitespacesAndNewlines)
        return KitoCheckoutOrder(
            items: cart.items,
            address: option.requiresAddress ? selectedAddress : nil,
            deliveryOption: option,
            pickupPoint: option.kind == .pickup ? selectedPickupPoint : nil,
            slot: option.usesTimeSlots ? selectedSlot : nil,
            deliveryText: deliveryText,
            paymentMethod: payment,
            applePayToken: applePayToken,
            totals: totals,
            giftNote: offersGiftNote && isGift && !note.isEmpty ? note : nil,
            currencyCode: currencyCode
        )
    }

    /// Sends the order to your closure. On success the model moves to `.done` with the
    /// confirmation; a thrown error's description is kept in `phase` for the banner.
    @discardableResult
    public func placeOrder(applePayToken: Data? = nil, using handler: (KitoCheckoutOrder) async throws -> KitoPlacedOrder) async -> Bool {
        guard phase != .placing else { return false }
        guard let order = makeOrder(applePayToken: applePayToken) else {
            let missing = KitoCheckoutValidator.issues(for: .review, in: snapshot, now: now())
            phase = .failed(missing.first?.message ?? "Something is missing from your order.")
            return false
        }
        phase = .placing
        do {
            let placed = try await handler(order)
            placedOrder = placed
            phase = .editing
            isMovingForward = true
            step = .done
            return true
        } catch {
            phase = .failed(Self.message(for: error))
            return false
        }
    }

    /// Records a failure that happened outside `placeOrder`, such as an Apple Pay sheet error.
    public func fail(_ message: String) { phase = .failed(message) }

    public func dismissError() {
        if case .failed = phase { phase = .editing }
    }

    /// Back to the first step with a fresh order, keeping addresses and payment methods.
    public func reset() {
        placedOrder = nil
        phase = .editing
        acceptedTerms = false
        isGift = false
        giftNote = ""
        promo = nil
        tip = .none
        isMovingForward = false
        step = steps.first ?? .bag
    }

    private static func message(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription { return description }
        return "We couldn't place your order. Please try again."
    }
}
