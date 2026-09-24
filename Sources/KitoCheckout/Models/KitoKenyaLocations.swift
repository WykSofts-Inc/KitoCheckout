//
//  KitoKenyaLocations.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// One of Kenya's 47 counties, with its main towns (for Nairobi, its best-known areas).
public struct KitoCounty: Identifiable, Hashable, Sendable {
    /// The official county code, 1 (Mombasa) to 47 (Nairobi).
    public let code: Int
    public let name: String
    public let towns: [String]

    public var id: Int { code }

    public init(code: Int, name: String, towns: [String]) {
        self.code = code
        self.name = name
        self.towns = towns
    }
}

/// The counties and towns the address form offers.
public enum KitoKenya {
    public static func county(named name: String) -> KitoCounty? {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return counties.first { $0.name.lowercased() == key }
    }

    public static func towns(in county: String) -> [String] {
        self.county(named: county)?.towns ?? []
    }

    /// The county a town belongs to, when it's one of the listed towns.
    public static func county(containing town: String) -> KitoCounty? {
        let key = town.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return counties.first { county in county.towns.contains { $0.lowercased() == key } }
    }

    /// All 47 counties, sorted by name.
    public static var sortedCounties: [KitoCounty] { counties.sorted { $0.name < $1.name } }

    /// All 47 counties in county-code order.
    public static let counties: [KitoCounty] = [
        KitoCounty(code: 1, name: "Mombasa", towns: ["Mombasa", "Nyali", "Bamburi", "Likoni", "Changamwe", "Kisauni", "Shanzu"]),
        KitoCounty(code: 2, name: "Kwale", towns: ["Kwale", "Ukunda", "Diani", "Msambweni", "Kinango", "Lunga Lunga"]),
        KitoCounty(code: 3, name: "Kilifi", towns: ["Kilifi", "Malindi", "Watamu", "Mtwapa", "Mariakani", "Kaloleni"]),
        KitoCounty(code: 4, name: "Tana River", towns: ["Hola", "Garsen", "Bura", "Madogo"]),
        KitoCounty(code: 5, name: "Lamu", towns: ["Lamu", "Mpeketoni", "Faza", "Hindi"]),
        KitoCounty(code: 6, name: "Taita-Taveta", towns: ["Voi", "Wundanyi", "Taveta", "Mwatate"]),
        KitoCounty(code: 7, name: "Garissa", towns: ["Garissa", "Dadaab", "Masalani", "Modogashe"]),
        KitoCounty(code: 8, name: "Wajir", towns: ["Wajir", "Habaswein", "Griftu", "Eldas"]),
        KitoCounty(code: 9, name: "Mandera", towns: ["Mandera", "El Wak", "Rhamu", "Takaba"]),
        KitoCounty(code: 10, name: "Marsabit", towns: ["Marsabit", "Moyale", "Laisamis", "North Horr"]),
        KitoCounty(code: 11, name: "Isiolo", towns: ["Isiolo", "Garbatulla", "Merti", "Kinna"]),
        KitoCounty(code: 12, name: "Meru", towns: ["Meru", "Maua", "Timau", "Nkubu", "Mitunguu"]),
        KitoCounty(code: 13, name: "Tharaka-Nithi", towns: ["Chuka", "Kathwana", "Marimanti", "Chogoria"]),
        KitoCounty(code: 14, name: "Embu", towns: ["Embu", "Runyenjes", "Siakago", "Kiritiri"]),
        KitoCounty(code: 15, name: "Kitui", towns: ["Kitui", "Mwingi", "Mutomo", "Kyuso"]),
        KitoCounty(code: 16, name: "Machakos", towns: ["Machakos", "Athi River", "Mlolongo", "Syokimau", "Kangundo", "Tala"]),
        KitoCounty(code: 17, name: "Makueni", towns: ["Wote", "Makindu", "Kibwezi", "Emali", "Mtito Andei"]),
        KitoCounty(code: 18, name: "Nyandarua", towns: ["Ol Kalou", "Engineer", "Njabini", "Ndaragwa"]),
        KitoCounty(code: 19, name: "Nyeri", towns: ["Nyeri", "Karatina", "Othaya", "Naro Moru", "Mukurweini"]),
        KitoCounty(code: 20, name: "Kirinyaga", towns: ["Kerugoya", "Kutus", "Sagana", "Wang'uru", "Kagio"]),
        KitoCounty(code: 21, name: "Murang'a", towns: ["Murang'a", "Kenol", "Kangema", "Maragua", "Kandara"]),
        KitoCounty(code: 22, name: "Kiambu", towns: ["Kiambu", "Thika", "Ruiru", "Juja", "Kikuyu", "Limuru", "Ruaka", "Githunguri"]),
        KitoCounty(code: 23, name: "Turkana", towns: ["Lodwar", "Kakuma", "Lokichogio", "Lokichar"]),
        KitoCounty(code: 24, name: "West Pokot", towns: ["Kapenguria", "Makutano", "Chepareria", "Sigor"]),
        KitoCounty(code: 25, name: "Samburu", towns: ["Maralal", "Baragoi", "Archers Post", "Wamba"]),
        KitoCounty(code: 26, name: "Trans-Nzoia", towns: ["Kitale", "Endebess", "Kiminini", "Saboti"]),
        KitoCounty(code: 27, name: "Uasin Gishu", towns: ["Eldoret", "Burnt Forest", "Turbo", "Moi's Bridge"]),
        KitoCounty(code: 28, name: "Elgeyo-Marakwet", towns: ["Iten", "Kapsowar", "Chepkorio", "Tambach"]),
        KitoCounty(code: 29, name: "Nandi", towns: ["Kapsabet", "Nandi Hills", "Mosoriot", "Kobujoi"]),
        KitoCounty(code: 30, name: "Baringo", towns: ["Kabarnet", "Eldama Ravine", "Marigat", "Mogotio"]),
        KitoCounty(code: 31, name: "Laikipia", towns: ["Nanyuki", "Nyahururu", "Rumuruti", "Doldol"]),
        KitoCounty(code: 32, name: "Nakuru", towns: ["Nakuru", "Naivasha", "Gilgil", "Molo", "Njoro", "Subukia"]),
        KitoCounty(code: 33, name: "Narok", towns: ["Narok", "Kilgoris", "Ololulung'a", "Nairagie Ngare"]),
        KitoCounty(code: 34, name: "Kajiado", towns: ["Kajiado", "Kitengela", "Ngong", "Ongata Rongai", "Isinya", "Namanga", "Loitokitok"]),
        KitoCounty(code: 35, name: "Kericho", towns: ["Kericho", "Litein", "Londiani", "Kipkelion"]),
        KitoCounty(code: 36, name: "Bomet", towns: ["Bomet", "Sotik", "Longisa", "Mulot"]),
        KitoCounty(code: 37, name: "Kakamega", towns: ["Kakamega", "Mumias", "Malava", "Butere", "Lugari"]),
        KitoCounty(code: 38, name: "Vihiga", towns: ["Vihiga", "Mbale", "Luanda", "Chavakali", "Hamisi"]),
        KitoCounty(code: 39, name: "Bungoma", towns: ["Bungoma", "Webuye", "Kimilili", "Chwele", "Malakisi"]),
        KitoCounty(code: 40, name: "Busia", towns: ["Busia", "Malaba", "Nambale", "Port Victoria", "Funyula"]),
        KitoCounty(code: 41, name: "Siaya", towns: ["Siaya", "Bondo", "Ugunja", "Yala", "Usenge"]),
        KitoCounty(code: 42, name: "Kisumu", towns: ["Kisumu", "Ahero", "Maseno", "Muhoroni", "Kombewa"]),
        KitoCounty(code: 43, name: "Homa Bay", towns: ["Homa Bay", "Mbita", "Oyugis", "Kendu Bay", "Ndhiwa"]),
        KitoCounty(code: 44, name: "Migori", towns: ["Migori", "Rongo", "Awendo", "Isebania", "Kehancha"]),
        KitoCounty(code: 45, name: "Kisii", towns: ["Kisii", "Ogembo", "Suneka", "Marani", "Nyamache"]),
        KitoCounty(code: 46, name: "Nyamira", towns: ["Nyamira", "Keroka", "Nyansiongo", "Ekerenyo"]),
        KitoCounty(code: 47, name: "Nairobi", towns: [
            "Nairobi CBD", "Westlands", "Kilimani", "Kileleshwa", "Lavington", "Karen", "Lang'ata",
            "Parklands", "Upper Hill", "South B", "South C", "Embakasi", "Kasarani", "Roysambu",
            "Eastleigh", "Donholm", "Runda", "Gigiri", "Kitisuru", "Kahawa",
        ]),
    ]
}
