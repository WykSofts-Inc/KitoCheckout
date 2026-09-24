//
//  KitoAddressForm.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import UIKit
import KitoCore

/// Adds or edits an address: a map slot, Home/Work/Other, name and phone, county and town
/// pickers with all 47 counties, street, building, landmark, rider note and "set as default".
public struct KitoAddressForm<Map: View>: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tint: Color?
    let isNew: Bool
    let onCancel: () -> Void
    let onSave: (KitoAddress) -> Void
    let map: (KitoAddress) -> Map

    @State private var draft: KitoAddress
    @State private var customLabel: String
    @State private var showsErrors = false
    @State private var shakes = 0
    @FocusState private var focus: KitoAddressFormField?

    public init(
        address: KitoAddress? = nil,
        tint: Color? = nil,
        onCancel: @escaping () -> Void,
        onSave: @escaping (KitoAddress) -> Void,
        @ViewBuilder map: @escaping (KitoAddress) -> Map
    ) {
        let start = address ?? KitoAddress(county: "Nairobi")
        _draft = State(initialValue: start)
        if case .other(let name) = start.label { _customLabel = State(initialValue: name) } else { _customLabel = State(initialValue: "") }
        self.isNew = address.map { address in address.recipient.isEmpty && address.street.isEmpty } ?? true
        self.tint = tint
        self.onCancel = onCancel
        self.onSave = onSave
        self.map = map
    }

    private var accent: Color { theme.checkoutAccent(tint) }
    private var errors: [KitoAddressField: String] { showsErrors ? draft.validationErrors() : [:] }
    private var towns: [String] { KitoKenya.towns(in: draft.county) }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.xl) {
                    map(draft)
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous).strokeBorder(theme.colors.border, lineWidth: 1))
                    labelPicker
                    contactFields
                    locationFields
                    extraFields
                    defaultToggle
                }
                .padding(theme.spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle(isNew ? "New address" : "Edit address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).fontWeight(.bold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: save) { Text("Save address") }
                    .buttonStyle(KitoCheckoutPrimaryButtonStyle(tint: tint))
                    .modifier(KitoShakeEffect(shakes: CGFloat(shakes)))
                    .padding(.horizontal, theme.spacing.lg)
                    .padding(.bottom, theme.spacing.sm)
            }
        }
        .tint(accent)
    }

    // MARK: Sections

    private var labelPicker: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            fieldTitle("Save as")
            HStack(spacing: theme.spacing.sm) {
                labelChip(.home)
                labelChip(.work)
                labelChip(.other(customLabel))
            }
            if case .other = draft.label {
                KitoCheckoutTextField(title: "Label", text: $customLabel, prompt: "e.g. Mum's place", focus: $focus, field: .label)
                    .onChange(of: customLabel) { _, name in draft.label = .other(name) }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(KitoCheckoutMotion.spring(reduceMotion), value: draft.label)
    }

    private func labelChip(_ label: KitoAddressLabel) -> some View {
        let selected = sameKind(draft.label, label)
        return Button {
            draft.label = label
        } label: {
            Label(kindTitle(label), systemImage: label.systemImage)
                .font(theme.typography.label)
                .padding(.horizontal, theme.spacing.md)
                .padding(.vertical, theme.spacing.sm)
                .foregroundStyle(selected ? theme.checkoutOnAccent(tint) : theme.colors.onSurface)
                .background(Capsule().fill(selected ? accent : theme.colors.surface))
                .overlay(Capsule().strokeBorder(selected ? Color.clear : theme.colors.border, lineWidth: 1))
        }
        .buttonStyle(KitoCheckoutPressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var contactFields: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            fieldTitle("Contact")
            KitoCheckoutTextField(title: "Full name", text: $draft.recipient, prompt: "Who's receiving it?", error: errors[.recipient],
                                  contentType: .name, focus: $focus, field: .recipient)
            KitoCheckoutTextField(title: "Phone number", text: $draft.phone, prompt: "0712 345 678", error: errors[.phone],
                                  keyboard: .phonePad, contentType: .telephoneNumber, focus: $focus, field: .phone)
        }
    }

    private var locationFields: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            fieldTitle("Location")
            HStack(alignment: .top, spacing: theme.spacing.md) {
                KitoCheckoutMenuField(title: "County", value: draft.county, placeholder: "Choose", options: KitoKenya.sortedCounties.map(\.name), error: errors[.county]) { county in
                    draft.county = county
                    if !KitoKenya.towns(in: county).contains(draft.town) { draft.town = "" }
                }
                KitoCheckoutMenuField(title: "Town or area", value: draft.town, placeholder: "Choose", options: towns, error: errors[.town]) { town in
                    draft.town = town
                }
            }
            KitoCheckoutTextField(title: "Estate or neighbourhood", text: $draft.area, prompt: "e.g. Riverside Drive estate", focus: $focus, field: .area)
            KitoCheckoutTextField(title: "Street or road", text: $draft.street, prompt: "e.g. Argwings Kodhek Road", error: errors[.street],
                                  contentType: .streetAddressLine1, focus: $focus, field: .street)
            KitoCheckoutTextField(title: "Building, floor, door", text: $draft.building, prompt: "e.g. Mvuli Court, Block B, 4th floor",
                                  contentType: .streetAddressLine2, focus: $focus, field: .building)
        }
    }

    private var extraFields: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            fieldTitle("For the rider")
            KitoCheckoutTextField(title: "Landmark", text: $draft.landmark, prompt: "e.g. Opposite the petrol station", focus: $focus, field: .landmark)
            KitoCheckoutTextField(title: "Delivery instructions", text: $draft.instructions, prompt: "e.g. Call when you reach the gate", focus: $focus, field: .instructions)
        }
    }

    private var defaultToggle: some View {
        Toggle(isOn: $draft.isDefault) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Set as default").font(theme.typography.bodyEmphasized).foregroundStyle(theme.colors.onSurface)
                Text("Used first next time you check out").font(theme.typography.caption).foregroundStyle(theme.colors.onSurface.opacity(0.55))
            }
        }
        .tint(accent)
        .checkoutCard(accent: accent, padding: theme.spacing.md)
    }

    private func fieldTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.heavy))
            .tracking(0.8)
            .foregroundStyle(theme.colors.onBackground.opacity(0.5))
    }

    // MARK: Saving

    private func save() {
        var address = draft
        if case .other = address.label { address.label = .other(customLabel) }
        if address.isValid {
            onSave(address)
        } else {
            withAnimation(KitoCheckoutMotion.spring(reduceMotion)) { showsErrors = true }
            if !reduceMotion { withAnimation(.linear(duration: 0.4)) { shakes += 1 } }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            focus = firstInvalidField(address)
        }
    }

    private func firstInvalidField(_ address: KitoAddress) -> KitoAddressFormField? {
        let errors = address.validationErrors()
        if errors[.recipient] != nil { return .recipient }
        if errors[.phone] != nil { return .phone }
        if errors[.street] != nil { return .street }
        return nil
    }

    private func sameKind(_ lhs: KitoAddressLabel, _ rhs: KitoAddressLabel) -> Bool {
        switch (lhs, rhs) {
        case (.home, .home), (.work, .work), (.other, .other): return true
        default: return false
        }
    }

    private func kindTitle(_ label: KitoAddressLabel) -> String {
        if case .other = label { return "Other" }
        return label.title
    }
}

public extension KitoAddressForm where Map == KitoMapPinPlaceholder {
    init(address: KitoAddress? = nil, tint: Color? = nil, onCancel: @escaping () -> Void, onSave: @escaping (KitoAddress) -> Void) {
        self.init(address: address, tint: tint, onCancel: onCancel, onSave: onSave) { address in
            KitoMapPinPlaceholder(title: address.formatted(.short).isEmpty ? nil : address.formatted(.short), tint: tint)
        }
    }
}

enum KitoAddressFormField: Hashable {
    case label, recipient, phone, area, street, building, landmark, instructions
}

/// A labelled field with a focus ring and an error line.
struct KitoCheckoutTextField: View {
    let title: String
    @Binding var text: String
    var prompt: String = ""
    var error: String?
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType?
    var focus: FocusState<KitoAddressFormField?>.Binding
    let field: KitoAddressFormField
    @Environment(\.kitoTheme) private var theme

    private var isFocused: Bool { focus.wrappedValue == field }

    private var borderColor: Color {
        if error != nil { return theme.colors.danger }
        return isFocused ? theme.colors.onBackground : theme.colors.border
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(error == nil ? theme.colors.onBackground.opacity(0.65) : theme.colors.danger)
            TextField(prompt, text: $text)
                .font(theme.typography.body)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .focused(focus, equals: field)
                .padding(.horizontal, theme.spacing.md)
                .frame(minHeight: 48)
                .background(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).fill(theme.colors.surface))
                .overlay(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).strokeBorder(borderColor, lineWidth: isFocused || error != nil ? 1.5 : 1))
                .animation(.easeOut(duration: 0.18), value: isFocused)
            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.danger)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// A labelled menu picker for county and town.
struct KitoCheckoutMenuField: View {
    let title: String
    let value: String
    let placeholder: String
    let options: [String]
    var error: String?
    let onSelect: (String) -> Void
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(error == nil ? theme.colors.onBackground.opacity(0.65) : theme.colors.danger)
            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        if option == value { Label(option, systemImage: "checkmark") } else { Text(option) }
                    }
                }
            } label: {
                HStack {
                    Text(value.isEmpty ? placeholder : value)
                        .font(theme.typography.body)
                        .foregroundStyle(value.isEmpty ? theme.colors.onSurface.opacity(0.4) : theme.colors.onSurface)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.colors.onSurface.opacity(0.4))
                }
                .padding(.horizontal, theme.spacing.md)
                .frame(minHeight: 48)
                .background(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).fill(theme.colors.surface))
                .overlay(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).strokeBorder(error == nil ? theme.colors.border : theme.colors.danger, lineWidth: 1))
            }
            .disabled(options.isEmpty)
            if let error {
                Text(error).font(theme.typography.caption).foregroundStyle(theme.colors.danger)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(title)
        .accessibilityValue(value.isEmpty ? "Not chosen" : value)
    }
}

/// A horizontal shake for a rejected save.
struct KitoShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(shakes * .pi * 4), y: 0))
    }
}
