//
//  KitoOrderSuccessView.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import UIKit
import KitoCore
import KitoCart

/// The confirmation: a checkmark that draws itself, a burst of confetti, the order number (tap to
/// copy), the ETA, "Track order", "Continue shopping" and a shareable receipt. With Reduce Motion
/// the checkmark simply appears and there's no confetti.
///
/// ```swift
/// KitoOrderSuccessView(order: placed, onTrackOrder: { showTracking = true }, onContinueShopping: { dismiss() })
/// ```
public struct KitoOrderSuccessView: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let order: KitoPlacedOrder
    let title: String
    let tint: Color?
    let onTrackOrder: (() -> Void)?
    let onContinueShopping: (() -> Void)?

    @State private var drawn = false
    @State private var revealed = false
    @State private var burst = 0
    @State private var copied = false

    public init(
        order: KitoPlacedOrder,
        title: String = "Order placed!",
        tint: Color? = nil,
        onTrackOrder: (() -> Void)? = nil,
        onContinueShopping: (() -> Void)? = nil
    ) {
        self.order = order
        self.title = title
        self.tint = tint
        self.onTrackOrder = onTrackOrder
        self.onContinueShopping = onContinueShopping
    }

    private var accent: Color { tint ?? theme.colors.success }

    public var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: theme.spacing.xl) {
                    KitoSuccessCheckmark(drawn: drawn, color: accent)
                        .padding(.top, theme.spacing.xxl)
                    heading
                    detailsCard
                        .opacity(revealed ? 1 : 0)
                        .offset(y: revealed ? 0 : 24)
                    actions
                        .opacity(revealed ? 1 : 0)
                        .offset(y: revealed ? 0 : 32)
                }
                .padding(.horizontal, theme.spacing.lg)
                .padding(.bottom, theme.spacing.xxl)
            }
            if !reduceMotion {
                KitoConfettiView(trigger: burst, colors: confettiColors)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .background(background.ignoresSafeArea())
        .onAppear(perform: celebrate)
    }

    private var confettiColors: [Color] {
        [accent, theme.colors.warning, theme.colors.primary, theme.colors.danger, theme.colors.secondary]
    }

    private var background: some View {
        ZStack {
            theme.colors.background
            RadialGradient(colors: [accent.opacity(0.18), .clear], center: .top, startRadius: 10, endRadius: 420)
        }
    }

    private var heading: some View {
        VStack(spacing: theme.spacing.sm) {
            Text(title)
                .font(theme.typography.displayMedium)
                .foregroundStyle(theme.colors.onBackground)
                .accessibilityAddTraits(.isHeader)
            if let eta = order.eta {
                Text(eta)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.onBackground.opacity(0.65))
            }
            orderNumberChip
        }
        .multilineTextAlignment(.center)
        .opacity(drawn ? 1 : 0)
        .scaleEffect(drawn || reduceMotion ? 1 : 0.9)
    }

    private var orderNumberChip: some View {
        Button(action: copyNumber) {
            HStack(spacing: 6) {
                Text("Order \(order.number)")
                    .font(.subheadline.weight(.bold).monospaced())
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.caption.weight(.bold))
                    .contentTransition(.symbolEffect(.replace))
            }
            .foregroundStyle(theme.colors.onSurface)
            .padding(.horizontal, theme.spacing.md)
            .padding(.vertical, theme.spacing.sm)
            .background(Capsule().fill(theme.colors.surface))
            .overlay(Capsule().strokeBorder(theme.colors.border, lineWidth: 1))
        }
        .buttonStyle(KitoCheckoutPressStyle())
        .padding(.top, theme.spacing.xs)
        .accessibilityLabel("Order number \(order.number)")
        .accessibilityHint(copied ? "Copied" : "Double tap to copy")
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            if let eta = order.eta {
                detailRow("clock.fill", title: order.deliveryTitle ?? "Delivery", value: eta)
            }
            if let destination = order.destination {
                detailRow("mappin.and.ellipse", title: "Delivering to", value: destination)
            }
            if let payment = order.paymentTitle {
                detailRow("creditcard.fill", title: "Paid with", value: payment)
            }
            KitoDashedDivider(color: theme.colors.border)
            HStack {
                Text(order.items.isEmpty ? "Total" : "Total · \(order.items.reduce(0) { $0 + $1.quantity }) items")
                    .font(theme.typography.label)
                    .foregroundStyle(theme.colors.onSurface.opacity(0.7))
                Spacer()
                Text(KitoCartMoney.string(order.total, currencyCode: order.currencyCode))
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.colors.onSurface)
            }
        }
        .checkoutCard(accent: accent)
    }

    private func detailRow(_ symbol: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            KitoCheckoutIconTile(systemImage: symbol, color: accent, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(theme.typography.caption).foregroundStyle(theme.colors.onSurface.opacity(0.55))
                Text(value).font(theme.typography.label.weight(.semibold)).foregroundStyle(theme.colors.onSurface)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: theme.spacing.md) {
            if let onTrackOrder {
                Button(action: onTrackOrder) {
                    Label("Track order", systemImage: "location.fill")
                }
                .buttonStyle(KitoCheckoutPrimaryButtonStyle(tint: tint))
            }
            if let onContinueShopping {
                Button("Continue shopping", action: onContinueShopping)
                    .buttonStyle(KitoCheckoutSecondaryButtonStyle(tint: tint))
            }
            ShareLink(item: order.receiptText, subject: Text("Receipt for order \(order.number)")) {
                Label("Share receipt", systemImage: "square.and.arrow.up")
                    .font(theme.typography.label.weight(.semibold))
                    .foregroundStyle(theme.colors.onBackground.opacity(0.75))
                    .padding(.vertical, theme.spacing.sm)
            }
        }
    }

    private func celebrate() {
        guard !drawn else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if reduceMotion {
            drawn = true
            revealed = true
            return
        }
        withAnimation(.easeOut(duration: 0.7)) { drawn = true }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.45)) { revealed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { burst += 1 }
    }

    private func copyNumber() {
        UIPasteboard.general.string = order.number
        withAnimation(.snappy) { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation(.snappy) { copied = false } }
    }
}

/// A ring that draws round, fills, then writes a tick.
struct KitoSuccessCheckmark: View {
    let drawn: Bool
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fill = false
    @State private var tick = false

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.12)).scaleEffect(fill ? 1.25 : 0.6)
            Circle()
                .trim(from: 0, to: drawn ? 1 : 0)
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle().fill(color.gradient).scaleEffect(fill ? 1 : 0.001)
            KitoTickShape()
                .trim(from: 0, to: tick ? 1 : 0)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                .frame(width: 46, height: 36)
        }
        .frame(width: 110, height: 110)
        .shadow(color: color.opacity(0.35), radius: fill ? 20 : 0, y: 10)
        .onChange(of: drawn, initial: true) { _, isDrawn in
            guard isDrawn else { return }
            if reduceMotion {
                fill = true
                tick = true
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.55)) { fill = true }
                withAnimation(.easeOut(duration: 0.35).delay(0.8)) { tick = true }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Success")
    }
}

/// Paper pieces shot up from the top centre, falling and spinning under gravity.
struct KitoConfettiView: View {
    let trigger: Int
    let colors: [Color]
    @State private var pieces: [KitoConfettiPiece] = []
    @State private var start: Date?

    private let lifetime: TimeInterval = 3.2

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            Canvas { context, size in
                guard let start else { return }
                let elapsed = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    draw(piece, elapsed: elapsed, in: &context, size: size)
                }
            }
        }
        .onChange(of: trigger) { _, _ in launch() }
    }

    private func launch() {
        var generator = SystemRandomNumberGenerator()
        pieces = (0..<90).map { index in KitoConfettiPiece.random(index: index, colorCount: max(colors.count, 1), using: &generator) }
        start = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + lifetime) { start = nil }
    }

    private func draw(_ piece: KitoConfettiPiece, elapsed: TimeInterval, in context: inout GraphicsContext, size: CGSize) {
        let time = elapsed - piece.delay
        guard time > 0, time < lifetime else { return }
        let point = piece.position(at: time, origin: CGPoint(x: size.width / 2, y: size.height * 0.18))
        let fade = max(0, min(1, (lifetime - time) / 0.8))
        var copy = context
        copy.opacity = fade
        copy.translateBy(x: point.x, y: point.y)
        copy.rotate(by: .degrees(piece.spin * time))
        copy.scaleBy(x: cos(time * piece.flutter), y: 1)
        let rect = CGRect(x: -piece.size.width / 2, y: -piece.size.height / 2, width: piece.size.width, height: piece.size.height)
        let color = colors.isEmpty ? Color.accentColor : colors[piece.colorIndex % colors.count]
        let shape = piece.isCircle ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 1.5)
        copy.fill(shape, with: .color(color))
    }
}

struct KitoConfettiPiece {
    let angle: Double
    let speed: Double
    let spin: Double
    let flutter: Double
    let delay: Double
    let size: CGSize
    let colorIndex: Int
    let isCircle: Bool

    static func random<G: RandomNumberGenerator>(index: Int, colorCount: Int, using generator: inout G) -> KitoConfettiPiece {
        let angle = Double.random(in: -150 ... -30, using: &generator) * .pi / 180
        return KitoConfettiPiece(
            angle: angle,
            speed: Double.random(in: 380...780, using: &generator),
            spin: Double.random(in: -540...540, using: &generator),
            flutter: Double.random(in: 5...12, using: &generator),
            delay: Double.random(in: 0...0.18, using: &generator),
            size: CGSize(width: Double.random(in: 6...10, using: &generator), height: Double.random(in: 8...14, using: &generator)),
            colorIndex: index % colorCount,
            isCircle: index % 5 == 0
        )
    }

    func position(at time: Double, origin: CGPoint) -> CGPoint {
        let drag = 1 / (1 + time * 1.6)
        let x = origin.x + cos(angle) * speed * time * drag
        let rise = sin(angle) * speed * time * drag
        let fall = 0.5 * 620 * time * time
        return CGPoint(x: x, y: origin.y + rise + fall)
    }
}
