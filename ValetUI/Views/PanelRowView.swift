import SwiftUI

// MARK: - PanelRow

struct PanelRow: View {
    let icon: String
    let label: String
    var trailingText: String? = nil
    var showChevron: Bool = false
    var isDestructive: Bool = false
    var isDisabled: Bool = false
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 16)
                    .foregroundStyle(isDestructive ? .red : .primary)

                Text(label)
                    .font(.body)
                    .foregroundStyle(isDestructive ? .red : .primary)
                    .lineLimit(1)

                Spacer()

                if let trailing = trailingText {
                    Text(trailing)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 36)
            .contentShape(Rectangle())
            .background(
                isHovered && !isDisabled
                    ? Color.primary.opacity(0.08)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { isHovered = $0 }
    }
}

// MARK: - PanelRow with custom icon (NSImage)

struct PanelRowCustomIcon: View {
    let image: NSImage
    let label: String
    var showChevron: Bool = false
    var isDisabled: Bool = false
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(nsImage: image)
                    .frame(width: 16, height: 16)
                    .opacity(isDisabled ? 0.4 : 1.0)

                Text(label)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 36)
            .contentShape(Rectangle())
            .background(
                isHovered && !isDisabled
                    ? Color.primary.opacity(0.08)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { isHovered = $0 }
    }
}

// MARK: - PanelSectionHeader

struct PanelSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }
}

// MARK: - PanelDivider

struct PanelDivider: View {
    var body: some View {
        Divider()
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
    }
}
