import SwiftUI

struct ConfigContentView: View {
    let config: SystemConfig?

    // UI-only constants (icons belong to the view; colour does not — the
    // panel header is a neutral mono kicker)
    private static let groupIcons: [String: String] = [
        "network": "network", "sessions": "person.2", "cadence": "clock",
        "transfer": "arrow.left.arrow.right", "logging": "doc.text",
        "sdk": "cpu", "paths": "folder", "subconscious": "brain"
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Rectangle().fill(OpenDuo.borderHairline).frame(height: 1)

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
                        .font(.odMono(11))
                        .foregroundStyle(OpenDuo.textMuted)
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
            ODKicker(text: L10n.Dashboard.configTitle, tint: OpenDuo.textKicker)
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
                    .font(.system(size: 10, weight: .medium))
            }
        }
        .buttonStyle(ODOutlineButtonStyle(tint: copied ? OpenDuo.ok : OpenDuo.textAccentSoft))
    }

    // MARK: - Card
    //
    // A hairline panel with a mono header bar. No per-group accent colour:
    // hierarchy is structural, not chromatic.

    private func sectionCard<Content: View>(
        icon: String, label: String, badge: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            ODPanelHeader(
                title: label,
                trailing: AnyView(
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.system(size: 9))
                            .foregroundStyle(OpenDuo.textFaint)
                        Text(badge)
                            .font(.odMono(9))
                            .foregroundStyle(OpenDuo.textMuted)
                    }
                )
            )

            content()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .odPanel()
    }

    private func configCard(group: String, entries: [String: ConfigEntry]) -> some View {
        sectionCard(
            icon: Self.groupIcons[group] ?? "gearshape",
            label: ConfigMeta.groupLabels[group] ?? group,
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
        let enabled = partitions.filter(\.enabled).count
        return sectionCard(
            icon: "brain",
            label: L10n.Dashboard.subconsciousTitle,
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
                return SharedPresentationFormatting.formatDuration(ms)
            }
            return entry.value ?? "-"
        }()

        let sourceColor: Color = switch entry.source {
        case "env": OpenDuo.cyan300
        case "settings": OpenDuo.attention
        default: OpenDuo.textPrimary
        }

        let sourceBadge: String? = switch entry.source {
        case "env": "env"
        case "settings": "set"
        case "unset": nil
        default: entry.source
        }

        return HStack(spacing: 0) {
            Text(key)
                .font(.odMono(10))
                .foregroundStyle(OpenDuo.textSecondary)
                .frame(width: 160, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(displayVal)
                .font(.odMono(10))
                .foregroundStyle(sourceColor)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            Spacer(minLength: 0)

            if let badge = sourceBadge {
                // Bare mono type on the surface — no badge plate
                Text(badge)
                    .font(.odKicker(8))
                    .foregroundStyle(sourceColor.opacity(0.8))
            }
        }
        .padding(.vertical, 3)
    }

    private func partitionRow(_ p: PartitionConfig) -> some View {
        let cooldown = p.cooldown_ticks ?? 0
        let timeout = SharedPresentationFormatting.formatDuration(Double(p.max_duration_ms ?? 0))

        return HStack(spacing: 0) {
            ODSignalDot(tint: OpenDuo.ok, isLive: p.enabled, diameter: 5)

            Text(p.name)
                .font(.odMono(10))
                .foregroundStyle(p.enabled ? OpenDuo.textPrimary : OpenDuo.textMuted)
                .padding(.leading, 6)

            Spacer()

            if cooldown > 0 {
                Text("cd:\(cooldown)t")
                    .font(.odMono(9))
                    .foregroundStyle(OpenDuo.textMuted)
                    .padding(.trailing, 8)
            }

            Text(timeout)
                .font(.odMono(9))
                .foregroundStyle(OpenDuo.textMuted)
        }
        .padding(.vertical, 2)
    }
}
