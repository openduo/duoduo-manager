import SwiftUI

struct ConfigContentView: View {
    let config: SystemConfig?

    // UI-only constants (icons/colors belong to the view)
    private static let groupIcons: [String: String] = [
        "network": "network", "sessions": "person.2", "cadence": "clock",
        "transfer": "arrow.left.arrow.right", "logging": "doc.text",
        "sdk": "cpu", "paths": "folder", "subconscious": "brain"
    ]

    private static let groupAccents: [String: Color] = [
        "network": Color(red: 137/255, green: 180/255, blue: 250/255),
        "sessions": Color(red: 166/255, green: 227/255, blue: 161/255),
        "cadence": Color(red: 203/255, green: 166/255, blue: 247/255),
        "transfer": Color(red: 148/255, green: 226/255, blue: 213/255),
        "logging": Color(red: 249/255, green: 226/255, blue: 175/255),
        "sdk": Color(red: 243/255, green: 139/255, blue: 168/255),
        "paths": Color(red: 250/255, green: 179/255, blue: 135/255),
        "subconscious": Color(red: 203/255, green: 166/255, blue: 247/255),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Rectangle().fill(DashboardTheme.border).frame(height: 1)

            if let config {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(ConfigMeta.groupOrder, id: \.self) { group in
                            if let entries = config.entries(for: group) {
                                configCard(group: group, entries: entries)
                            }
                        }
                        if let parts = config.subconscious?.partitions, !parts.isEmpty {
                            subconsciousCard(parts)
                        }
                    }
                    .padding(16)
                }
            } else {
                VStack {
                    Spacer()
                    Text("no config loaded")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(DashboardTheme.textTertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            Text("> ")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(DashboardTheme.accent)
            Text("runtime config")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(DashboardTheme.text)
            Spacer()
            copyButton
        }
    }

    // MARK: - Copy Button

    @State private var copied = false

    private var copyButton: some View {
        Button {
            guard let config else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(config.buildDotEnv(), forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 9))
                Text(copied ? "Copied" : "Copy .env")
                    .font(.system(size: 10, design: .monospaced))
            }
            .foregroundStyle(copied ? DashboardTheme.emerald : DashboardTheme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(DashboardTheme.accent.opacity(copied ? 0.12 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(DashboardTheme.accent.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Card

    private func sectionCard<Content: View>(
        icon: String, label: String, accent: Color, badge: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(accent)
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent)
                    .textCase(.uppercase)
                Spacer()
                Text(badge)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(DashboardTheme.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Rectangle().fill(DashboardTheme.border.opacity(0.4)).frame(height: 1)
                .padding(.horizontal, 12)

            content()
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(DashboardTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DashboardTheme.border, lineWidth: 1)
                )
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(accent.opacity(0.6))
                .frame(width: 2)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 8))
        }
    }

    private func configCard(group: String, entries: [String: ConfigEntry]) -> some View {
        let accent = Self.groupAccents[group] ?? DashboardTheme.textSecondary
        return sectionCard(
            icon: Self.groupIcons[group] ?? "gearshape",
            label: ConfigMeta.groupLabels[group] ?? group,
            accent: accent,
            badge: "\(entries.count) keys"
        ) {
            VStack(spacing: 0) {
                ForEach(Array(entries.keys.sorted()), id: \.self) { key in
                    if let entry = entries[key] {
                        configRow(key: key, entry: entry)
                    }
                }
            }
        }
    }

    private func subconsciousCard(_ partitions: [PartitionConfig]) -> some View {
        let accent = Self.groupAccents["subconscious"] ?? DashboardTheme.fuchsia
        let enabled = partitions.filter(\.enabled).count
        return sectionCard(
            icon: "brain",
            label: "Subconscious",
            accent: accent,
            badge: "\(enabled)/\(partitions.count) active"
        ) {
            VStack(spacing: 4) {
                ForEach(partitions) { p in
                    partitionRow(p)
                }
            }
        }
    }

    // MARK: - Row Views

    private func configRow(key: String, entry: ConfigEntry) -> some View {
        let displayVal: String = {
            guard entry.source != "unset" else { return "-" }
            if ConfigMeta.msKeys.contains(key), let val = entry.value, let ms = Double(val) {
                return DashboardTheme.formatDuration(ms)
            }
            return entry.value ?? "-"
        }()

        let sourceColor: Color = switch entry.source {
        case "env": DashboardTheme.accent
        case "settings": DashboardTheme.amber
        default: DashboardTheme.text
        }

        let sourceBadge: String? = switch entry.source {
        case "env": "env"
        case "settings": "set"
        case "unset": nil
        default: entry.source
        }

        return HStack(spacing: 0) {
            Text(key)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DashboardTheme.textSecondary)
                .frame(width: 160, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(displayVal)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(sourceColor)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            Spacer(minLength: 0)

            if let badge = sourceBadge {
                Text(badge)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(sourceColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(sourceColor.opacity(0.1))
                    )
            }
        }
        .padding(.vertical, 3)
    }

    private func partitionRow(_ p: PartitionConfig) -> some View {
        let cooldown = p.cooldown_ticks ?? 0
        let timeout = DashboardTheme.formatDuration(Double(p.max_duration_ms ?? 0))

        return HStack(spacing: 0) {
            Circle()
                .fill(p.enabled ? DashboardTheme.emerald : DashboardTheme.textTertiary.opacity(0.4))
                .frame(width: 5, height: 5)

            Text(p.name)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(p.enabled ? DashboardTheme.text : DashboardTheme.textTertiary)
                .padding(.leading, 6)

            Spacer()

            if cooldown > 0 {
                Text("cd:\(cooldown)t")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(DashboardTheme.textTertiary)
                    .padding(.trailing, 8)
            }

            Text(timeout)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(DashboardTheme.textTertiary)
        }
        .padding(.vertical, 2)
    }
}
