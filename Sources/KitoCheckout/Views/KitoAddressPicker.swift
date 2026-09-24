//
//  KitoAddressPicker.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// Saved addresses to choose from, with Home/Work labels, a default badge and an "Add new
/// address" form. Long-press an address to edit it, make it the default or delete it.
///
/// ```swift
/// KitoAddressPicker(addresses: $addresses, selection: $selectedID)
/// KitoAddressPicker(addresses: $addresses, selection: $selectedID) { address in
///     MyMapView(coordinate: address.coordinate)      // your map in the form's map slot
/// }
/// ```
public struct KitoAddressPicker<Map: View>: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var addresses: [KitoAddress]
    @Binding var selection: KitoAddress.ID?
    let tint: Color?
    let allowsAdding: Bool
    let map: (KitoAddress) -> Map

    @State private var editing: KitoAddress?

    public init(
        addresses: Binding<[KitoAddress]>,
        selection: Binding<KitoAddress.ID?>,
        tint: Color? = nil,
        allowsAdding: Bool = true,
        @ViewBuilder map: @escaping (KitoAddress) -> Map
    ) {
        _addresses = addresses
        _selection = selection
        self.tint = tint
        self.allowsAdding = allowsAdding
        self.map = map
    }

    private var accent: Color { theme.checkoutAccent(tint) }

    public var body: some View {
        VStack(spacing: theme.spacing.md) {
            ForEach(addresses) { address in
                row(address)
                    .transition(.asymmetric(insertion: .scale(scale: 0.94).combined(with: .opacity), removal: .opacity))
            }
            if allowsAdding {
                addButton
            }
        }
        .animation(KitoCheckoutMotion.spring(reduceMotion), value: addresses)
        .sheet(item: $editing) { address in
            KitoAddressForm(address: address, tint: tint, onCancel: { editing = nil }, onSave: save, map: map)
        }
    }

    private func row(_ address: KitoAddress) -> some View {
        let selected = address.id == selection
        return Button {
            selection = address.id
        } label: {
            KitoAddressRow(address: address, isSelected: selected, accent: accent, onAccent: theme.checkoutOnAccent(tint))
                .checkoutCard(selected: selected, accent: accent)
        }
        .buttonStyle(KitoCheckoutPressStyle())
        .contextMenu {
            Button { editing = address } label: { Label("Edit", systemImage: "pencil") }
            if !address.isDefault {
                Button { makeDefault(address.id) } label: { Label("Set as default", systemImage: "star") }
            }
            Button(role: .destructive) { remove(address.id) } label: { Label("Delete", systemImage: "trash") }
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityAction(named: "Edit") { editing = address }
    }

    private var addButton: some View {
        Button {
            editing = KitoAddress(label: addresses.isEmpty ? .home : .work, county: "Nairobi", isDefault: addresses.isEmpty)
        } label: {
            HStack(spacing: theme.spacing.md) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(accent.opacity(0.1)))
                Text("Add new address")
                    .font(theme.typography.bodyEmphasized)
                Spacer()
                Image(systemName: "chevron.forward").font(.caption.weight(.bold)).opacity(0.4)
            }
            .foregroundStyle(accent)
            .padding(theme.spacing.md)
            .background(
                RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    .foregroundStyle(theme.colors.border)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(KitoCheckoutPressStyle())
    }

    private func save(_ address: KitoAddress) {
        var list = addresses
        if address.isDefault {
            for index in list.indices { list[index].isDefault = false }
        }
        if let index = list.firstIndex(where: { $0.id == address.id }) {
            list[index] = address
        } else {
            list.append(address)
        }
        addresses = list
        selection = address.id
        editing = nil
    }

    private func makeDefault(_ id: KitoAddress.ID) {
        var list = addresses
        for index in list.indices { list[index].isDefault = list[index].id == id }
        addresses = list
    }

    private func remove(_ id: KitoAddress.ID) {
        addresses.removeAll { $0.id == id }
        if selection == id { selection = (addresses.first { $0.isDefault } ?? addresses.first)?.id }
    }
}

public extension KitoAddressPicker where Map == KitoMapPinPlaceholder {
    /// Uses `KitoMapPinPlaceholder` in the form's map slot.
    init(addresses: Binding<[KitoAddress]>, selection: Binding<KitoAddress.ID?>, tint: Color? = nil, allowsAdding: Bool = true) {
        self.init(addresses: addresses, selection: selection, tint: tint, allowsAdding: allowsAdding) { address in
            KitoMapPinPlaceholder(title: address.formatted(.short).isEmpty ? nil : address.formatted(.short), tint: tint)
        }
    }
}

/// One saved address: label tile, name, default badge, the address and the rider's note.
struct KitoAddressRow: View {
    let address: KitoAddress
    let isSelected: Bool
    let accent: Color
    let onAccent: Color
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            KitoCheckoutIconTile(systemImage: address.label.systemImage, color: accent, size: 42, isFilled: isSelected)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: theme.spacing.sm) {
                    Text(address.label.title)
                        .font(theme.typography.bodyEmphasized.weight(.bold))
                        .foregroundStyle(theme.colors.onSurface)
                    if address.isDefault {
                        KitoCheckoutBadge(text: "Default", color: theme.colors.success)
                    }
                }
                Text(address.formatted(.singleLine))
                    .font(theme.typography.label.weight(.regular))
                    .foregroundStyle(theme.colors.onSurface.opacity(0.75))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                detailLine
            }
            Spacer(minLength: theme.spacing.sm)
            KitoCheckoutRadio(isSelected: isSelected, accent: accent, onAccent: onAccent)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var detailLine: some View {
        let phone = KitoKenyanPhone.display(address.phone) ?? address.phone
        let person = [address.recipient, phone].filter { !$0.isEmpty }.joined(separator: " · ")
        if !person.isEmpty {
            Label(person, systemImage: "person.fill")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.onSurface.opacity(0.55))
                .labelStyle(KitoCompactLabelStyle())
        }
        if !address.landmark.isEmpty {
            Label("Near \(address.landmark)", systemImage: "signpost.right.fill")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.onSurface.opacity(0.55))
                .labelStyle(KitoCompactLabelStyle())
        }
    }
}

struct KitoCompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.font(.system(size: 9, weight: .bold))
            configuration.title
        }
    }
}
