//
//  KitoCheckoutExtras.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// "I agree to the Terms" with a checkbox that draws its tick. The text is Markdown, so links work.
///
/// ```swift
/// KitoTermsCheckbox(isOn: $accepted, text: "I agree to the [Terms](https://example.com/terms) and [Privacy Policy](https://example.com/privacy)")
/// ```
public struct KitoTermsCheckbox: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isOn: Bool
    let text: String
    let showsError: Bool
    let tint: Color?

    public init(isOn: Binding<Bool>, text: String = "I agree to the Terms of Service and Privacy Policy", showsError: Bool = false, tint: Color? = nil) {
        _isOn = isOn
        self.text = text
        self.showsError = showsError
        self.tint = tint
    }

    private var accent: Color { theme.checkoutAccent(tint) }

    private var attributed: AttributedString {
        var value = (try? AttributedString(markdown: text)) ?? AttributedString(text)
        for run in value.runs where run.link != nil {
            value[run.range].foregroundColor = accent
            value[run.range].underlineStyle = .single
        }
        return value
    }

    private var plain: String { String(attributed.characters) }

    private var hasLinks: Bool { attributed.runs.contains { $0.link != nil } }

    /// Tapping the words toggles the box, unless they hold links (which must stay tappable).
    @ViewBuilder
    private var label: some View {
        let words = Text(attributed)
            .font(theme.typography.label.weight(.regular))
            .foregroundStyle(theme.colors.onSurface.opacity(0.8))
            .tint(accent)
            .fixedSize(horizontal: false, vertical: true)
        if hasLinks {
            words
        } else {
            words.onTapGesture { isOn.toggle() }
        }
    }

    public var body: some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            Button {
                isOn.toggle()
            } label: {
                KitoCheckbox(isOn: isOn, accent: accent, onAccent: theme.checkoutOnAccent(tint), isError: showsError && !isOn)
            }
            .buttonStyle(.plain)
            label
            Spacer(minLength: 0)
        }
        .accessibilityRepresentation {
            Toggle(plain, isOn: $isOn)
        }
    }
}

struct KitoCheckbox: View {
    let isOn: Bool
    let accent: Color
    let onAccent: Color
    var isError = false
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        ZStack {
            shape.fill(isOn ? accent : theme.colors.surface)
            shape.strokeBorder(isOn ? accent : (isError ? theme.colors.danger : theme.colors.border), lineWidth: 2)
            KitoTickShape()
                .trim(from: 0, to: isOn ? 1 : 0)
                .stroke(onAccent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .padding(6)
        }
        .frame(width: 24, height: 24)
        .scaleEffect(isOn && !reduceMotion ? 1.05 : 1)
        .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.45), value: isOn)
        .animation(.easeOut(duration: 0.2), value: isError)
    }
}

/// A tick drawn left to right, so `trim` animates it being written.
struct KitoTickShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.05))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY - rect.height * 0.08))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.1))
        return path
    }
}

/// "This is a gift" with a note that opens underneath and counts characters.
///
/// ```swift
/// KitoGiftNoteField(isGift: $isGift, note: $note, limit: 150)
/// ```
public struct KitoGiftNoteField: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isGift: Bool
    @Binding var note: String
    let limit: Int
    let prompt: String
    let tint: Color?

    public init(isGift: Binding<Bool>, note: Binding<String>, limit: Int = 150, prompt: String = "Write a short message — we'll print it on a card.", tint: Color? = nil) {
        _isGift = isGift
        _note = note
        self.limit = max(limit, 1)
        self.prompt = prompt
        self.tint = tint
    }

    private var accent: Color { theme.checkoutAccent(tint) }
    private var remaining: Int { limit - note.count }

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Toggle(isOn: $isGift) {
                HStack(spacing: theme.spacing.md) {
                    KitoCheckoutIconTile(systemImage: "gift.fill", color: theme.colors.danger, size: 40, isFilled: isGift)
                        .symbolEffect(.bounce, value: isGift && !reduceMotion)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This is a gift").font(theme.typography.bodyEmphasized.weight(.semibold)).foregroundStyle(theme.colors.onSurface)
                        Text("Prices are left off the receipt in the box").font(theme.typography.caption).foregroundStyle(theme.colors.onSurface.opacity(0.55))
                    }
                }
            }
            .tint(accent)
            if isGift {
                noteEditor
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .checkoutCard(accent: accent)
        .animation(KitoCheckoutMotion.spring(reduceMotion), value: isGift)
    }

    private var noteEditor: some View {
        VStack(alignment: .trailing, spacing: 6) {
            TextField(prompt, text: $note, axis: .vertical)
                .lineLimit(3...6)
                .font(theme.typography.body)
                .padding(theme.spacing.md)
                .background(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).fill(theme.colors.surfaceMuted))
                .onChange(of: note) { _, value in
                    if value.count > limit { note = String(value.prefix(limit)) }
                }
            Text("\(note.count)/\(limit)")
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(remaining < 15 ? theme.colors.warning : theme.colors.onSurface.opacity(0.45))
                .contentTransition(reduceMotion ? .identity : .numericText(value: Double(note.count)))
                .animation(reduceMotion ? nil : .snappy, value: note.count)
                .accessibilityLabel("\(remaining) characters left")
        }
    }
}
