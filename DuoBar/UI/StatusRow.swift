import SwiftUI

struct StatusRow: View {
    enum Accessory {
        case none
        case disclosure
        case menu
    }

    let symbol: String
    let title: String
    let detail: String
    let stateText: String
    let tint: Color
    var accessory: Accessory = .none
    let trailing: AnyView?

    init(
        symbol: String,
        title: String,
        detail: String,
        stateText: String,
        tint: Color,
        accessory: Accessory = .none,
        trailing: AnyView? = nil
    ) {
        self.symbol = symbol
        self.title = title
        self.detail = detail
        self.stateText = stateText
        self.tint = tint
        self.accessory = accessory
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Spacer(minLength: 8)

            if let trailing {
                trailing
            } else {
                Text(stateText)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .layoutPriority(0)

                if let accessorySymbol {
                    Image(systemName: accessorySymbol)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 48)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var accessorySymbol: String? {
        switch accessory {
        case .none: nil
        case .disclosure: "chevron.right"
        case .menu: "chevron.up.chevron.down"
        }
    }
}
