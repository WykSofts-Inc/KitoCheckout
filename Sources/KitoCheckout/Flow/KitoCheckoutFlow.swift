//
//  KitoCheckoutFlow.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import UIKit
import KitoCore
import KitoCart

/// The whole checkout: Bag → Delivery → Payment → Review → Done, with a progress header, steps
/// that slide in the direction you're going, a back button, and a sticky bar whose total updates
/// as you change delivery, tip or promo.
///
/// ```swift
/// @State private var checkout = KitoCheckoutModel(
///     cart: cart,
///     addresses: savedAddresses,
///     deliveryOptions: [.standard(price: 250), .express(price: 450), .pickup(points: points)],
///     paymentMethods: [.mpesa(phone: "0712345678"), .card(.visa, last4: "4242", expiry: "08/28"), .cashOnDelivery()],
///     rules: KitoCheckoutPricingRules(serviceFee: .fixed(50), vat: .kenya, freeDeliveryThreshold: 5_000),
///     offersTip: true, termsText: "I agree to the [Terms](https://example.com/terms)")
///
/// KitoCheckoutFlow(model: checkout, onClose: { dismiss() }) { order in
///     let number = try await api.placeOrder(order)       // STK push, card charge, …
///     return order.confirmed(number: number)
/// }
/// .checkoutMap { address in MyMapView(address) }          // a real map on the delivery step
/// ```
///
/// On the first step the header shows a close button: it calls `onClose` when you pass one, and
/// otherwise dismisses the flow when it's presented (a sheet, a full-screen cover or a pushed
/// screen). Hide it with `.checkoutDismissButton(.hidden)`.
public struct KitoCheckoutFlow<Thumbnail: View>: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var model: KitoCheckoutModel
    let title: String
    let progressStyle: KitoCheckoutProgressStyle
    let tint: Color?
    let onClose: (() -> Void)?
    let onAddCard: (() -> Void)?
    let onTrackOrder: ((KitoPlacedOrder) -> Void)?
    let onContinueShopping: (() -> Void)?
    let onPlaceOrder: (KitoCheckoutOrder) async throws -> KitoPlacedOrder
    let thumbnail: (KitoCartItem) -> Thumbnail

    private var mapView: ((KitoAddress) -> AnyView)?
    private var dismissButton: Visibility = .automatic

    @Environment(\.dismiss) private var dismiss
    @Environment(\.isPresented) private var isPresented
    @State private var showsTermsError = false

    /// - Parameters:
    ///   - onClose: Shown as the close button on the first step and on the confirmation. Without
    ///     it, those buttons dismiss the flow when it's presented.
    ///   - onAddCard: Adds an "Add a card" row to the payment list — present your card form
    ///     (KitoScreens' `KitoCardCheckoutScreen` works well) and add the saved card to
    ///     `model.paymentMethods`.
    ///   - onPlaceOrder: Charge and submit the order, then return the confirmation
    ///     (`order.confirmed(number:)`). Throw to show the error above the button.
    public init(
        model: KitoCheckoutModel,
        title: String = "Checkout",
        progressStyle: KitoCheckoutProgressStyle = .dots,
        tint: Color? = nil,
        onClose: (() -> Void)? = nil,
        onAddCard: (() -> Void)? = nil,
        onTrackOrder: ((KitoPlacedOrder) -> Void)? = nil,
        onContinueShopping: (() -> Void)? = nil,
        onPlaceOrder: @escaping (KitoCheckoutOrder) async throws -> KitoPlacedOrder,
        @ViewBuilder thumbnail: @escaping (KitoCartItem) -> Thumbnail
    ) {
        self.model = model
        self.title = title
        self.progressStyle = progressStyle
        self.tint = tint
        self.onClose = onClose
        self.onAddCard = onAddCard
        self.onTrackOrder = onTrackOrder
        self.onContinueShopping = onContinueShopping
        self.onPlaceOrder = onPlaceOrder
        self.thumbnail = thumbnail
    }

    /// Puts your own map in the delivery step's address form, in place of the placeholder
    /// (KitoMaps, MapKit, …). The address carries `latitude` and `longitude` when it has them.
    public func checkoutMap<Map: View>(@ViewBuilder _ map: @escaping (KitoAddress) -> Map) -> KitoCheckoutFlow {
        var copy = self
        copy.mapView = { AnyView(map($0)) }
        return copy
    }

    /// Whether the first step and the confirmation show a close button. `.automatic` shows it
    /// when there's an `onClose` or the flow is presented; `.hidden` never shows it; `.visible`
    /// always does.
    public func checkoutDismissButton(_ visibility: Visibility) -> KitoCheckoutFlow {
        var copy = self
        copy.dismissButton = visibility
        return copy
    }

    /// What the close button does, or `nil` when there shouldn't be one.
    private var closeAction: (() -> Void)? {
        switch dismissButton {
        case .hidden:
            return nil
        case .visible:
            return onClose ?? { dismiss() }
        default:
            if let onClose { return onClose }
            return isPresented ? { dismiss() } : nil
        }
    }

    private var animation: Animation? { reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.48, dampingFraction: 0.86) }

    public var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            if model.step == .done, let order = model.placedOrder {
                KitoOrderSuccessView(order: order, tint: nil,
                                     onTrackOrder: onTrackOrder.map { track in { track(order) } },
                                     onContinueShopping: onContinueShopping ?? onClose)
                    .overlay(alignment: .topLeading) { closeButton }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                steps
                    .transition(.opacity)
            }
        }
        .animation(animation, value: model.step == .done)
        .onChange(of: model.acceptedTerms) { _, accepted in if accepted { showsTermsError = false } }
    }

    // MARK: Steps

    private var steps: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                stepScroll
                    .id(model.step)
                    .transition(stepTransition)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .clipped()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if case .failed(let message) = model.phase {
                    errorBanner(message)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                totalBar
            }
            .animation(animation, value: model.phase)
        }
    }

    private var header: some View {
        VStack(spacing: theme.spacing.md) {
            ZStack {
                Text(title)
                    .font(theme.typography.titleMedium)
                    .foregroundStyle(theme.colors.onBackground)
                    .accessibilityAddTraits(.isHeader)
                HStack {
                    backButton
                    Spacer()
                }
            }
            KitoCheckoutProgressHeader(steps: model.steps, current: model.step, style: progressStyle, tint: tint) { step in
                move(to: step)
            }
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.top, theme.spacing.sm)
        .padding(.bottom, theme.spacing.md)
        .background(theme.colors.background)
    }

    @ViewBuilder
    private var backButton: some View {
        if !model.isFirstStep {
            circleButton("chevron.backward", label: "Back") { goBack() }
        } else if let closeAction {
            circleButton("xmark", label: "Close", action: closeAction)
        }
    }

    @ViewBuilder
    private var closeButton: some View {
        if let closeAction {
            circleButton("xmark", label: "Close", action: closeAction)
                .padding(.leading, theme.spacing.lg)
                .padding(.top, theme.spacing.sm)
        }
    }

    private func circleButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(theme.colors.onSurface)
                .frame(width: 40, height: 40)
                .background(Circle().fill(theme.colors.surface))
                .overlay(Circle().strokeBorder(theme.colors.border, lineWidth: 1))
                .shadow(color: Color.black.opacity(0.06), radius: 6, y: 3)
        }
        .buttonStyle(KitoCheckoutPressStyle())
        .accessibilityLabel(label)
    }

    private var stepScroll: some View {
        ScrollView {
            stepContent
                .padding(.horizontal, theme.spacing.lg)
                .padding(.top, theme.spacing.sm)
                .padding(.bottom, theme.spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch model.step {
        case .bag:
            KitoBagStep(model: model, tint: tint, onContinueShopping: onContinueShopping, thumbnail: thumbnail)
        case .delivery:
            KitoDeliveryStep(model: model, tint: tint) { address in
                deliveryMap(address)
            }
        case .payment:
            KitoPaymentStep(model: model, tint: tint, onAddCard: onAddCard)
        case .review:
            KitoReviewStep(model: model, tint: tint, showsTermsError: showsTermsError, onChange: { move(to: $0) }, thumbnail: thumbnail)
        case .done:
            EmptyView()
        }
    }

    @ViewBuilder
    private func deliveryMap(_ address: KitoAddress) -> some View {
        if let mapView {
            mapView(address)
        } else {
            KitoMapPinPlaceholder(title: address.formatted(.short).isEmpty ? nil : address.formatted(.short), tint: tint)
        }
    }

    private var stepTransition: AnyTransition {
        if reduceMotion { return .opacity }
        let forward = model.isMovingForward
        return .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    // MARK: Bar

    private var usesApplePayButton: Bool {
        model.isReviewStep && model.selectedPaymentMethod?.isApplePay == true && model.applePayAvailability.isUsable
    }

    private var buttonTitle: String {
        guard model.isReviewStep else {
            return model.nextStep.map { "Continue to \($0.title.lowercased())" } ?? "Continue"
        }
        if model.selectedPaymentMethod?.isMpesa == true { return "Pay with M-Pesa" }
        if case .cashOnDelivery = model.selectedPaymentMethod?.kind { return "Place order" }
        return "Pay now"
    }

    private var caption: String? {
        let totals = model.totals
        if totals.isVATIncluded && totals.vat > 0 { return "Includes " + KitoCartMoney.string(totals.vat, currencyCode: model.currencyCode) + " VAT" }
        if totals.discountTotal > 0 { return "You save " + KitoCartMoney.string(totals.discountTotal, currencyCode: model.currencyCode) }
        let count = totals.itemCount
        return count == 1 ? "1 item" : "\(count) items"
    }

    /// The terms checkbox is the one thing the button lets you tap past, to point at it.
    private var blockingIssues: [KitoCheckoutIssue] {
        model.issues.filter { $0 != .termsNotAccepted }
    }

    private var totalBar: some View {
        KitoCheckoutTotalBar(
            total: model.totals.total,
            currencyCode: model.currencyCode,
            caption: caption,
            button: usesApplePayButton ? .applePay : .standard(buttonTitle),
            hint: blockingIssues.first?.message ?? (showsTermsError ? KitoCheckoutIssue.termsNotAccepted.message : nil),
            isEnabled: blockingIssues.isEmpty && !showsTermsError,
            isLoading: model.phase == .placing,
            tint: tint,
            action: primaryAction
        )
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: theme.spacing.sm) {
            Image(systemName: "xmark.octagon.fill").foregroundStyle(theme.colors.danger)
            Text(message)
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colors.onSurface)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button { model.dismissError() } label: {
                Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(theme.colors.onSurface.opacity(0.5))
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(theme.spacing.md)
        .background(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).fill(theme.colors.danger.opacity(0.12)))
        .padding(.horizontal, theme.spacing.lg)
        .padding(.bottom, theme.spacing.sm)
    }

    // MARK: Actions

    private func primaryAction() {
        model.dismissError()
        guard model.isReviewStep else {
            if let next = model.nextStep { move(to: next) }
            return
        }
        if model.issues.contains(.termsNotAccepted) {
            withAnimation(animation) { showsTermsError = true }
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        Task { await place() }
    }

    @MainActor
    private func place() async {
        if model.selectedPaymentMethod?.isApplePay == true, let configuration = model.applePayConfiguration {
            await payWithApplePay(configuration)
            return
        }
        let placed = await model.placeOrder(using: onPlaceOrder)
        if !placed { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    }

    @MainActor
    private func payWithApplePay(_ configuration: KitoApplePayConfiguration) async {
        do {
            let request = try KitoApplePay.makeRequest(configuration: configuration, totals: model.totals)
            let handler = onPlaceOrder
            let checkout = model
            let outcome = await KitoApplePay.present(request) { payment in
                await checkout.placeOrder(applePayToken: payment.token.paymentData, using: handler)
            }
            if case .failed(let message) = outcome, model.step != .done { model.fail(message) }
        } catch {
            model.fail(KitoApplePayAvailability.notConfigured.message ?? "Apple Pay isn't available.")
        }
    }

    private func move(to target: KitoCheckoutStep) {
        let forward = target > model.step
        if model.isMovingForward != forward {
            model.isMovingForward = forward
            DispatchQueue.main.async { go(to: target) }
        } else {
            go(to: target)
        }
    }

    private func go(to target: KitoCheckoutStep) {
        var moved = false
        withAnimation(animation) { moved = model.go(to: target) }
        if moved { UISelectionFeedbackGenerator().selectionChanged() }
    }

    private func goBack() {
        guard let previous = model.previousStep else { return }
        move(to: previous)
    }
}

public extension KitoCheckoutFlow where Thumbnail == KitoItemThumbnail {
    /// Uses `KitoItemThumbnail` for item pictures.
    init(
        model: KitoCheckoutModel,
        title: String = "Checkout",
        progressStyle: KitoCheckoutProgressStyle = .dots,
        tint: Color? = nil,
        onClose: (() -> Void)? = nil,
        onAddCard: (() -> Void)? = nil,
        onTrackOrder: ((KitoPlacedOrder) -> Void)? = nil,
        onContinueShopping: (() -> Void)? = nil,
        onPlaceOrder: @escaping (KitoCheckoutOrder) async throws -> KitoPlacedOrder
    ) {
        self.init(model: model, title: title, progressStyle: progressStyle, tint: tint, onClose: onClose, onAddCard: onAddCard,
                  onTrackOrder: onTrackOrder, onContinueShopping: onContinueShopping, onPlaceOrder: onPlaceOrder) { KitoItemThumbnail($0) }
    }
}
