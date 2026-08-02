import SwiftUI

/// Identification badge for a bottle: the wine color when there is one, otherwise the
/// beverage type icon (beer, spirit, sake...).
struct BeverageBadge: View {
    let beverageType: BeverageType
    let color: WineColor?

    var body: some View {
        if let color {
            WineColorBadge(color: color)
        } else {
            // Non-wine beverages: the type's first letter rather than an icon.
            Text(beverageType.initial)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 14, height: 14)
                .background(Circle().fill(beverageType.displayColor))
                .overlay(Circle().stroke(.primary.opacity(0.15), lineWidth: 0.5))
                .accessibilityLabel(beverageType.label)
        }
    }
}

#Preview("Wine and other beverages") {
    HStack(spacing: 12) {
        BeverageBadge(beverageType: .wine, color: .red)
        ForEach([BeverageType.spirit, .beer, .sake, .cider, .other]) { type in
            VStack {
                BeverageBadge(beverageType: type, color: nil)
                Text(type.label)
                    .font(.caption2)
            }
        }
    }
    .padding()
}
