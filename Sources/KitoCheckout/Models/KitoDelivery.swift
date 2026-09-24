//
//  KitoDelivery.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

public enum KitoDeliveryKind: String, CaseIterable, Hashable, Sendable {
    case standard, express, pickup, scheduled

    public var systemImage: String {
        switch self {
        case .standard: return "shippingbox.fill"
        case .express: return "bolt.fill"
        case .pickup: return "storefront.fill"
        case .scheduled: return "calendar.badge.clock"
        }
    }
}

/// When an order arrives.
public enum KitoDeliveryETA: Hashable, Sendable {
    case minutes(ClosedRange<Int>)
    case hours(ClosedRange<Int>)
    /// 0 is today, 1 tomorrow.
    case days(ClosedRange<Int>)
    case text(String)

    /// "30–45 min", "2–3 hours", "Tomorrow", "2–4 days".
    public var label: String {
        switch self {
        case .minutes(let range): return Self.range(range) + " min"
        case .hours(let range): return Self.range(range) + (range.upperBound == 1 ? " hour" : " hours")
        case .days(let range):
            if range.upperBound == 0 { return "Today" }
            if range == 1...1 { return "Tomorrow" }
            if range.lowerBound == 0 { return "Within " + Self.range(range.upperBound...range.upperBound) + " days" }
            return Self.range(range) + " days"
        case .text(let text): return text
        }
    }

    /// For a confirmation: "Arrives in 30–45 min", "Arrives tomorrow".
    public var arrivalText: String {
        switch self {
        case .minutes, .hours: return "Arrives in " + label
        case .days(let range):
            if range.upperBound <= 1 { return "Arrives " + label.lowercased() }
            return "Arrives in " + label
        case .text(let text): return text
        }
    }

    private static func range(_ range: ClosedRange<Int>) -> String {
        range.lowerBound == range.upperBound ? "\(range.lowerBound)" : "\(range.lowerBound)–\(range.upperBound)"
    }
}

/// A shop, locker or agent where the customer collects the order.
public struct KitoPickupPoint: Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var address: String
    /// "Mon–Sat, 8 AM–8 PM".
    public var hours: String
    public var distanceKm: Double?

    public init(id: String = UUID().uuidString, name: String, address: String, hours: String = "", distanceKm: Double? = nil) {
        self.id = id
        self.name = name
        self.address = address
        self.hours = hours
        self.distanceKm = distanceKm
    }

    /// "1.2 km", or nil.
    public var distanceText: String? {
        guard let distanceKm else { return nil }
        if distanceKm < 1 { return "\(Int((distanceKm * 1000).rounded())) m" }
        return String(format: "%.1f km", distanceKm)
    }
}

/// A way to get the order: standard, express, pickup or a booked time slot.
public struct KitoDeliveryOption: Identifiable, Hashable, Sendable {
    public let id: String
    public var kind: KitoDeliveryKind
    public var title: String
    public var subtitle: String?
    public var price: Decimal
    public var eta: KitoDeliveryETA
    /// A short tag such as "Fastest" or "Cheapest".
    public var badge: String?
    /// The places to choose from when `kind` is `.pickup`.
    public var pickupPoints: [KitoPickupPoint]
    /// Whether the customer picks a day and time window for this option.
    public var usesTimeSlots: Bool
    /// Set to explain why it can't be chosen right now ("Express is busy — try again later").
    public var unavailableReason: String?

    public init(
        id: String,
        kind: KitoDeliveryKind,
        title: String,
        subtitle: String? = nil,
        price: Decimal,
        eta: KitoDeliveryETA,
        badge: String? = nil,
        pickupPoints: [KitoPickupPoint] = [],
        usesTimeSlots: Bool = false,
        unavailableReason: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.price = price
        self.eta = eta
        self.badge = badge
        self.pickupPoints = pickupPoints
        self.usesTimeSlots = usesTimeSlots
        self.unavailableReason = unavailableReason
    }

    public var isAvailable: Bool { unavailableReason == nil }

    /// Pickup orders don't need a delivery address.
    public var requiresAddress: Bool { kind != .pickup }

    public static func standard(price: Decimal, eta: KitoDeliveryETA = .days(1...2), title: String = "Standard delivery") -> KitoDeliveryOption {
        KitoDeliveryOption(id: "standard", kind: .standard, title: title, price: price, eta: eta)
    }

    public static func express(price: Decimal, eta: KitoDeliveryETA = .minutes(30...45), title: String = "Express") -> KitoDeliveryOption {
        KitoDeliveryOption(id: "express", kind: .express, title: title, price: price, eta: eta, badge: "Fastest")
    }

    public static func pickup(price: Decimal = 0, points: [KitoPickupPoint], eta: KitoDeliveryETA = .hours(2...4), title: String = "Pick up") -> KitoDeliveryOption {
        KitoDeliveryOption(id: "pickup", kind: .pickup, title: title, subtitle: "Collect from a pickup point near you", price: price, eta: eta, pickupPoints: points)
    }

    public static func scheduled(price: Decimal, title: String = "Choose a time") -> KitoDeliveryOption {
        KitoDeliveryOption(id: "scheduled", kind: .scheduled, title: title, subtitle: "Pick a day and a 2-hour window", price: price, eta: .text("At your chosen time"), usesTimeSlots: true)
    }
}
