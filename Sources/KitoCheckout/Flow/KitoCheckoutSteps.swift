//
//  KitoCheckoutSteps.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore
import KitoCart

/// Bag: the items with steppers and the free-delivery bar.
struct KitoBagStep<Thumbnail: View>: View {
    @Bindable var model: KitoCheckoutModel
    let tint: Color?
    let onContinueShopping: (() -> Void)?
    let thumbnail: (KitoCartItem) -> Thumbnail
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var freeDeliveryPricing: KitoCartPricing? {
        guard let threshold = model.rules.freeDeliveryThreshold else { return nil }
        let rules = KitoCartPricingRules(deliveryFee: model.selectedDeliveryOption?.price ?? 0, freeDeliveryThreshold: threshold)
        return rules.pricing(subtotal: model.cart.subtotal, promo: model.promo)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.lg) {
            if model.cart.isEmpty {
                KitoEmptyCartView(action: onContinueShopping)
                    .frame(minHeight: 360)
            } else {
                KitoCheckoutSectionHeader(title: "Your bag", subtitle: itemsText)
                if let pricing = freeDeliveryPricing {
                    KitoFreeDeliveryProgress(pricing: pricing, currencyCode: model.currencyCode, tint: tint)
                }
                ForEach(model.cart.items) { item in
                    KitoCartItemRow(item: item, quantity: quantity(for: item), currencyCode: model.currencyCode,
                                    onRemove: { model.cart.remove(id: item.id) }) { item in
                        thumbnail(item)
                    }
                    .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
                    .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
                }
            }
        }
        .animation(KitoCheckoutMotion.spring(reduceMotion), value: model.cart.items)
    }

    private var itemsText: String {
        let count = model.cart.totalQuantity
        return count == 1 ? "1 item" : "\(count) items"
    }

    private func quantity(for item: KitoCartItem) -> Binding<Int> {
        Binding(get: { model.cart.quantity(of: item.id) }, set: { model.cart.setQuantity(id: item.id, quantity: $0) })
    }
}

/// Delivery: method, address (unless it's pickup) and time slot.
struct KitoDeliveryStep<Map: View>: View {
    @Bindable var model: KitoCheckoutModel
    let tint: Color?
    let map: (KitoAddress) -> Map
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var waivesFees: Bool {
        guard let threshold = model.rules.freeDeliveryThreshold else { return model.totals.waivedDeliveryFee > 0 }
        return model.cart.subtotal >= threshold || model.totals.waivedDeliveryFee > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xl) {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                KitoCheckoutSectionHeader(title: "How do you want it?")
                KitoDeliveryOptions(model.deliveryOptions, selection: $model.selectedDeliveryOptionID, pickupPoint: $model.selectedPickupPointID,
                                    currencyCode: model.currencyCode, waivesFees: waivesFees, tint: tint)
            }
            if model.needsAddress {
                VStack(alignment: .leading, spacing: theme.spacing.md) {
                    KitoCheckoutSectionHeader(title: "Deliver to")
                    KitoAddressPicker(addresses: $model.addresses, selection: $model.selectedAddressID, tint: tint, map: map)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if model.needsSlot, let schedule = model.schedule {
                VStack(alignment: .leading, spacing: theme.spacing.md) {
                    KitoCheckoutSectionHeader(title: "When?", subtitle: model.selectedSlot.map { schedule.label(for: $0, now: model.now()) })
                    KitoDeliverySlotPicker(schedule: schedule, selection: $model.selectedSlot, now: model.now(), tint: tint)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(KitoCheckoutMotion.spring(reduceMotion), value: model.selectedDeliveryOptionID)
    }
}

/// Payment: the methods, the Apple Pay notice when it can't be used, and the tip.
struct KitoPaymentStep: View {
    @Bindable var model: KitoCheckoutModel
    let tint: Color?
    let onAddCard: (() -> Void)?
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var showsApplePayNotice: Bool {
        model.paymentMethods.contains { $0.isApplePay } && !model.applePayAvailability.isUsable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xl) {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                KitoCheckoutSectionHeader(title: "Pay with")
                KitoPaymentMethodList(model.paymentMethods, selection: $model.selectedPaymentMethodID, total: model.totals.total,
                                      currencyCode: model.currencyCode, applePay: model.applePayAvailability, now: model.now(),
                                      tint: tint, onAddCard: onAddCard)
                if showsApplePayNotice {
                    KitoApplePayNotice(availability: model.applePayAvailability)
                }
                if model.selectedPaymentMethod?.isMpesa == true {
                    mpesaNote
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            if model.offersTip {
                KitoTipSelector(tip: $model.tip, subtotal: model.totals.subtotal, currencyCode: model.currencyCode,
                                wholeUnits: model.rules.roundsToWholeUnits, tint: tint)
            }
        }
        .animation(KitoCheckoutMotion.spring(reduceMotion), value: model.selectedPaymentMethodID)
    }

    private var mpesaNote: some View {
        Label("You'll get an M-Pesa prompt on your phone after you place the order. Enter your PIN to pay.", systemImage: "iphone.radiowaves.left.and.right")
            .font(theme.typography.caption)
            .foregroundStyle(theme.colors.onBackground.opacity(0.65))
            .padding(theme.spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).fill(theme.colors.success.opacity(0.1)))
    }
}

/// Review: what, where and how, each with a Change link, then the summary, promo, gift note and terms.
struct KitoReviewStep<Thumbnail: View>: View {
    @Bindable var model: KitoCheckoutModel
    let tint: Color?
    let showsTermsError: Bool
    let onChange: (KitoCheckoutStep) -> Void
    let thumbnail: (KitoCartItem) -> Thumbnail
    @Environment(\.kitoTheme) private var theme

    private var accent: Color { theme.checkoutAccent(tint) }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.lg) {
            recap
            KitoOrderSummary(totals: model.totals, currencyCode: model.currencyCode, tint: tint, thumbnail: thumbnail)
            if let validator = model.promoValidator {
                KitoPromoCodeField(applied: $model.promo, validator: validator, subtotal: model.cart.subtotal, currencyCode: model.currencyCode)
            }
            if model.offersGiftNote {
                KitoGiftNoteField(isGift: $model.isGift, note: $model.giftNote, tint: tint)
            }
            if let terms = model.termsText {
                KitoTermsCheckbox(isOn: $model.acceptedTerms, text: terms, showsError: showsTermsError, tint: tint)
                    .padding(.horizontal, theme.spacing.xs)
            }
        }
    }

    private var recap: some View {
        VStack(spacing: 0) {
            if let destination = destinationText {
                recapRow(model.needsAddress ? "house.fill" : "storefront.fill", title: model.needsAddress ? "Deliver to" : "Pick up from", value: destination, step: .delivery)
                Divider().padding(.leading, 56)
            }
            recapRow("clock.fill", title: model.selectedDeliveryOption?.title ?? "Delivery", value: model.deliveryText, step: .delivery)
            if let payment = model.selectedPaymentMethod {
                Divider().padding(.leading, 56)
                recapRow("creditcard.fill", title: "Pay with", value: payment.title, step: .payment)
            }
        }
        .checkoutCard(accent: accent, padding: 0)
    }

    private var destinationText: String? {
        if model.needsAddress { return model.selectedAddress.map { "\($0.label.title) · " + $0.formatted(.singleLine) } }
        return model.selectedPickupPoint.map { "\($0.name), \($0.address)" }
    }

    private func recapRow(_ symbol: String, title: String, value: String, step: KitoCheckoutStep) -> some View {
        HStack(spacing: theme.spacing.md) {
            KitoCheckoutIconTile(systemImage: symbol, color: accent, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(theme.typography.caption).foregroundStyle(theme.colors.onSurface.opacity(0.55))
                Text(value).font(theme.typography.label.weight(.semibold)).foregroundStyle(theme.colors.onSurface).lineLimit(2)
            }
            Spacer(minLength: theme.spacing.sm)
            if model.steps.contains(step) {
                Button("Change") { onChange(step) }
                    .font(theme.typography.caption.weight(.bold))
                    .foregroundStyle(accent)
                    .accessibilityLabel("Change \(title.lowercased())")
            }
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, theme.spacing.md)
    }
}
