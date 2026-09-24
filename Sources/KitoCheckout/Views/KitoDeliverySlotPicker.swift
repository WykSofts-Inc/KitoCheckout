//
//  KitoDeliverySlotPicker.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// Day chips, then the day's time windows. Full, closed and past windows are shown but can't be
/// chosen; windows with only a few places left say so.
///
/// ```swift
/// let schedule = KitoDeliverySchedule(rules: KitoSlotRules(sameDayCutoffMinutes: 17 * 60, closedWeekdays: [1]),
///                                     booked: ["2026-09-25-1000": 6])
/// KitoDeliverySlotPicker(schedule: schedule, selection: $slot)
/// ```
public struct KitoDeliverySlotPicker: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let schedule: KitoDeliverySchedule
    @Binding var selection: KitoDeliverySlot?
    let now: Date
    let timeStyle: KitoTimeWindow.Style
    let tint: Color?

    @State private var selectedDay: Date?
    @Namespace private var dayNamespace

    public init(schedule: KitoDeliverySchedule, selection: Binding<KitoDeliverySlot?>, now: Date = Date(), timeStyle: KitoTimeWindow.Style = .twelveHour, tint: Color? = nil) {
        self.schedule = schedule
        _selection = selection
        self.now = now
        self.timeStyle = timeStyle
        self.tint = tint
    }

    private var accent: Color { theme.checkoutAccent(tint) }
    private var days: [KitoDeliveryDay] { schedule.days(from: now) }

    private var activeDay: KitoDeliveryDay? {
        let calendar = schedule.rules.calendar
        if let selectedDay, let day = days.first(where: { calendar.isDate($0.date, inSameDayAs: selectedDay) }) { return day }
        if let selection, let day = days.first(where: { calendar.isDate($0.date, inSameDayAs: selection.start) }) { return day }
        return days.first { schedule.openSlotCount(on: $0, now: now) > 0 } ?? days.first
    }

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.lg) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacing.sm) {
                    ForEach(days) { day in
                        dayChip(day)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
            if let day = activeDay {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(day.slots) { slot in
                        slotButton(slot)
                    }
                }
                .id(day.id)
                .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        .animation(KitoCheckoutMotion.spring(reduceMotion), value: activeDay?.id)
        .animation(KitoCheckoutMotion.spring(reduceMotion), value: selection?.id)
    }

    // MARK: Days

    private func dayChip(_ day: KitoDeliveryDay) -> some View {
        let isActive = day.id == activeDay?.id
        let open = schedule.openSlotCount(on: day, now: now)
        let calendar = schedule.rules.calendar
        return Button {
            selectedDay = day.date
        } label: {
            VStack(spacing: 2) {
                Text(schedule.dayTitle(for: day.date, now: now))
                    .font(.caption.weight(.semibold))
                Text("\(calendar.component(.day, from: day.date))")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                Text(open == 0 ? "Full" : "\(open) open")
                    .font(.caption2.weight(.medium))
                    .opacity(0.75)
            }
            .foregroundStyle(isActive ? theme.checkoutOnAccent(tint) : theme.colors.onSurface.opacity(open == 0 ? 0.4 : 1))
            .frame(width: 70, height: 78)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous)
                        .fill(theme.colors.surface)
                        .overlay(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).strokeBorder(theme.colors.border, lineWidth: 1))
                    if isActive {
                        RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous)
                            .fill(accent.gradient)
                            .shadow(color: accent.opacity(0.3), radius: 8, y: 4)
                            .matchedGeometryEffect(id: "day", in: dayNamespace)
                    }
                }
            }
        }
        .buttonStyle(KitoCheckoutPressStyle())
        .accessibilityLabel("\(schedule.dayTitle(for: day.date, now: now)) \(calendar.component(.day, from: day.date)), \(open) slots open")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    // MARK: Slots

    private func slotButton(_ slot: KitoDeliverySlot) -> some View {
        let availability = schedule.availability(of: slot, now: now)
        let selected = slot.id == selection?.id
        return Button {
            selection = slot
        } label: {
            KitoSlotCell(label: slot.window.label(timeStyle), availability: availability, isSelected: selected, accent: accent, onAccent: theme.checkoutOnAccent(tint))
        }
        .buttonStyle(KitoCheckoutPressStyle())
        .disabled(!availability.isSelectable)
        .accessibilityLabel(slot.window.label(timeStyle))
        .accessibilityValue(availability.label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct KitoSlotCell: View {
    let label: String
    let availability: KitoSlotAvailability
    let isSelected: Bool
    let accent: Color
    let onAccent: Color
    @Environment(\.kitoTheme) private var theme

    private var statusColor: Color {
        if isSelected { return onAccent.opacity(0.8) }
        switch availability {
        case .available: return theme.colors.success
        case .fewLeft: return theme.colors.warning
        case .full, .cutOff, .past: return theme.colors.onSurface.opacity(0.4)
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(theme.typography.label.weight(.bold))
                    .strikethrough(!availability.isSelectable)
                    .foregroundStyle(isSelected ? onAccent : theme.colors.onSurface.opacity(availability.isSelectable ? 1 : 0.4))
                HStack(spacing: 4) {
                    Circle().fill(statusColor).frame(width: 6, height: 6)
                    Text(availability.label).font(.caption2.weight(.semibold)).foregroundStyle(statusColor)
                }
            }
            Spacer(minLength: 0)
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(onAccent)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, 10)
        .background(shape.fill(isSelected ? AnyShapeStyle(accent.gradient) : AnyShapeStyle(availability.isSelectable ? theme.colors.surface : theme.colors.surfaceMuted)))
        .overlay(shape.strokeBorder(isSelected ? Color.clear : theme.colors.border, style: StrokeStyle(lineWidth: 1, dash: availability.isSelectable ? [] : [4, 3])))
        .shadow(color: isSelected ? accent.opacity(0.25) : .clear, radius: 8, y: 4)
    }
}
