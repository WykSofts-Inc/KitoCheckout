//
//  KitoOrderNumber.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// Order numbers people can read out over the phone.
public enum KitoOrderNumber {
    /// Letters and digits that can't be mistaken for each other: no 0/O, 1/I/L, 5/S, 2/Z, 8/B.
    public static let alphabet: [Character] = Array("34679ACDEFGHJKMNPQRTUVWXY")

    /// "KC-240926-0042": a prefix, the date (yyMMdd in the calendar's time zone) and a padded sequence.
    public static func dated(_ sequence: Int, prefix: String = "KC", date: Date, digits: Int = 4, calendar: Calendar = KitoCheckoutDefaults.calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let day = String(format: "%02d%02d%02d", (parts.year ?? 0) % 100, parts.month ?? 0, parts.day ?? 0)
        let number = String(max(sequence, 0))
        let padded = String(repeating: "0", count: max(digits - number.count, 0)) + number
        return join(prefix, [day, padded])
    }

    /// "KC-7QHM-X9TP": random characters from `alphabet`, in groups.
    public static func random<Generator: RandomNumberGenerator>(prefix: String = "KC", length: Int = 8, groupSize: Int = 4, using generator: inout Generator) -> String {
        let characters = (0..<max(length, 1)).map { _ in alphabet[Int.random(in: 0..<alphabet.count, using: &generator)] }
        return join(prefix, chunks(String(characters), size: groupSize))
    }

    public static func random(prefix: String = "KC", length: Int = 8, groupSize: Int = 4) -> String {
        var generator = SystemRandomNumberGenerator()
        return random(prefix: prefix, length: length, groupSize: groupSize, using: &generator)
    }

    /// Splits a long number into groups: "10423381" → "1042 3381".
    public static func grouped(_ raw: String, size: Int = 4, separator: String = " ") -> String {
        let compact = raw.filter { !$0.isWhitespace && $0 != "-" }
        return chunks(compact, size: size).joined(separator: separator)
    }

    static func chunks(_ value: String, size: Int) -> [String] {
        let characters = Array(value)
        let step = max(size, 1)
        return stride(from: 0, to: characters.count, by: step).map { start in
            String(characters[start..<min(start + step, characters.count)])
        }
    }

    private static func join(_ prefix: String, _ parts: [String]) -> String {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return ((trimmed.isEmpty ? [] : [trimmed]) + parts).joined(separator: "-")
    }
}
