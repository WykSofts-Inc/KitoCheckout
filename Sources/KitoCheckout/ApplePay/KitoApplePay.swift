//
//  KitoApplePay.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation
import PassKit

/// Card networks to accept through Apple Pay.
public enum KitoApplePayNetwork: String, CaseIterable, Hashable, Sendable {
    case visa, masterCard, amex, discover, maestro, unionPay

    var passKit: PKPaymentNetwork {
        switch self {
        case .visa: return .visa
        case .masterCard: return .masterCard
        case .amex: return .amex
        case .discover: return .discover
        case .maestro: return .maestro
        case .unionPay: return .chinaUnionPay
        }
    }
}

/// Your Apple Pay setup. Without a merchant identifier Apple Pay is shown as "not set up" and
/// can't be chosen — nothing crashes and no sheet is attempted.
public struct KitoApplePayConfiguration: Hashable, Sendable {
    /// "merchant.com.yourcompany.shop", from the Apple Developer portal. It must also be listed
    /// under the Apple Pay capability in your app target.
    public var merchantIdentifier: String?
    /// The name on the total line of the sheet: "Pay Duka Moja".
    public var merchantName: String
    public var countryCode: String
    public var currencyCode: String
    public var networks: [KitoApplePayNetwork]
    public var requiresThreeDS: Bool

    public init(
        merchantIdentifier: String?,
        merchantName: String,
        countryCode: String = "KE",
        currencyCode: String = KitoCheckoutDefaults.currencyCode,
        networks: [KitoApplePayNetwork] = [.visa, .masterCard, .amex],
        requiresThreeDS: Bool = true
    ) {
        self.merchantIdentifier = merchantIdentifier
        self.merchantName = merchantName
        self.countryCode = countryCode
        self.currencyCode = currencyCode
        self.networks = networks
        self.requiresThreeDS = requiresThreeDS
    }

    /// True when the identifier looks like a real one ("merchant." followed by something).
    public var hasMerchantIdentifier: Bool {
        guard let id = merchantIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return id.hasPrefix("merchant.") && id.count > "merchant.".count
    }
}

/// Whether Apple Pay can be used here.
public enum KitoApplePayAvailability: Hashable, Sendable {
    case available
    /// The device supports Apple Pay but has no card for the accepted networks yet.
    case needsSetup
    /// The app has no merchant identifier configured.
    case notConfigured
    /// This device or region can't use Apple Pay.
    case unsupported

    public var isUsable: Bool { self == .available }

    /// Copy for the payment row and the notice; `nil` when available.
    public var message: String? {
        switch self {
        case .available: return nil
        case .needsSetup: return "Add a card to Apple Wallet to pay with Apple Pay."
        case .notConfigured: return "Apple Pay isn't set up for this shop yet."
        case .unsupported: return "Apple Pay isn't available on this device."
        }
    }
}

public enum KitoApplePayError: Error, Equatable, Sendable {
    case notConfigured
    case unsupported
    case invalidAmount
}

/// How the Apple Pay sheet ended.
public enum KitoApplePayOutcome: Equatable, Sendable {
    /// The payment was authorised and your closure accepted it.
    case authorized
    case cancelled
    case failed(String)
}

/// A line on the Apple Pay sheet.
public struct KitoApplePayLine: Hashable, Sendable {
    public let label: String
    public let amount: Decimal

    public init(label: String, amount: Decimal) {
        self.label = label
        self.amount = amount
    }
}

/// Builds and presents an Apple Pay request from checkout totals.
public enum KitoApplePay {
    /// The pure decision, for tests and previews.
    public static func availability(hasMerchantIdentifier: Bool, deviceSupportsPayments: Bool, hasCards: Bool) -> KitoApplePayAvailability {
        if !hasMerchantIdentifier { return .notConfigured }
        if !deviceSupportsPayments { return .unsupported }
        return hasCards ? .available : .needsSetup
    }

    /// Asks PassKit. Pass `nil` when your app has no Apple Pay setup at all.
    public static func availability(for configuration: KitoApplePayConfiguration?) -> KitoApplePayAvailability {
        guard let configuration, configuration.hasMerchantIdentifier else { return .notConfigured }
        let networks = configuration.networks.map(\.passKit)
        return availability(
            hasMerchantIdentifier: true,
            deviceSupportsPayments: PKPaymentAuthorizationController.canMakePayments(),
            hasCards: PKPaymentAuthorizationController.canMakePayments(usingNetworks: networks)
        )
    }

    /// The sheet's lines: each charge, then "Pay <merchant>" with the total. Included VAT isn't
    /// listed, since it's already inside the prices.
    public static func summaryLines(for totals: KitoCheckoutTotals, merchantName: String) -> [KitoApplePayLine] {
        var lines: [KitoApplePayLine] = []
        for line in totals.lines where line.kind != .total && !line.isIncluded {
            lines.append(KitoApplePayLine(label: line.title, amount: line.amount))
        }
        lines.append(KitoApplePayLine(label: merchantName, amount: totals.total))
        return lines
    }

    /// A request ready for `present(_:authorize:)`.
    public static func makeRequest(configuration: KitoApplePayConfiguration, totals: KitoCheckoutTotals) throws -> PKPaymentRequest {
        guard configuration.hasMerchantIdentifier, let merchant = configuration.merchantIdentifier else { throw KitoApplePayError.notConfigured }
        guard totals.total > 0 else { throw KitoApplePayError.invalidAmount }
        let request = PKPaymentRequest()
        request.merchantIdentifier = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        request.countryCode = configuration.countryCode
        request.currencyCode = configuration.currencyCode
        request.supportedNetworks = configuration.networks.map(\.passKit)
        request.merchantCapabilities = configuration.requiresThreeDS ? .threeDSecure : [.threeDSecure, .credit, .debit]
        request.paymentSummaryItems = summaryLines(for: totals, merchantName: configuration.merchantName).map { line in
            PKPaymentSummaryItem(label: line.label, amount: NSDecimalNumber(decimal: line.amount))
        }
        return request
    }

    /// Shows the Apple Pay sheet. `authorize` receives the payment — send `payment.token.paymentData`
    /// to your provider and return whether it went through.
    @MainActor
    public static func present(_ request: PKPaymentRequest, authorize: @escaping @MainActor (PKPayment) async -> Bool) async -> KitoApplePayOutcome {
        let session = KitoApplePaySession(authorize: authorize)
        return await session.run(request)
    }
}

/// Keeps the controller and its delegate alive for the length of one sheet.
final class KitoApplePaySession: NSObject, PKPaymentAuthorizationControllerDelegate, @unchecked Sendable {
    private let authorize: @MainActor (PKPayment) async -> Bool
    private var continuation: CheckedContinuation<KitoApplePayOutcome, Never>?
    private var controller: PKPaymentAuthorizationController?
    private var outcome: KitoApplePayOutcome = .cancelled
    private static var active: KitoApplePaySession?

    init(authorize: @escaping @MainActor (PKPayment) async -> Bool) {
        self.authorize = authorize
    }

    @MainActor
    func run(_ request: PKPaymentRequest) async -> KitoApplePayOutcome {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            Self.active = self
            let controller = PKPaymentAuthorizationController(paymentRequest: request)
            controller.delegate = self
            self.controller = controller
            controller.present { [weak self] presented in
                guard !presented else { return }
                DispatchQueue.main.async { self?.finish(.failed("Apple Pay couldn't be opened.")) }
            }
        }
    }

    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        let authorize = self.authorize
        Task { @MainActor in
            let accepted = await authorize(payment)
            self.outcome = accepted ? .authorized : .failed("The payment didn't go through.")
            completion(PKPaymentAuthorizationResult(status: accepted ? .success : .failure, errors: nil))
        }
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss { [weak self] in
            DispatchQueue.main.async { self?.finish(nil) }
        }
    }

    private func finish(_ override: KitoApplePayOutcome?) {
        continuation?.resume(returning: override ?? outcome)
        continuation = nil
        controller = nil
        Self.active = nil
    }
}
