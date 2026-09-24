# ``KitoCheckout``

A multi-step SwiftUI checkout with delivery, payment, review and confirmation steps.

## Overview

KitoCheckout takes a cart through Bag, Delivery, Payment, Review and Done. The
flow has a progress header in three styles, steps that slide in the direction
you're going, and a sticky bar whose total updates as delivery, tip or promo
change. It builds on KitoCart's items and promo codes.

``KitoCheckoutModel`` holds the whole checkout — addresses, delivery options and
slots, payment methods, pricing rules and the current step — and
``KitoCheckoutFlow`` draws it. Your `onPlaceOrder` closure receives a
``KitoCheckoutOrder``; return the confirmation, or throw to show the error above
the button.

```swift
import KitoCart
import KitoCheckout

@State private var checkout = KitoCheckoutModel(
    cart: cart,
    addresses: savedAddresses,
    deliveryOptions: [.standard(price: 250), .express(price: 450)],
    paymentMethods: [.mpesa(phone: "0712345678"), .cashOnDelivery(limit: 10_000)],
    rules: KitoCheckoutPricingRules(vat: .kenya, freeDeliveryThreshold: 5_000)
)

var body: some View {
    KitoCheckoutFlow(model: checkout, onClose: { dismiss() }) { order in
        let number = try await api.placeOrder(order)
        return order.confirmed(number: number)
    }
}
```

Each part also works on its own: a saved-address picker with Kenyan counties and
towns, delivery options and slots, a payment method list with an Apple Pay
button, a tip selector, an order summary, a terms checkbox, a gift note and a
confirmation screen. The pricing and slot logic are plain values —
``KitoCheckoutTotals`` and ``KitoDeliverySchedule`` — so you can use them in your
own screens. Every view reads `@Environment(\.kitoTheme)`, takes an optional
`tint`, and respects Reduce Motion.

## Topics

### Essentials

- ``KitoCheckoutFlow``
- ``KitoCheckoutModel``
- ``KitoCheckoutStep``
- ``KitoCheckoutPhase``
- ``KitoCheckoutProgressHeader``
- ``KitoCheckoutProgressStyle``
- ``KitoCheckoutTotalBar``
- ``KitoCheckoutBarButton``
- ``KitoCheckoutDefaults``

### Orders

- ``KitoCheckoutOrder``
- ``KitoPlacedOrder``
- ``KitoOrderNumber``
- ``KitoOrderSummary``
- ``KitoOrderSuccessView``
- ``KitoItemThumbnail``

### Pricing

- ``KitoCheckoutTotals``
- ``KitoCheckoutPricingRules``
- ``KitoCheckoutLine``
- ``KitoCheckoutDiscount``
- ``KitoVAT``
- ``KitoVATMode``
- ``KitoServiceFee``
- ``KitoTip``
- ``KitoTipSelector``

### Delivery

- ``KitoAddress``
- ``KitoAddressLabel``
- ``KitoAddressFormat``
- ``KitoAddressField``
- ``KitoAddressPicker``
- ``KitoAddressForm``
- ``KitoMapPinPlaceholder``
- ``KitoKenya``
- ``KitoCounty``
- ``KitoKenyanPhone``
- ``KitoDeliveryOption``
- ``KitoDeliveryKind``
- ``KitoDeliveryETA``
- ``KitoPickupPoint``
- ``KitoDeliveryOptions``
- ``KitoDeliverySchedule``
- ``KitoSlotRules``
- ``KitoTimeWindow``
- ``KitoDeliveryDay``
- ``KitoDeliverySlot``
- ``KitoSlotAvailability``
- ``KitoDeliverySlotPicker``

### Payment

- ``KitoPaymentMethod``
- ``KitoPaymentKind``
- ``KitoPaymentCardBrand``
- ``KitoPaymentMethodList``
- ``KitoPaymentMethodIcon``
- ``KitoApplePay``
- ``KitoApplePayConfiguration``
- ``KitoApplePayAvailability``
- ``KitoApplePayNetwork``
- ``KitoApplePayLine``
- ``KitoApplePayOutcome``
- ``KitoApplePayError``
- ``KitoApplePayButton``
- ``KitoApplePayNotice``

### Review and Validation

- ``KitoTermsCheckbox``
- ``KitoGiftNoteField``
- ``KitoCheckoutIssue``
- ``KitoCheckoutSnapshot``
- ``KitoCheckoutValidator``
