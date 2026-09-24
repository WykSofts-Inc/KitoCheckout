# KitoCheckout

A multi-step checkout for SwiftUI: Bag → Delivery → Payment → Review → Done. It has a progress
header in three styles, steps that slide the way you're going, and a sticky bar whose total
updates as you change delivery, tip or promo. The parts work on their own too: a saved-address
picker with Kenyan counties and towns, delivery options, a delivery slot picker, a payment method
list with an Apple Pay button, a tip selector, an order summary with rolling numbers, a terms
checkbox, a gift note and a confirmation screen with confetti. The maths is plain values with
tests. Part of the [Kito](https://github.com/WykSofts-Inc/KitoDevKit) ecosystem, and it builds on
[KitoCart](https://github.com/WykSofts-Inc/KitoCart)'s items and promo codes.

## The whole checkout

```swift
import KitoCart
import KitoCheckout

@State private var checkout = KitoCheckoutModel(
    cart: cart,                                            // your KitoCartViewModel
    addresses: savedAddresses,
    deliveryOptions: [.standard(price: 250), .express(price: 450),
                      .pickup(points: pickupPoints), .scheduled(price: 150)],
    schedule: KitoDeliverySchedule(rules: KitoSlotRules(sameDayCutoffMinutes: 17 * 60)),
    paymentMethods: [.mpesa(phone: "0712345678"), .card(.visa, last4: "4242", expiry: "08/28"),
                     .applePay, .cashOnDelivery(limit: 10_000), .wallet(balance: 850)],
    applePay: KitoApplePayConfiguration(merchantIdentifier: "merchant.com.yourcompany.shop",
                                        merchantName: "Your Shop"),
    rules: KitoCheckoutPricingRules(serviceFee: .percent(2, minimum: 20), vat: .kenya,
                                    freeDeliveryThreshold: 5_000),
    promoValidator: KitoPromoValidator(codes: [KitoPromoCode(code: "KARIBU", kind: .percent(10))]),
    offersTip: true, offersGiftNote: true,
    termsText: "I agree to the [Terms](https://example.com/terms) and [Privacy Policy](https://example.com/privacy)")

KitoCheckoutFlow(model: checkout, progressStyle: .dots,          // .segmented, .text
                 onClose: { dismiss() },
                 onAddCard: { showAddCard = true },
                 onTrackOrder: { order in track(order.number) },
                 onContinueShopping: { dismiss() }) { order in
    let number = try await api.placeOrder(order)                  // STK push, card charge, …
    return order.confirmed(number: number)
}
```

`onPlaceOrder` receives a `KitoCheckoutOrder`: the items, address or pickup point, delivery option,
slot, payment method, totals, gift note and, for Apple Pay, the payment token. Return the
confirmation, or throw to show the error above the button. The button can't be pressed until the
step is complete, and a hint says what's missing: "Choose a delivery address", "Balance too low —
top up KES 600", "That time is no longer available — pick another". Tap a finished step in the
header, or "Change" on the review, to go back.

Put a real map in the delivery step's address form with `.checkoutMap`, in place of the
placeholder pin:

```swift
KitoCheckoutFlow(model: checkout, onPlaceOrder: place)
    .checkoutMap { address in
        MyMapView(latitude: address.latitude, longitude: address.longitude)   // KitoMaps, MapKit, …
    }
```

The first step always has a way out. With `onClose` the header's close button calls it. Without
it, the button dismisses the flow when it's presented, so a checkout that starts at
`.delivery` (no bag step) in a sheet or full-screen cover can still be closed. Use
`.checkoutDismissButton(.hidden)` when your own chrome already has one.

The model holds everything, so you can also build your own screens around it:
`checkout.advance()`, `goBack()`, `go(to:)`, `issues`, `canContinue`, `totals`, `deliveryText`,
`placeOrder(using:)`.

## Totals

```swift
let totals = KitoCheckoutTotals(
    items: cart.items,
    rules: KitoCheckoutPricingRules(serviceFee: .fixed(50),
                                    vat: KitoVAT(percent: 16, mode: .exclusive),   // or .kenya (inclusive)
                                    freeDeliveryThreshold: 5_000,
                                    roundsToWholeUnits: true),                      // M-Pesa takes whole shillings
    deliveryFee: 250,
    promo: appliedCode,
    tip: .percent(10),
    discounts: [KitoCheckoutDiscount(title: "Loyalty points", amount: 120)])

totals.subtotal; totals.promoDiscount; totals.deliveryFee; totals.waivedDeliveryFee
totals.serviceFee; totals.vat; totals.tipAmount; totals.total
totals.lines          // for your own summary
```

The order is: subtotal, then promo, then other discounts, then delivery (free past the threshold or
with a free-delivery code), then a service fee on the subtotal. VAT comes next, on the discounted
goods (and on the fees too if you set `appliesToFees`), then the tip on the subtotal. Inclusive VAT
is shown in the total but not added again.

## Delivery

```swift
KitoAddressPicker(addresses: $addresses, selection: $addressID)          // add, edit, default, delete
KitoAddressPicker(addresses: $addresses, selection: $addressID) { address in
    MyMap(address)                                                       // your map in the form's slot
}
KitoDeliveryOptions(options, selection: $optionID, pickupPoint: $pointID)
KitoDeliverySlotPicker(schedule: schedule, selection: $slot)
```

The address form lists all 47 counties (`KitoKenya.counties`) and their main towns, and it checks
Kenyan phone numbers (`KitoKenyanPhone.normalize("0712 345 678")` gives `+254712345678`).
`address.formatted(.singleLine / .multiLine / .short / .courier)` drops empty parts and repeats such as
"Nairobi, Nairobi".

Slots come from rules: windows, days ahead, lead time, a same-day cut-off, closed weekdays and
capacity. Add bookings you already have by slot id:

```swift
let schedule = KitoDeliverySchedule(
    rules: KitoSlotRules(windows: [KitoTimeWindow(8, 10), KitoTimeWindow(14, 16)],
                         leadTime: 60 * 60, sameDayCutoffMinutes: 15 * 60, closedWeekdays: [1]),
    booked: ["2026-09-25-0800": 6])
schedule.availability(of: slot, now: .now)       // .available(remaining:), .fewLeft, .full, .cutOff, .past
schedule.firstAvailableSlot(now: .now)
```

## Payment

```swift
KitoPaymentMethodList(methods, selection: $methodID, total: totals.total,
                      applePay: KitoApplePay.availability(for: applePayConfig)) { showAddCard = true }
KitoTipSelector(tip: $tip, subtotal: totals.subtotal)
KitoApplePayButton(type: .buy) { pay() }
```

A wallet that can't cover the total, a card past its expiry month, a cash-on-delivery limit and an
invalid M-Pesa number each switch the method off and say why.

For M-Pesa and card entry, KitoCheckout doesn't draw its own screens. It works alongside
[KitoScreens](https://github.com/wykeenjenga/KitoScreens): present `KitoMpesaScreen` from your
`onPlaceOrder` closure (or send the STK push yourself), and present `KitoCardCheckoutScreen` from
`onAddCard`, then add the saved card with `.card(brand, last4:, expiry:)`.

### Apple Pay

```swift
let config = KitoApplePayConfiguration(merchantIdentifier: "merchant.com.yourcompany.shop",
                                       merchantName: "Your Shop", countryCode: "KE", currencyCode: "KES")
let request = try KitoApplePay.makeRequest(configuration: config, totals: totals)
let outcome = await KitoApplePay.present(request) { payment in
    await api.charge(token: payment.token.paymentData)          // your payment provider
}
```

Apple Pay needs the **Apple Pay capability** on your app target with a **merchant ID** from the
Apple Developer portal, and a payment provider that can decrypt the token. Until then Apple Pay
still appears in the list, switched off, with "Apple Pay isn't set up for this shop yet."
`KitoApplePayNotice` explains what's needed. It never tries to open the sheet, so nothing crashes.
On a device with no cards the row says "Add a card to Apple Wallet". Once it's configured,
choosing Apple Pay changes the review button to Apple's own button, and the flow puts the token in
the order it sends you.

## Review and done

```swift
KitoOrderSummary(totals: totals)                         // items with thumbnails, then each charge
KitoTermsCheckbox(isOn: $accepted, text: "I agree to the [Terms](https://example.com/terms)")
KitoGiftNoteField(isGift: $isGift, note: $note, limit: 150)
KitoOrderSuccessView(order: placed, onTrackOrder: { … }, onContinueShopping: { … })
```

`KitoOrderSuccessView` draws a checkmark, fires confetti, shows the order number (tap to copy) and the
ETA, and has a "Share receipt" button for `order.receiptText`. Order numbers:

```swift
KitoOrderNumber.dated(42, date: .now)       // "KC-260924-0042"
KitoOrderNumber.random()                    // "KC-7QHM-X9TP", with no 0/O, 1/I/L look-alikes
KitoOrderNumber.grouped("10423381")         // "1042 3381"
```

Every view reads `@Environment(\.kitoTheme)`, takes an optional `tint` (black in light mode and white
in dark by default), respects Reduce Motion, has VoiceOver labels and works in light and dark mode.

## Right-to-left

- The flow, step header, progress bars and step transitions mirror automatically in Arabic/Hebrew layouts.
- The Back button and the payment/address disclosure chevrons use `chevron.backward` / `chevron.forward`, so they point the right way in RTL.
- The confetti and map placeholder are decorative drawings and stay as they are.
- Money, tip and VAT strings use fixed Latin digits; localise them yourself if you need locale digits.

## Installation

```swift
.package(url: "https://github.com/WykSofts-Inc/KitoCheckout.git", from: "0.2.0")
```

Requires iOS 17. KitoCheckout depends on KitoCore and KitoCart.

## License

MIT — see [LICENSE](LICENSE).
