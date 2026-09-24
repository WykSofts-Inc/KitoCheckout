//
//  KitoCheckoutProgressHeader.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// Shows where the customer is in the checkout: numbered dots, a segmented bar or "Step 2 of 4".
///
/// ```swift
/// KitoCheckoutProgressHeader(steps: KitoCheckoutStep.standard, current: .payment, style: .dots)
/// ```
public struct KitoCheckoutProgressHeader: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let steps: [KitoCheckoutStep]
    let current: KitoCheckoutStep
    let style: KitoCheckoutProgressStyle
    let tint: Color?
    let onSelect: ((KitoCheckoutStep) -> Void)?

    /// - Parameter onSelect: Called when a finished step is tapped, to go back to it.
    public init(steps: [KitoCheckoutStep] = KitoCheckoutStep.standard, current: KitoCheckoutStep, style: KitoCheckoutProgressStyle = .dots, tint: Color? = nil, onSelect: ((KitoCheckoutStep) -> Void)? = nil) {
        self.steps = steps.filter { $0 != .done }
        self.current = current
        self.style = style
        self.tint = tint
        self.onSelect = onSelect
    }

    private var accent: Color { theme.checkoutAccent(tint) }
    private var index: Int { steps.firstIndex(of: current) ?? steps.count }
    private var position: Int { min(index + 1, steps.count) }
    private var fraction: CGFloat { steps.isEmpty ? 0 : CGFloat(position) / CGFloat(steps.count) }
    private var animation: Animation? { KitoCheckoutMotion.spring(reduceMotion) }

    public var body: some View {
        Group {
            switch style {
            case .dots: dots
            case .segmented: segmented
            case .text: textStyle
            }
        }
        .animation(animation, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(position) of \(steps.count), \(current.title)")
    }

    // MARK: Dots

    private var dots: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element) { offset, step in
                dot(step, offset: offset)
                if offset < steps.count - 1 {
                    connector(filled: offset < index)
                        .padding(.top, 13)
                }
            }
        }
    }

    private func dot(_ step: KitoCheckoutStep, offset: Int) -> some View {
        let done = offset < index
        let active = offset == index
        return Button {
            if done { onSelect?(step) }
        } label: {
            VStack(spacing: 6) {
                KitoProgressDot(number: offset + 1, isDone: done, isActive: active, accent: accent, onAccent: theme.checkoutOnAccent(tint))
                Text(step.title)
                    .font(.caption2.weight(active ? .bold : .medium))
                    .foregroundStyle(theme.colors.onBackground.opacity(active || done ? 0.9 : 0.45))
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(width: 56)
        }
        .buttonStyle(.plain)
        .disabled(!done || onSelect == nil)
    }

    private func connector(filled: Bool) -> some View {
        ZStack(alignment: .leading) {
            Capsule().fill(theme.colors.border.opacity(0.6))
            Capsule().fill(accent)
                .scaleEffect(x: filled ? 1 : 0.001, anchor: .leading)
        }
        .frame(height: 3)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, -10)
    }

    // MARK: Segmented

    private var segmented: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            HStack(spacing: 6) {
                ForEach(Array(steps.enumerated()), id: \.element) { offset, _ in
                    segment(offset)
                }
            }
            HStack {
                Label(current.title, systemImage: current.systemImage)
                    .font(theme.typography.label)
                    .foregroundStyle(theme.colors.onBackground)
                    .contentTransition(.opacity)
                Spacer()
                Text("\(position)/\(steps.count)")
                    .font(theme.typography.caption.monospacedDigit())
                    .foregroundStyle(theme.colors.onBackground.opacity(0.5))
                    .contentTransition(reduceMotion ? .identity : .numericText(value: Double(position)))
            }
        }
    }

    private func segment(_ offset: Int) -> some View {
        let filled = offset <= index
        return ZStack(alignment: .leading) {
            Capsule().fill(theme.colors.border.opacity(0.6))
            Capsule().fill(accent.gradient)
                .scaleEffect(x: filled ? 1 : 0.001, anchor: .leading)
                .opacity(offset == index ? 1 : 0.85)
        }
        .frame(height: 6)
    }

    // MARK: Text

    private var textStyle: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("STEP \(position) OF \(steps.count)")
                        .font(.caption2.weight(.heavy))
                        .tracking(1)
                        .foregroundStyle(accent.opacity(0.8))
                    Text(current.title)
                        .font(theme.typography.titleLarge)
                        .foregroundStyle(theme.colors.onBackground)
                        .id(current)
                        .transition(.push(from: .trailing).combined(with: .opacity))
                }
                Spacer()
                if let next = nextTitle {
                    Text("Next: \(next)")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.onBackground.opacity(0.5))
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.colors.border.opacity(0.6))
                    Capsule().fill(accent.gradient).frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 4)
        }
    }

    private var nextTitle: String? {
        index + 1 < steps.count ? steps[index + 1].title : nil
    }
}

/// One numbered dot: a number, a filled current dot with a halo, or a tick when finished.
struct KitoProgressDot: View {
    let number: Int
    let isDone: Bool
    let isActive: Bool
    let accent: Color
    let onAccent: Color
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var filled: Bool { isDone || isActive }

    var body: some View {
        ZStack {
            if isActive && !reduceMotion {
                Circle()
                    .stroke(accent.opacity(0.35), lineWidth: 2)
                    .scaleEffect(pulse ? 1.55 : 1)
                    .opacity(pulse ? 0 : 1)
                    .onAppear { withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true } }
                    .onDisappear { pulse = false }
            }
            Circle()
                .fill(filled ? AnyShapeStyle(accent.gradient) : AnyShapeStyle(theme.colors.surfaceMuted))
            Circle().strokeBorder(filled ? Color.clear : theme.colors.border, lineWidth: 1)
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(onAccent)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text("\(number)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive ? onAccent : theme.colors.onBackground.opacity(0.5))
            }
        }
        .frame(width: 28, height: 28)
        .scaleEffect(isActive ? 1.08 : 1)
    }
}
