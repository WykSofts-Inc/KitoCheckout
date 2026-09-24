// swift-tools-version: 5.9
//
//  Package.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "KitoCheckout",
    platforms: [.iOS(.v17)],
    products: [.library(name: "KitoCheckout", targets: ["KitoCheckout"])],
    dependencies: [
        .package(url: "https://github.com/WykSofts-Inc/KitoCore.git", from: "1.1.0"),
        .package(url: "https://github.com/WykSofts-Inc/KitoCart.git", from: "1.1.1"),
    ],
    targets: [
        .target(name: "KitoCheckout", dependencies: [
            .product(name: "KitoCore", package: "KitoCore"),
            .product(name: "KitoCart", package: "KitoCart"),
        ]),
        .testTarget(name: "KitoCheckoutTests", dependencies: ["KitoCheckout"]),
    ]
)
