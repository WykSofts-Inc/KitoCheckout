//
//  KitoCheckoutTests.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
import KitoCart
@testable import KitoCheckout

// MARK: - Helpers

private let nairobi = KitoCheckoutDefaults.calendar

/// A date in Nairobi time.
private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    nairobi.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? Date()
}

private func item(_ id: String, _ price: Decimal, _ quantity: Int = 1) -> KitoCartItem {
    KitoCartItem(id: id, name: id.capitalized, unitPrice: price, quantity: quantity)
}

/// Deterministic numbers for order-number tests.
private struct SplitMix: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Totals

final class KitoCheckoutTotalsTests: XCTestCase {
    func testSubtotalFeesAndTotalWithoutVAT() {
        let totals = KitoCheckoutTotals(items: [item("chapati", 50, 4), item("stew", 450)],
                                        rules: KitoCheckoutPricingRules(serviceFee: .fixed(30)), deliveryFee: 150)
        XCTAssertEqual(totals.subtotal, 650)
        XCTAssertEqual(totals.deliveryFee, 150)
        XCTAssertEqual(totals.serviceFee, 30)
        XCTAssertEqual(totals.vat, 0)
        XCTAssertEqual(totals.total, 830)
        XCTAssertEqual(totals.itemCount, 5)
    }

    func testInclusiveVATIsShownButNotAdded() {
        let totals = KitoCheckoutTotals(items: [item("shoes", 5_800)], rules: KitoCheckoutPricingRules(vat: .kenya), deliveryFee: 200)
        XCTAssertEqual(totals.vat, 800)          // 5,800 × 16 / 116
        XCTAssertEqual(totals.total, 6_000)
        XCTAssertTrue(totals.isVATIncluded)
        let line = totals.lines.first { $0.kind == .vat }
        XCTAssertEqual(line?.isIncluded, true)
        XCTAssertEqual(line?.title, "VAT 16% (included)")
    }

    func testExclusiveVATIsAddedOnTop() {
        let rules = KitoCheckoutPricingRules(vat: KitoVAT(percent: 16, mode: .exclusive))
        let totals = KitoCheckoutTotals(items: [item("lamp", 2_500)], rules: rules, deliveryFee: 100)
        XCTAssertEqual(totals.vat, 400)
        XCTAssertEqual(totals.total, 3_000)
        XCTAssertEqual(totals.lines.first { $0.kind == .vat }?.title, "VAT 16%")
    }

    func testVATCanIncludeFees() {
        let rules = KitoCheckoutPricingRules(serviceFee: .fixed(100), vat: KitoVAT(percent: 16, mode: .exclusive, appliesToFees: true))
        let totals = KitoCheckoutTotals(items: [item("bag", 1_000)], rules: rules, deliveryFee: 150)
        XCTAssertEqual(totals.vat, 200)          // 16% of 1,250
        XCTAssertEqual(totals.total, 1_450)
    }

    func testVATIsChargedAfterDiscounts() {
        let rules = KitoCheckoutPricingRules(vat: KitoVAT(percent: 16, mode: .exclusive))
        let promo = KitoPromoCode(code: "save10", kind: .percent(10))
        let totals = KitoCheckoutTotals(items: [item("jacket", 5_000)], rules: rules, promo: promo)
        XCTAssertEqual(totals.promoDiscount, 500)
        XCTAssertEqual(totals.vat, 720)          // 16% of 4,500
        XCTAssertEqual(totals.total, 5_220)
    }

    func testPercentPromoWithCapAndMinimum() {
        let capped = KitoPromoCode(code: "BIG", kind: .percent(20, cap: 300))
        XCTAssertEqual(KitoCheckoutTotals(items: [item("tv", 10_000)], promo: capped).promoDiscount, 300)

        let minimum = KitoPromoCode(code: "MIN", kind: .fixed(200), minimumSubtotal: 1_000)
        let short = KitoCheckoutTotals(items: [item("mug", 900)], promo: minimum)
        XCTAssertEqual(short.promoDiscount, 0)
        XCTAssertFalse(short.isPromoEligible)
        XCTAssertNil(short.lines.first { $0.kind == .promo })
        XCTAssertEqual(KitoCheckoutTotals(items: [item("mug", 1_200)], promo: minimum).promoDiscount, 200)
    }

    func testFreeDeliveryFromThresholdAndFromPromo() {
        let rules = KitoCheckoutPricingRules(freeDeliveryThreshold: 3_000)
        let over = KitoCheckoutTotals(items: [item("rug", 3_200)], rules: rules, deliveryFee: 250)
        XCTAssertEqual(over.deliveryFee, 0)
        XCTAssertEqual(over.waivedDeliveryFee, 250)
        XCTAssertEqual(over.lines.first { $0.kind == .delivery }?.originalAmount, 250)

        let under = KitoCheckoutTotals(items: [item("rug", 2_000)], rules: rules, deliveryFee: 250)
        XCTAssertEqual(under.deliveryFee, 250)

        let code = KitoPromoCode(code: "SHIP", kind: .freeDelivery)
        XCTAssertEqual(KitoCheckoutTotals(items: [item("pen", 100)], deliveryFee: 250, promo: code).total, 100)
    }

    func testServiceFeePercentWithBounds() {
        XCTAssertEqual(KitoServiceFee.percent(5).amount(on: 1_000), 50)
        XCTAssertEqual(KitoServiceFee.percent(5, minimum: 30).amount(on: 200), 30)
        XCTAssertEqual(KitoServiceFee.percent(5, maximum: 200).amount(on: 10_000), 200)
        XCTAssertEqual(KitoServiceFee.fixed(40).amount(on: 0), 0)
    }

    func testTipPercentagesRoundToWholeUnits() {
        XCTAssertEqual(KitoTip.percent(10).amount(on: 1_235), 124)          // 123.5 rounds half up
        XCTAssertEqual(KitoTip.percent(15).amount(on: 999), 150)           // 149.85
        XCTAssertEqual(KitoTip.percent(15).amount(on: 999, wholeUnits: false), Decimal(string: "149.85"))
        XCTAssertEqual(KitoTip.none.amount(on: 5_000), 0)
        XCTAssertEqual(KitoTip.custom(75).amount(on: 5_000), 75)
        XCTAssertEqual(KitoTip.custom(-5).amount(on: 5_000), 0)
    }

    func testTipIsOnTheSubtotalAndAddedToTotal() {
        let totals = KitoCheckoutTotals(items: [item("pizza", 1_200)], deliveryFee: 200, tip: .percent(10))
        XCTAssertEqual(totals.tipAmount, 120)
        XCTAssertEqual(totals.total, 1_520)
        XCTAssertEqual(totals.with(tip: .percent(5)).total, 1_460)
        XCTAssertEqual(totals.with(tip: .none).deliveryFee, 200)
    }

    func testOtherDiscountsNeverExceedTheSubtotal() {
        let discounts = [KitoCheckoutDiscount(title: "Points", amount: 300), KitoCheckoutDiscount(title: "Staff", amount: 500)]
        let totals = KitoCheckoutTotals(items: [item("book", 600)], discounts: discounts)
        XCTAssertEqual(totals.otherDiscounts, 600)
        XCTAssertEqual(totals.total, 0)
        let lines = totals.lines.filter { $0.kind == .discount }
        XCTAssertEqual(lines.map(\.amount), [-300, -300])
    }

    func testRoundingTheTotalToWholeUnits() {
        let rules = KitoCheckoutPricingRules(vat: KitoVAT(percent: 16, mode: .exclusive), roundsToWholeUnits: true)
        let totals = KitoCheckoutTotals(items: [item("soap", Decimal(string: "99.99") ?? 0)], rules: rules)
        XCTAssertEqual(totals.vat, 16)           // 15.9984 → 16.00
        XCTAssertEqual(totals.total, 116)        // 115.99 → 116

        let exact = KitoCheckoutPricingRules(vat: KitoVAT(percent: 16, mode: .exclusive), roundsToWholeUnits: false)
        XCTAssertEqual(KitoCheckoutTotals(items: [item("soap", Decimal(string: "99.99") ?? 0)], rules: exact).total, Decimal(string: "115.99"))
    }

    func testLinesOrderAndEmptyCart() {
        let rules = KitoCheckoutPricingRules(serviceFee: .fixed(20), vat: .kenya)
        let totals = KitoCheckoutTotals(items: [item("tea", 580)], rules: rules, deliveryFee: 100,
                                        promo: KitoPromoCode(code: "TEA", kind: .fixed(50)), tip: .custom(30))
        XCTAssertEqual(totals.lines.map(\.kind), [.subtotal, .promo, .delivery, .serviceFee, .vat, .tip, .total])
        XCTAssertEqual(totals.lines.first { $0.kind == .promo }?.title, "Promo TEA")

        let empty = KitoCheckoutTotals(items: [], rules: rules, deliveryFee: 100)
        XCTAssertEqual(empty.total, 0)
        XCTAssertEqual(empty.deliveryFee, 0)
    }
}

// MARK: - Slots

final class KitoDeliverySlotTests: XCTestCase {
    private let rules = KitoSlotRules(windows: [KitoTimeWindow(8, 10), KitoTimeWindow(12, 14), KitoTimeWindow(18, 20)],
                                      daysAhead: 4, leadTime: 60 * 60, capacity: 5, fewLeftThreshold: 2)

    func testDaysStartTodayAndSkipClosedWeekdays() {
        // Thursday 24 September 2026.
        let now = date(2026, 9, 24, 9)
        let open = KitoDeliverySchedule(rules: rules).days(from: now)
        XCTAssertEqual(open.count, 4)
        XCTAssertEqual(open.first?.slots.count, 3)

        var closedSunday = rules
        closedSunday.closedWeekdays = [1]
        let days = KitoDeliverySchedule(rules: closedSunday).days(from: now)
        XCTAssertEqual(days.map { nairobi.component(.day, from: $0.date) }, [24, 25, 26])
    }

    func testCutOffPastAndOpen() {
        let schedule = KitoDeliverySchedule(rules: rules)
        let now = date(2026, 9, 24, 11, 15)
        let slots = schedule.slots(on: now)
        XCTAssertEqual(schedule.availability(of: slots[0], now: now), .past)          // 8–10 has ended
        XCTAssertEqual(schedule.availability(of: slots[1], now: now), .cutOff)        // 12:00 minus an hour has passed
        XCTAssertEqual(schedule.availability(of: slots[2], now: now), .available(remaining: 5))
        XCTAssertEqual(schedule.availability(of: slots[1], now: date(2026, 9, 24, 10, 59)), .available(remaining: 5))
    }

    func testFullAndFewLeft() {
        let day = date(2026, 9, 25)
        let base = KitoDeliverySchedule(rules: rules)
        let morning = base.slotID(day: day, window: KitoTimeWindow(8, 10))
        let noon = base.slotID(day: day, window: KitoTimeWindow(12, 14))
        XCTAssertEqual(morning, "2026-09-25-0800")
        let schedule = KitoDeliverySchedule(rules: rules, booked: [morning: 5, noon: 4])
        let slots = schedule.slots(on: day)
        let now = date(2026, 9, 24, 20)
        XCTAssertEqual(schedule.availability(of: slots[0], now: now), .full)
        XCTAssertEqual(schedule.availability(of: slots[1], now: now), .fewLeft(1))
        XCTAssertEqual(KitoSlotAvailability.fewLeft(1).label, "Last one")
        XCTAssertFalse(schedule.isSelectable(slots[0], now: now))
        XCTAssertEqual(schedule.firstAvailableSlot(now: now)?.id, noon)
    }

    func testCapacityOverride() {
        let day = date(2026, 9, 25)
        let base = KitoDeliverySchedule(rules: rules)
        let evening = base.slotID(day: day, window: KitoTimeWindow(18, 20))
        let schedule = KitoDeliverySchedule(rules: rules, booked: [evening: 1], capacityOverrides: [evening: 1])
        XCTAssertEqual(schedule.availability(of: schedule.slots(on: day)[2], now: date(2026, 9, 24, 8)), .full)
    }

    func testSameDayCutoff() {
        var cutoff = rules
        cutoff.sameDayCutoffMinutes = 15 * 60
        let schedule = KitoDeliverySchedule(rules: cutoff)
        let evening = schedule.slots(on: date(2026, 9, 24))[2]
        XCTAssertEqual(schedule.availability(of: evening, now: date(2026, 9, 24, 14, 59)), .available(remaining: 5))
        XCTAssertEqual(schedule.availability(of: evening, now: date(2026, 9, 24, 15)), .cutOff)
        let tomorrow = schedule.slots(on: date(2026, 9, 25))[0]
        XCTAssertTrue(schedule.isSelectable(tomorrow, now: date(2026, 9, 24, 15)))
    }

    func testFirstAvailableRollsToTomorrow() {
        let schedule = KitoDeliverySchedule(rules: rules)
        let slot = schedule.firstAvailableSlot(now: date(2026, 9, 24, 19, 30))
        XCTAssertEqual(slot?.id, "2026-09-25-0800")
    }

    func testLabels() {
        let schedule = KitoDeliverySchedule(rules: rules)
        let now = date(2026, 9, 24, 7)
        XCTAssertEqual(schedule.dayTitle(for: date(2026, 9, 24), now: now), "Today")
        XCTAssertEqual(schedule.dayTitle(for: date(2026, 9, 25), now: now), "Tomorrow")
        XCTAssertEqual(schedule.dayTitle(for: date(2026, 9, 26), now: now), "Sat")
        let saturday = schedule.slots(on: date(2026, 9, 26))[1]
        XCTAssertEqual(schedule.label(for: saturday, now: now), "Sat 26, 12–2 PM")
        let today = schedule.slots(on: date(2026, 9, 24))[0]
        XCTAssertEqual(schedule.label(for: today, now: now), "Today, 8–10 AM")
    }

    func testTimeWindowLabels() {
        XCTAssertEqual(KitoTimeWindow(8, 10).label(), "8–10 AM")
        XCTAssertEqual(KitoTimeWindow(10, 12).label(), "10 AM–12 PM")
        XCTAssertEqual(KitoTimeWindow(12, 14).label(), "12–2 PM")
        XCTAssertEqual(KitoTimeWindow(22, 24).label(), "10 PM–12 AM")
        XCTAssertEqual(KitoTimeWindow(startMinutes: 510, endMinutes: 630).label(), "8:30–10:30 AM")
        XCTAssertEqual(KitoTimeWindow(8, 10).label(.twentyFourHour), "08:00–10:00")
    }
}

// MARK: - Validation

final class KitoCheckoutValidationTests: XCTestCase {
    private let now = date(2026, 9, 24, 10)
    private let home = KitoAddress(label: .home, recipient: "Achieng Otieno", phone: "0712345678", street: "Argwings Kodhek Road", town: "Kilimani", county: "Nairobi")
    private let standard = KitoDeliveryOption.standard(price: 250)

    func testEmptyBagBlocksTheBag() {
        let snapshot = KitoCheckoutSnapshot(items: [])
        XCTAssertEqual(KitoCheckoutValidator.issues(for: .bag, in: snapshot, now: now), [.emptyBag])
        let zero = KitoCheckoutSnapshot(items: [item("a", 10, 0)])
        XCTAssertFalse(KitoCheckoutValidator.canContinue(from: .bag, in: zero, now: now))
        XCTAssertTrue(KitoCheckoutValidator.canContinue(from: .bag, in: KitoCheckoutSnapshot(items: [item("a", 10)]), now: now))
    }

    func testDeliveryNeedsAnAddressUnlessPickup() {
        var snapshot = KitoCheckoutSnapshot(items: [item("a", 10)], deliveryOption: standard)
        XCTAssertEqual(KitoCheckoutValidator.issues(for: .delivery, in: snapshot, now: now), [.missingAddress])
        snapshot.address = home
        XCTAssertTrue(KitoCheckoutValidator.canContinue(from: .delivery, in: snapshot, now: now))

        let point = KitoPickupPoint(id: "p1", name: "Westlands Hub", address: "Waiyaki Way")
        var pickup = KitoCheckoutSnapshot(items: [item("a", 10)], deliveryOption: .pickup(points: [point]))
        XCTAssertEqual(KitoCheckoutValidator.issues(for: .delivery, in: pickup, now: now), [.missingPickupPoint])
        pickup.pickupPoint = point
        XCTAssertTrue(KitoCheckoutValidator.canContinue(from: .delivery, in: pickup, now: now))
    }

    func testDeliveryNeedsAnOptionThatIsAvailable() {
        XCTAssertEqual(KitoCheckoutValidator.issues(for: .delivery, in: KitoCheckoutSnapshot(items: [item("a", 10)]), now: now), [.missingDeliveryOption])
        var busy = KitoDeliveryOption.express(price: 450)
        busy.unavailableReason = "Express is busy right now."
        let snapshot = KitoCheckoutSnapshot(items: [item("a", 10)], address: home, deliveryOption: busy)
        XCTAssertEqual(KitoCheckoutValidator.issues(for: .delivery, in: snapshot, now: now), [.deliveryOptionUnavailable("Express is busy right now.")])
    }

    func testScheduledDeliveryNeedsAnOpenSlot() {
        let schedule = KitoDeliverySchedule(rules: KitoSlotRules(windows: [KitoTimeWindow(12, 14)], capacity: 3))
        var snapshot = KitoCheckoutSnapshot(items: [item("a", 10)], address: home, deliveryOption: .scheduled(price: 200), schedule: schedule)
        XCTAssertEqual(KitoCheckoutValidator.issues(for: .delivery, in: snapshot, now: now), [.missingSlot])
        let slot = schedule.slots(on: now)[0]
        snapshot.slot = slot
        XCTAssertTrue(KitoCheckoutValidator.canContinue(from: .delivery, in: snapshot, now: now))
        XCTAssertEqual(KitoCheckoutValidator.issues(for: .delivery, in: snapshot, now: date(2026, 9, 24, 11, 30)), [.slotUnavailable])
    }

    func testPaymentRules() {
        var snapshot = KitoCheckoutSnapshot(items: [item("a", 1_000)], total: 1_000)
        XCTAssertEqual(KitoCheckoutValidator.issues(for: .payment, in: snapshot, now: now), [.missingPayment])

        snapshot.paymentMethod = .wallet(balance: 400)
        XCTAssertEqual(KitoCheckoutValidator.issues(for: .payment, in: snapshot, now: now), [.paymentUnavailable("Balance too low — top up KES 600")])

        snapshot.paymentMethod = .card(.visa, last4: "4242", expiry: "08/26")
        XCTAssertEqual(KitoCheckoutValidator.issues(for: .payment, in: snapshot, now: now), [.paymentUnavailable("This card has expired")])
        snapshot.paymentMethod = .card(.visa, last4: "4242", expiry: "09/26")
        XCTAssertTrue(KitoCheckoutValidator.canContinue(from: .payment, in: snapshot, now: now))

        snapshot.paymentMethod = .mpesa(phone: "12345")
        XCTAssertEqual(KitoCheckoutValidator.issues(for: .payment, in: snapshot, now: now), [.paymentUnavailable("Add a valid M-Pesa number")])

        snapshot.paymentMethod = .cashOnDelivery(limit: 500)
        XCTAssertEqual(KitoCheckoutValidator.issues(for: .payment, in: snapshot, now: now), [.paymentUnavailable("Cash is accepted up to KES 500")])

        snapshot.paymentMethod = .applePay
        snapshot.applePay = .notConfigured
        XCTAssertEqual(KitoCheckoutValidator.issues(for: .payment, in: snapshot, now: now), [.applePayNotReady("Apple Pay isn't set up for this shop yet.")])
        snapshot.applePay = .available
        XCTAssertTrue(KitoCheckoutValidator.canContinue(from: .payment, in: snapshot, now: now))
    }

    func testReviewChecksEverythingAndTheTerms() {
        var snapshot = KitoCheckoutSnapshot(items: [item("a", 1_000)], address: home, deliveryOption: standard,
                                            paymentMethod: .mpesa(phone: "0712345678"), total: 1_250, requiresTerms: true)
        XCTAssertEqual(KitoCheckoutValidator.issues(for: .review, in: snapshot, now: now), [.termsNotAccepted])
        snapshot.acceptedTerms = true
        XCTAssertTrue(KitoCheckoutValidator.canContinue(from: .review, in: snapshot, now: now))
        snapshot.address = nil
        XCTAssertEqual(KitoCheckoutValidator.firstIncompleteStep(in: snapshot, now: now), .delivery)
        XCTAssertEqual(KitoCheckoutIssue.missingAddress.step, .delivery)
    }
}

// MARK: - Order numbers

final class KitoOrderNumberTests: XCTestCase {
    func testDatedNumbers() {
        XCTAssertEqual(KitoOrderNumber.dated(42, date: date(2026, 9, 24, 23, 30)), "KC-260924-0042")
        XCTAssertEqual(KitoOrderNumber.dated(123_456, prefix: "shop", date: date(2026, 1, 5), digits: 4), "SHOP-260105-123456")
        XCTAssertEqual(KitoOrderNumber.dated(7, prefix: "", date: date(2026, 12, 31), digits: 3), "261231-007")
    }

    func testRandomNumbersUseTheUnambiguousAlphabet() {
        var generator = SplitMix(state: 42)
        let number = KitoOrderNumber.random(prefix: "kc", length: 8, groupSize: 4, using: &generator)
        let parts = number.split(separator: "-")
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(parts[0], "KC")
        XCTAssertEqual(parts[1].count, 4)
        XCTAssertEqual(parts[2].count, 4)
        let body = parts.dropFirst().joined()
        XCTAssertTrue(body.allSatisfy { KitoOrderNumber.alphabet.contains($0) })
        for confusing in "01ILOSBZ258" { XCTAssertFalse(KitoOrderNumber.alphabet.contains(confusing)) }

        var again = SplitMix(state: 42)
        XCTAssertEqual(KitoOrderNumber.random(prefix: "kc", using: &again), number)
    }

    func testGrouping() {
        XCTAssertEqual(KitoOrderNumber.grouped("10423381"), "1042 3381")
        XCTAssertEqual(KitoOrderNumber.grouped("KC-104233", size: 3, separator: "-"), "KC1-042-33")
        XCTAssertEqual(KitoOrderNumber.grouped("12345", size: 2), "12 34 5")
    }
}

// MARK: - Addresses and phones

final class KitoAddressTests: XCTestCase {
    private let address = KitoAddress(label: .work, recipient: "Wanjiru Kamau", phone: "0722 123 456", street: "Waiyaki Way",
                                      building: "Delta Towers, 6th floor", area: "Westlands", town: "Westlands", county: "Nairobi",
                                      landmark: "the footbridge")

    func testSingleLineDropsEmptiesAndRepeats() {
        XCTAssertEqual(address.formatted(), "Delta Towers, 6th floor, Waiyaki Way, Westlands, Nairobi")
        let sparse = KitoAddress(street: "  Moi Avenue ", town: "Nairobi", county: "nairobi")
        XCTAssertEqual(sparse.formatted(.singleLine), "Moi Avenue, Nairobi")
    }

    func testShortMultiLineAndCourier() {
        XCTAssertEqual(address.formatted(.short), "Westlands")
        XCTAssertEqual(address.formatted(.multiLine), "Delta Towers, 6th floor, Waiyaki Way\nWestlands, Nairobi\nNear the footbridge")
        XCTAssertEqual(address.formatted(.courier), "Wanjiru Kamau\n+254 722 123 456\nDelta Towers, 6th floor, Waiyaki Way\nWestlands, Nairobi\nNear the footbridge")
        XCTAssertEqual(KitoAddress(street: "Kenyatta Road", county: "Kiambu").formatted(.short), "Kenyatta Road, Kiambu")
    }

    func testLabels() {
        XCTAssertEqual(KitoAddressLabel.home.title, "Home")
        XCTAssertEqual(KitoAddressLabel.other("  Shop ").title, "Shop")
        XCTAssertEqual(KitoAddressLabel.other("").title, "Other")
    }

    func testValidation() {
        XCTAssertTrue(address.isValid)
        let blank = KitoAddress()
        XCTAssertEqual(Set(blank.validationErrors().keys), [.recipient, .phone, .street, .town, .county])
        var badPhone = address
        badPhone.phone = "0812345678"
        XCTAssertEqual(badPhone.validationErrors().keys.first, .phone)
    }

    func testKenyanPhones() {
        XCTAssertEqual(KitoKenyanPhone.normalize("0712345678"), "+254712345678")
        XCTAssertEqual(KitoKenyanPhone.normalize("+254 712 345 678"), "+254712345678")
        XCTAssertEqual(KitoKenyanPhone.normalize("254110123456"), "+254110123456")
        XCTAssertEqual(KitoKenyanPhone.normalize("712345678"), "+254712345678")
        XCTAssertEqual(KitoKenyanPhone.normalize("+2540712345678"), "+254712345678")
        XCTAssertNil(KitoKenyanPhone.normalize("0212345678"))
        XCTAssertNil(KitoKenyanPhone.normalize("07123"))
        XCTAssertEqual(KitoKenyanPhone.display("0712345678"), "+254 712 345 678")
        XCTAssertEqual(KitoKenyanPhone.masked("0712345678"), "0712 ••• 678")
    }

    func testCounties() {
        XCTAssertEqual(KitoKenya.counties.count, 47)
        XCTAssertEqual(Set(KitoKenya.counties.map(\.code)), Set(1...47))
        XCTAssertEqual(KitoKenya.county(named: "nairobi")?.code, 47)
        XCTAssertTrue(KitoKenya.towns(in: "Kiambu").contains("Ruiru"))
        XCTAssertEqual(KitoKenya.county(containing: "Naivasha")?.name, "Nakuru")
        XCTAssertEqual(KitoKenya.sortedCounties.first?.name, "Baringo")
    }
}

// MARK: - Payment, delivery and Apple Pay values

final class KitoPaymentAndDeliveryTests: XCTestCase {
    func testCardBrandDetection() {
        XCTAssertEqual(KitoPaymentCardBrand.detect(number: "4242 4242 4242 4242"), .visa)
        XCTAssertEqual(KitoPaymentCardBrand.detect(number: "5555 5555 5555 4444"), .mastercard)
        XCTAssertEqual(KitoPaymentCardBrand.detect(number: "2221 0000 0000 0009"), .mastercard)
        XCTAssertEqual(KitoPaymentCardBrand.detect(number: "3782 822463 10005"), .amex)
        XCTAssertEqual(KitoPaymentCardBrand.detect(number: "6011 0000 0000 0004"), .other)
    }

    func testMethodTitlesAndSubtitles() {
        XCTAssertEqual(KitoPaymentMethod.card(.mastercard, last4: "1234567890124444").title, "Mastercard •••• 4444")
        XCTAssertEqual(KitoPaymentMethod.mpesa(phone: "0712345678").subtitle(), "Prompt sent to 0712 ••• 678")
        XCTAssertEqual(KitoPaymentMethod.wallet(balance: 1_250).subtitle(), "Balance KES 1,250")
        XCTAssertEqual(KitoPaymentMethod(id: "x", kind: .applePay, title: "Pay").title, "Pay")
    }

    func testCardExpiry() {
        let now = date(2026, 9, 24)
        XCTAssertFalse(KitoPaymentMethod.isExpired("09/26", now: now))
        XCTAssertTrue(KitoPaymentMethod.isExpired("08/26", now: now))
        XCTAssertTrue(KitoPaymentMethod.isExpired("12/2025", now: now))
        XCTAssertFalse(KitoPaymentMethod.isExpired("nonsense", now: now))
    }

    func testETALabels() {
        XCTAssertEqual(KitoDeliveryETA.minutes(30...45).label, "30–45 min")
        XCTAssertEqual(KitoDeliveryETA.hours(1...1).label, "1 hour")
        XCTAssertEqual(KitoDeliveryETA.days(0...0).label, "Today")
        XCTAssertEqual(KitoDeliveryETA.days(1...1).label, "Tomorrow")
        XCTAssertEqual(KitoDeliveryETA.days(2...4).label, "2–4 days")
        XCTAssertEqual(KitoDeliveryETA.days(1...1).arrivalText, "Arrives tomorrow")
        XCTAssertEqual(KitoDeliveryETA.minutes(20...30).arrivalText, "Arrives in 20–30 min")
        XCTAssertEqual(KitoPickupPoint(name: "A", address: "B", distanceKm: 0.4).distanceText, "400 m")
        XCTAssertEqual(KitoPickupPoint(name: "A", address: "B", distanceKm: 2.26).distanceText, "2.3 km")
        XCTAssertFalse(KitoDeliveryOption.pickup(points: []).requiresAddress)
    }

    func testApplePayAvailabilityAndLines() {
        XCTAssertEqual(KitoApplePay.availability(hasMerchantIdentifier: false, deviceSupportsPayments: true, hasCards: true), .notConfigured)
        XCTAssertEqual(KitoApplePay.availability(hasMerchantIdentifier: true, deviceSupportsPayments: false, hasCards: true), .unsupported)
        XCTAssertEqual(KitoApplePay.availability(hasMerchantIdentifier: true, deviceSupportsPayments: true, hasCards: false), .needsSetup)
        XCTAssertEqual(KitoApplePay.availability(hasMerchantIdentifier: true, deviceSupportsPayments: true, hasCards: true), .available)
        XCTAssertEqual(KitoApplePay.availability(for: nil), .notConfigured)
        XCTAssertFalse(KitoApplePayConfiguration(merchantIdentifier: "com.example", merchantName: "Shop").hasMerchantIdentifier)
        XCTAssertTrue(KitoApplePayConfiguration(merchantIdentifier: "merchant.com.example.shop", merchantName: "Shop").hasMerchantIdentifier)

        let totals = KitoCheckoutTotals(items: [item("a", 1_160)], rules: KitoCheckoutPricingRules(vat: .kenya), deliveryFee: 200, tip: .custom(40))
        let lines = KitoApplePay.summaryLines(for: totals, merchantName: "Duka Moja")
        XCTAssertEqual(lines.map(\.label), ["Subtotal", "Delivery", "Tip", "Duka Moja"])
        XCTAssertEqual(lines.last?.amount, 1_400)

        let config = KitoApplePayConfiguration(merchantIdentifier: nil, merchantName: "Shop")
        XCTAssertThrowsError(try KitoApplePay.makeRequest(configuration: config, totals: totals)) { error in
            XCTAssertEqual(error as? KitoApplePayError, .notConfigured)
        }
    }

    func testReceiptText() {
        let order = KitoPlacedOrder(number: "KC-260924-0042", eta: "Today, 2–4 PM", paymentTitle: "M-Pesa",
                                    items: [item("mandazi", 30, 4)], lines: KitoCheckoutTotals(items: [item("mandazi", 30, 4)], deliveryFee: 100).lines, total: 220)
        let receipt = order.receiptText
        XCTAssertTrue(receipt.hasPrefix("Order KC-260924-0042\nToday, 2–4 PM"))
        XCTAssertTrue(receipt.contains("4 × Mandazi — KES 120"))
        XCTAssertTrue(receipt.contains("Delivery: KES 100"))
        XCTAssertTrue(receipt.contains("Total: KES 220"))
        XCTAssertTrue(receipt.contains("Paid with M-Pesa"))
    }
}

// MARK: - Model

@MainActor
final class KitoCheckoutModelTests: XCTestCase {
    private let now = date(2026, 9, 24, 10)
    private let home = KitoAddress(id: "home", label: .home, recipient: "Achieng", phone: "0712345678", street: "Ngong Road", town: "Kilimani", county: "Nairobi")
    private let work = KitoAddress(id: "work", label: .work, recipient: "Achieng", phone: "0712345678", street: "Waiyaki Way", town: "Westlands", county: "Nairobi", isDefault: true)

    private func makeModel(items: [KitoCartItem] = [item("coffee", 1_200)], terms: String? = nil) -> KitoCheckoutModel {
        let fixed = now
        return KitoCheckoutModel(
            items: items,
            addresses: [home, work],
            deliveryOptions: [.standard(price: 250), .express(price: 450), .scheduled(price: 150)],
            schedule: KitoDeliverySchedule(rules: KitoSlotRules(windows: [KitoTimeWindow(14, 16)])),
            paymentMethods: [.wallet(balance: 100), .applePay, .mpesa(phone: "0712345678")],
            rules: KitoCheckoutPricingRules(serviceFee: .fixed(50)),
            offersTip: true,
            termsText: terms,
            now: { fixed }
        )
    }

    func testDefaultSelections() {
        let model = makeModel()
        XCTAssertEqual(model.step, .bag)
        XCTAssertEqual(model.selectedAddressID, "work")                  // the default address
        XCTAssertEqual(model.selectedDeliveryOptionID, "standard")
        XCTAssertEqual(model.selectedPaymentMethodID, "mpesa")           // wallet too low, Apple Pay not configured
        XCTAssertEqual(model.totals.total, 1_500)
    }

    func testAdvanceBackAndJump() {
        let model = makeModel()
        XCTAssertTrue(model.isFirstStep)
        XCTAssertFalse(model.goBack())
        XCTAssertTrue(model.advance())
        XCTAssertEqual(model.step, .delivery)
        XCTAssertTrue(model.isMovingForward)
        XCTAssertTrue(model.advance())
        XCTAssertTrue(model.advance())
        XCTAssertEqual(model.step, .review)
        XCTAssertTrue(model.isReviewStep)
        XCTAssertFalse(model.advance())
        XCTAssertTrue(model.go(to: .delivery))
        XCTAssertFalse(model.isMovingForward)
        XCTAssertTrue(model.go(to: .review))
    }

    func testCannotContinueWithoutAddressOrPayment() {
        let model = makeModel()
        model.advance()
        model.selectedAddressID = nil
        XCTAssertEqual(model.issues, [.missingAddress])
        XCTAssertFalse(model.advance())
        XCTAssertFalse(model.go(to: .review))
        model.selectedAddressID = "home"
        XCTAssertTrue(model.advance())
        model.selectedPaymentMethodID = nil
        XCTAssertEqual(model.issues, [.missingPayment])
        XCTAssertFalse(model.advance())
    }

    func testEmptyBagCannotContinue() {
        let model = makeModel(items: [])
        XCTAssertEqual(model.issues, [.emptyBag])
        XCTAssertFalse(model.advance())
    }

    func testChoosingScheduledPicksTheFirstOpenSlot() {
        let model = makeModel()
        model.selectedDeliveryOptionID = "scheduled"
        XCTAssertEqual(model.selectedSlot?.id, "2026-09-24-1400")
        XCTAssertEqual(model.deliveryText, "Today, 2–4 PM")
        XCTAssertEqual(model.totals.deliveryFee, 150)
    }

    func testTipChangesTheTotal() {
        let model = makeModel()
        model.tip = .percent(10)
        XCTAssertEqual(model.totals.tipAmount, 120)
        XCTAssertEqual(model.totals.total, 1_620)
        model.offersTip = false
        XCTAssertEqual(model.totals.total, 1_500)
    }

    func testSavingAnAddressMovesTheDefault() {
        let model = makeModel()
        let new = KitoAddress(id: "mum", label: .other("Mum"), recipient: "Mama", phone: "0722000111", street: "Thika Road", town: "Kasarani", county: "Nairobi", isDefault: true)
        model.save(new)
        XCTAssertEqual(model.selectedAddressID, "mum")
        XCTAssertEqual(model.addresses.filter(\.isDefault).map(\.id), ["mum"])
        model.removeAddress("mum")
        XCTAssertEqual(model.selectedAddressID, "home")
    }

    func testPlaceOrderSuccess() async {
        let model = makeModel(terms: "I agree")
        model.acceptedTerms = true
        model.isGift = false
        var received: KitoCheckoutOrder?
        let placed = await model.placeOrder { order in
            received = order
            return order.confirmed(number: "KC-1")
        }
        XCTAssertTrue(placed)
        XCTAssertEqual(model.step, .done)
        XCTAssertEqual(model.phase, .editing)
        XCTAssertEqual(model.placedOrder?.number, "KC-1")
        XCTAssertEqual(model.placedOrder?.total, 1_500)
        XCTAssertEqual(received?.address?.id, "work")
        XCTAssertEqual(received?.paymentMethod.id, "mpesa")
        XCTAssertFalse(model.goBack())
        model.reset()
        XCTAssertEqual(model.step, .bag)
        XCTAssertNil(model.placedOrder)
    }

    func testPlaceOrderNeedsTermsAndReportsErrors() async {
        struct Declined: LocalizedError { var errorDescription: String? { "M-Pesa request was cancelled." } }
        let model = makeModel(terms: "I agree")
        let blocked = await model.placeOrder { $0.confirmed(number: "X") }
        XCTAssertFalse(blocked)
        XCTAssertEqual(model.phase, .failed("Accept the terms to place your order."))

        model.acceptedTerms = true
        let failed = await model.placeOrder { _ in throw Declined() }
        XCTAssertFalse(failed)
        XCTAssertEqual(model.phase, .failed("M-Pesa request was cancelled."))
        model.dismissError()
        XCTAssertEqual(model.phase, .editing)
    }

    func testGiftNoteOnlyWhenOffered() {
        let model = makeModel()
        model.isGift = true
        model.giftNote = "Happy birthday!"
        XCTAssertNil(model.makeOrder()?.giftNote)
        model.offersGiftNote = true
        XCTAssertEqual(model.makeOrder()?.giftNote, "Happy birthday!")
    }

    func testStepsCanSkipTheBag() {
        let model = KitoCheckoutModel(items: [item("a", 100)], steps: [.delivery, .payment, .review, .done],
                                      deliveryOptions: [.pickup(points: [])], paymentMethods: [.cashOnDelivery()])
        XCTAssertEqual(model.steps, [.delivery, .payment, .review])
        XCTAssertEqual(model.step, .delivery)
        XCTAssertTrue(model.canContinue)
    }
}
