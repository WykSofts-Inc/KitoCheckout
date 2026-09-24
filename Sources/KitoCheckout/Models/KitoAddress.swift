//
//  KitoAddress.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// What an address is called in the list: Home, Work or a name of your own.
public enum KitoAddressLabel: Hashable, Sendable {
    case home
    case work
    case other(String)

    public static let presets: [KitoAddressLabel] = [.home, .work]

    public var title: String {
        switch self {
        case .home: return "Home"
        case .work: return "Work"
        case .other(let name):
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Other" : trimmed
        }
    }

    public var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .work: return "briefcase.fill"
        case .other: return "mappin.circle.fill"
        }
    }
}

/// A delivery address in the shape Kenyan addresses are actually given: a building and street,
/// an estate or area, a town, a county and a landmark the rider can look for.
public struct KitoAddress: Identifiable, Hashable, Sendable {
    public var id: String
    public var label: KitoAddressLabel
    public var recipient: String
    public var phone: String
    /// "Argwings Kodhek Road".
    public var street: String
    /// "Mvuli Court, Block B, 4th floor".
    public var building: String
    /// The estate or neighbourhood, e.g. "Kilimani".
    public var area: String
    public var town: String
    public var county: String
    /// "Opposite the petrol station".
    public var landmark: String
    /// A note for the rider: "Call when at the gate".
    public var instructions: String
    public var isDefault: Bool
    public var latitude: Double?
    public var longitude: Double?

    public init(
        id: String = UUID().uuidString,
        label: KitoAddressLabel = .home,
        recipient: String = "",
        phone: String = "",
        street: String = "",
        building: String = "",
        area: String = "",
        town: String = "",
        county: String = "",
        landmark: String = "",
        instructions: String = "",
        isDefault: Bool = false,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.label = label
        self.recipient = recipient
        self.phone = phone
        self.street = street
        self.building = building
        self.area = area
        self.town = town
        self.county = county
        self.landmark = landmark
        self.instructions = instructions
        self.isDefault = isDefault
        self.latitude = latitude
        self.longitude = longitude
    }

    public var hasCoordinate: Bool { latitude != nil && longitude != nil }
}

/// The ways an address can be written out.
public enum KitoAddressFormat: Sendable {
    /// "Mvuli Court, Argwings Kodhek Road, Kilimani, Nairobi".
    case singleLine
    /// Building and street, then area, town and county, then the landmark — one per line.
    case multiLine
    /// "Kilimani, Nairobi".
    case short
    /// The multi-line form with the recipient and phone on top, for a delivery label.
    case courier
}

public extension KitoAddress {
    func formatted(_ format: KitoAddressFormat = .singleLine) -> String {
        switch format {
        case .singleLine:
            return KitoAddressFormatter.join([building, street, area, town, county])
        case .short:
            let short = KitoAddressFormatter.join([area, town])
            return short.isEmpty ? KitoAddressFormatter.join([street, county]) : short
        case .multiLine:
            return KitoAddressFormatter.lines(for: self).joined(separator: "\n")
        case .courier:
            let phoneLine = KitoKenyanPhone.display(phone) ?? phone
            let head = [recipient, phoneLine].map(KitoAddressFormatter.clean).filter { !$0.isEmpty }
            return (head + KitoAddressFormatter.lines(for: self)).joined(separator: "\n")
        }
    }
}

enum KitoAddressFormatter {
    static func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Joins the non-empty parts with ", ", dropping repeats such as "Nairobi, Nairobi".
    static func join(_ parts: [String]) -> String {
        var seen = Set<String>()
        var kept: [String] = []
        for part in parts.map(clean) where !part.isEmpty {
            let key = part.lowercased()
            if seen.insert(key).inserted { kept.append(part) }
        }
        return kept.joined(separator: ", ")
    }

    static func lines(for address: KitoAddress) -> [String] {
        let first = join([address.building, address.street])
        let second = join([address.area, address.town, address.county])
        let landmark = clean(address.landmark)
        let third = landmark.isEmpty ? "" : "Near \(landmark)"
        return [first, second, third].filter { !$0.isEmpty }
    }
}

/// A field of the address form, for pointing errors at the right place.
public enum KitoAddressField: String, CaseIterable, Hashable, Sendable {
    case recipient, phone, street, area, town, county

    public var title: String {
        switch self {
        case .recipient: return "Full name"
        case .phone: return "Phone number"
        case .street: return "Street or road"
        case .area: return "Estate or area"
        case .town: return "Town"
        case .county: return "County"
        }
    }
}

public extension KitoAddress {
    /// Everything that stops this address being saved, keyed by field. Empty when it's valid.
    func validationErrors() -> [KitoAddressField: String] {
        var errors: [KitoAddressField: String] = [:]
        let clean = KitoAddressFormatter.clean
        if clean(recipient).count < 2 { errors[.recipient] = "Enter the name of the person receiving it." }
        if clean(phone).isEmpty {
            errors[.phone] = "Enter a phone number so the rider can call."
        } else if KitoKenyanPhone.normalize(phone) == nil {
            errors[.phone] = "Enter a Kenyan number, e.g. 0712 345 678."
        }
        if clean(street).isEmpty && clean(building).isEmpty { errors[.street] = "Enter a street, road or building." }
        if clean(town).isEmpty { errors[.town] = "Choose a town." }
        if clean(county).isEmpty { errors[.county] = "Choose a county." }
        return errors
    }

    var isValid: Bool { validationErrors().isEmpty }
}

/// Kenyan mobile numbers: 07XX and 01XX, with or without +254.
public enum KitoKenyanPhone {
    /// "+254712345678", or `nil` when it isn't a Kenyan mobile number.
    public static func normalize(_ input: String) -> String? {
        let digits = input.filter(\.isNumber)
        var national: Substring
        if digits.hasPrefix("254") {
            national = digits.dropFirst(3)
        } else if digits.hasPrefix("0") {
            national = digits.dropFirst()
        } else {
            national = Substring(digits)
        }
        if national.hasPrefix("0") { national = national.dropFirst() }
        guard national.count == 9, let first = national.first, first == "7" || first == "1" else { return nil }
        return "+254" + national
    }

    /// "+254 712 345 678".
    public static func display(_ input: String) -> String? {
        guard let e164 = normalize(input) else { return nil }
        let national = Array(e164.dropFirst(4))
        return "+254 " + String(national[0..<3]) + " " + String(national[3..<6]) + " " + String(national[6..<9])
    }

    /// "0712 ••• 678", for showing which phone an M-Pesa prompt goes to.
    public static func masked(_ input: String) -> String? {
        guard let e164 = normalize(input) else { return nil }
        let national = Array(e164.dropFirst(4))
        return "0" + String(national[0..<3]) + " ••• " + String(national[6..<9])
    }
}
