//
//  KitoDeliverySlots.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// A daily delivery window, in minutes after midnight: `KitoTimeWindow(8, 10)` is 8–10 AM.
public struct KitoTimeWindow: Hashable, Sendable {
    public let startMinutes: Int
    public let endMinutes: Int

    public init(startMinutes: Int, endMinutes: Int) {
        self.startMinutes = max(0, min(startMinutes, 24 * 60))
        self.endMinutes = max(self.startMinutes, min(endMinutes, 24 * 60))
    }

    /// Whole hours: `KitoTimeWindow(14, 16)`.
    public init(_ startHour: Int, _ endHour: Int) {
        self.init(startMinutes: startHour * 60, endMinutes: endHour * 60)
    }

    public enum Style: Sendable {
        /// "8–10 AM", "11 AM–1 PM".
        case twelveHour
        /// "08:00–10:00".
        case twentyFourHour
    }

    public func label(_ style: Style = .twelveHour) -> String {
        switch style {
        case .twentyFourHour:
            return Self.clock24(startMinutes) + "–" + Self.clock24(endMinutes)
        case .twelveHour:
            let startPM = Self.isPM(startMinutes)
            let endPM = Self.isPM(endMinutes)
            if startPM == endPM {
                return Self.clock12(startMinutes) + "–" + Self.clock12(endMinutes) + (endPM ? " PM" : " AM")
            }
            return Self.clock12(startMinutes) + (startPM ? " PM" : " AM") + "–" + Self.clock12(endMinutes) + (endPM ? " PM" : " AM")
        }
    }

    /// Midnight at the end of the day reads as AM ("10 PM–12 AM").
    private static func isPM(_ minutes: Int) -> Bool {
        let hour = (minutes / 60) % 24
        return hour >= 12
    }

    private static func clock12(_ minutes: Int) -> String {
        let hour24 = (minutes / 60) % 24
        let minute = minutes % 60
        let hour = hour24 % 12 == 0 ? 12 : hour24 % 12
        return minute == 0 ? "\(hour)" : String(format: "%d:%02d", hour, minute)
    }

    private static func clock24(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

/// One bookable window on one day.
public struct KitoDeliverySlot: Identifiable, Hashable, Sendable {
    /// "2026-09-24-1400": the day and start time, stable across launches.
    public let id: String
    public let start: Date
    public let end: Date
    public let window: KitoTimeWindow
    public var capacity: Int
    public var booked: Int

    public init(id: String, start: Date, end: Date, window: KitoTimeWindow, capacity: Int, booked: Int = 0) {
        self.id = id
        self.start = start
        self.end = end
        self.window = window
        self.capacity = capacity
        self.booked = booked
    }

    public var remaining: Int { max(capacity - booked, 0) }
}

/// Whether a slot can be booked right now.
public enum KitoSlotAvailability: Equatable, Sendable {
    case available(remaining: Int)
    /// Bookable, but only a few places are left.
    case fewLeft(Int)
    case full
    /// Too close to the start (or past the same-day cut-off) to prepare in time.
    case cutOff
    /// The window has already ended.
    case past

    public var isSelectable: Bool {
        switch self {
        case .available, .fewLeft: return true
        case .full, .cutOff, .past: return false
        }
    }

    /// "4 left", "2 left", "Full", "Closed".
    public var label: String {
        switch self {
        case .available(let remaining): return "\(remaining) left"
        case .fewLeft(let remaining): return remaining == 1 ? "Last one" : "\(remaining) left"
        case .full: return "Full"
        case .cutOff, .past: return "Closed"
        }
    }
}

/// How slots are laid out and when they close.
public struct KitoSlotRules: Equatable, Sendable {
    public var windows: [KitoTimeWindow]
    /// How many days to offer, today included.
    public var daysAhead: Int
    /// A slot stops taking orders this long before it starts.
    public var leadTime: TimeInterval
    /// After this time of day (minutes after midnight) no more same-day slots are offered.
    public var sameDayCutoffMinutes: Int?
    /// Calendar weekdays with no deliveries (1 is Sunday).
    public var closedWeekdays: Set<Int>
    /// Orders each slot can take.
    public var capacity: Int
    /// At or below this many places a slot shows as "few left".
    public var fewLeftThreshold: Int
    public var calendar: Calendar

    public init(
        windows: [KitoTimeWindow] = [KitoTimeWindow(8, 10), KitoTimeWindow(10, 12), KitoTimeWindow(12, 14), KitoTimeWindow(14, 16), KitoTimeWindow(16, 18), KitoTimeWindow(18, 20)],
        daysAhead: Int = 7,
        leadTime: TimeInterval = 60 * 60,
        sameDayCutoffMinutes: Int? = nil,
        closedWeekdays: Set<Int> = [],
        capacity: Int = 6,
        fewLeftThreshold: Int = 2,
        calendar: Calendar = KitoCheckoutDefaults.calendar
    ) {
        self.windows = windows
        self.daysAhead = max(daysAhead, 1)
        self.leadTime = max(leadTime, 0)
        self.sameDayCutoffMinutes = sameDayCutoffMinutes
        self.closedWeekdays = closedWeekdays
        self.capacity = max(capacity, 0)
        self.fewLeftThreshold = max(fewLeftThreshold, 0)
        self.calendar = calendar
    }
}

/// A day in the picker with its slots.
public struct KitoDeliveryDay: Identifiable, Hashable, Sendable {
    /// Midnight at the start of the day.
    public let date: Date
    public let slots: [KitoDeliverySlot]

    public var id: Date { date }
}

/// Builds the days and slots from the rules and the bookings you already have, and answers
/// whether a slot can still be chosen.
public struct KitoDeliverySchedule: Equatable, Sendable {
    public var rules: KitoSlotRules
    /// Orders already booked, by slot id (`KitoDeliverySchedule.slotID(day:window:)`).
    public var booked: [String: Int]
    /// Per-slot capacity overrides, by slot id.
    public var capacityOverrides: [String: Int]

    public init(rules: KitoSlotRules = KitoSlotRules(), booked: [String: Int] = [:], capacityOverrides: [String: Int] = [:]) {
        self.rules = rules
        self.booked = booked
        self.capacityOverrides = capacityOverrides
    }

    /// "2026-09-24-1400".
    public func slotID(day: Date, window: KitoTimeWindow) -> String {
        let parts = rules.calendar.dateComponents([.year, .month, .day], from: day)
        let hour = window.startMinutes / 60
        let minute = window.startMinutes % 60
        return String(format: "%04d-%02d-%02d-%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, hour, minute)
    }

    /// The open days from today, skipping closed weekdays.
    public func days(from now: Date) -> [KitoDeliveryDay] {
        let calendar = rules.calendar
        let today = calendar.startOfDay(for: now)
        return (0..<rules.daysAhead).compactMap { offset -> KitoDeliveryDay? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            if rules.closedWeekdays.contains(calendar.component(.weekday, from: day)) { return nil }
            return KitoDeliveryDay(date: day, slots: slots(on: day))
        }
    }

    public func slots(on day: Date) -> [KitoDeliverySlot] {
        let calendar = rules.calendar
        let midnight = calendar.startOfDay(for: day)
        return rules.windows.compactMap { window in
            guard let start = calendar.date(byAdding: .minute, value: window.startMinutes, to: midnight),
                  let end = calendar.date(byAdding: .minute, value: window.endMinutes, to: midnight) else { return nil }
            let id = slotID(day: midnight, window: window)
            let capacity = capacityOverrides[id] ?? rules.capacity
            return KitoDeliverySlot(id: id, start: start, end: end, window: window, capacity: capacity, booked: booked[id] ?? 0)
        }
    }

    public func availability(of slot: KitoDeliverySlot, now: Date) -> KitoSlotAvailability {
        if now >= slot.end { return .past }
        if now > slot.start.addingTimeInterval(-rules.leadTime) { return .cutOff }
        if isPastSameDayCutoff(slot: slot, now: now) { return .cutOff }
        let remaining = max((capacityOverrides[slot.id] ?? slot.capacity) - (booked[slot.id] ?? slot.booked), 0)
        if remaining == 0 { return .full }
        if remaining <= rules.fewLeftThreshold { return .fewLeft(remaining) }
        return .available(remaining: remaining)
    }

    private func isPastSameDayCutoff(slot: KitoDeliverySlot, now: Date) -> Bool {
        guard let cutoff = rules.sameDayCutoffMinutes else { return false }
        let calendar = rules.calendar
        guard calendar.isDate(slot.start, inSameDayAs: now) else { return false }
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return minutes >= cutoff
    }

    public func isSelectable(_ slot: KitoDeliverySlot, now: Date) -> Bool {
        availability(of: slot, now: now).isSelectable
    }

    /// How many slots on the day can still be booked.
    public func openSlotCount(on day: KitoDeliveryDay, now: Date) -> Int {
        day.slots.filter { isSelectable($0, now: now) }.count
    }

    /// The earliest slot that can still be booked.
    public func firstAvailableSlot(now: Date) -> KitoDeliverySlot? {
        for day in days(from: now) {
            if let slot = day.slots.first(where: { isSelectable($0, now: now) }) { return slot }
        }
        return nil
    }

    /// "Today", "Tomorrow", or the short weekday ("Sat").
    public func dayTitle(for day: Date, now: Date) -> String {
        let calendar = rules.calendar
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
           calendar.isDate(day, inSameDayAs: tomorrow) { return "Tomorrow" }
        let index = calendar.component(.weekday, from: day) - 1
        let symbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return symbols.indices.contains(index) ? symbols[index] : ""
    }

    /// "Today, 2–4 PM", "Tomorrow, 8–10 AM", "Sat 26, 10 AM–12 PM".
    public func label(for slot: KitoDeliverySlot, now: Date, style: KitoTimeWindow.Style = .twelveHour) -> String {
        let title = dayTitle(for: slot.start, now: now)
        let isNear = title == "Today" || title == "Tomorrow"
        let day = rules.calendar.component(.day, from: slot.start)
        let dayText = isNear ? title : "\(title) \(day)"
        return dayText + ", " + slot.window.label(style)
    }
}
