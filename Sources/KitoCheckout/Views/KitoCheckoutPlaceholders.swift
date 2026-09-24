//
//  KitoCheckoutPlaceholders.swift
//  KitoCheckout
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore
import KitoCart

/// The default item picture: the item's image when it has a URL, otherwise a colour tile with
/// its initials. Pass your own thumbnail builder to use your image loader.
public struct KitoItemThumbnail: View {
    let item: KitoCartItem

    public init(_ item: KitoCartItem) {
        self.item = item
    }

    private var hue: Double {
        let sum = item.name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Double(sum % 360) / 360
    }

    private var initials: String {
        let words = item.name.split(separator: " ").prefix(2)
        return words.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    public var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hue: hue, saturation: 0.45, brightness: 0.95), Color(hue: hue, saturation: 0.7, brightness: 0.75)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(initials)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
            if let url = item.imageURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.clear
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// A stand-in map with a dropping pin, for the address form's map slot until you plug in a real
/// map (KitoMaps, MapKit, …).
public struct KitoMapPinPlaceholder: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String?
    let tint: Color?
    @State private var dropped = false

    public init(title: String? = nil, tint: Color? = nil) {
        self.title = title
        self.tint = tint
    }

    private var accent: Color { tint ?? theme.colors.danger }

    public var body: some View {
        ZStack {
            theme.colors.surfaceMuted
            KitoMapStreets(color: theme.colors.border)
            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: dropped ? 70 : 10, height: dropped ? 70 : 10)
                .offset(y: 16)
            pin
            if let title {
                VStack {
                    Spacer()
                    Label(title, systemImage: "mappin.and.ellipse")
                        .font(theme.typography.caption.weight(.semibold))
                        .foregroundStyle(theme.colors.onSurface)
                        .padding(.horizontal, theme.spacing.md)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.regularMaterial))
                        .padding(theme.spacing.sm)
                }
            }
        }
        .clipped()
        .onAppear {
            if reduceMotion { dropped = true } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.15)) { dropped = true }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title.map { "Map pin at \($0)" } ?? "Map pin")
    }

    private var pin: some View {
        VStack(spacing: -4) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 34, weight: .bold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, accent)
                .shadow(color: accent.opacity(0.4), radius: 6, y: 4)
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 10))
                .foregroundStyle(accent)
        }
        .offset(y: dropped ? 0 : -60)
        .opacity(dropped ? 1 : 0)
    }
}

/// A few streets and blocks drawn in the theme's border colour.
struct KitoMapStreets: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let wide = StrokeStyle(lineWidth: 9, lineCap: .round)
        let thin = StrokeStyle(lineWidth: 4, lineCap: .round)
        context.stroke(road(from: CGPoint(x: -10, y: size.height * 0.62), to: CGPoint(x: size.width + 10, y: size.height * 0.38)), with: .color(color), style: wide)
        context.stroke(road(from: CGPoint(x: size.width * 0.3, y: -10), to: CGPoint(x: size.width * 0.42, y: size.height + 10)), with: .color(color), style: wide)
        for fraction in [0.15, 0.7, 0.88] {
            let x = size.width * fraction
            context.stroke(road(from: CGPoint(x: x, y: -10), to: CGPoint(x: x + 20, y: size.height + 10)), with: .color(color.opacity(0.7)), style: thin)
        }
        for fraction in [0.18, 0.85] {
            let y = size.height * fraction
            context.stroke(road(from: CGPoint(x: -10, y: y), to: CGPoint(x: size.width + 10, y: y - 12)), with: .color(color.opacity(0.7)), style: thin)
        }
        let park = CGRect(x: size.width * 0.52, y: size.height * 0.55, width: size.width * 0.14, height: size.height * 0.24)
        context.fill(Path(roundedRect: park, cornerRadius: 8), with: .color(Color.green.opacity(0.18)))
    }

    private func road(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}
