import SwiftUI

struct EventsContentView: View {
    let events: [SpineEvent]
    let sessionKey: String

    @State private var autoFollow = true
    @State private var expandedIDs: Set<String> = []

    private let bottomAnchor = "___bottom___"

    private var displayName: String {
        sessionKey.hasPrefix("meta:") ? String(sessionKey.dropFirst(5)) : sessionKey
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(DashboardTheme.border).frame(height: 1)
            scrollArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            Text("> ")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(DashboardTheme.accent)
            Text(displayName)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(DashboardTheme.text)
            Text("  [\(events.count) events]")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DashboardTheme.textTertiary)
            Spacer()
            liveBadge
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var liveBadge: some View {
        HStack(spacing: 4) {
            Text("●")
                .font(.system(size: 9, design: .monospaced))
            Text("LIVE")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(DashboardTheme.emerald)
    }

    // MARK: - Scroll Area

    private var scrollArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                eventRows
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { _ in autoFollow = false }
            )
            .onChange(of: events.count) { old, new in
                if autoFollow { proxy.scrollTo(bottomAnchor, anchor: .bottom) }
            }
            .onChange(of: autoFollow) { old, new in
                if autoFollow { proxy.scrollTo(bottomAnchor, anchor: .bottom) }
            }
        }
    }

    private var eventRows: some View {
        LazyVStack(spacing: 0) {
            if events.isEmpty {
                Text("no events")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(DashboardTheme.textTertiary)
                    .padding(40)
            } else {
                ForEach(events) { evt in
                    row(for: evt)
                }
                Color.clear.frame(height: 1).id(bottomAnchor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func row(for evt: SpineEvent) -> some View {
        EventRowView(
            event: evt,
            isExpanded: expandedIDs.contains(evt.id),
            onToggle: { toggleExpand(evt.id) }
        )
        .contextMenu { contextMenu(for: evt) }
        .id(evt.id)
    }

    @ViewBuilder
    private func contextMenu(for evt: SpineEvent) -> some View {
        Button(expandedIDs.contains(evt.id) ? "Collapse" : "Expand JSON") {
            toggleExpand(evt.id)
        }
        Divider()
        Button("Copy Event ID") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(evt.id, forType: .string)
        }
        Button("Copy Raw JSON") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(rawJSON(evt), forType: .string)
        }
    }

    // MARK: - Helpers

    private func toggleExpand(_ id: String) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
            autoFollow = false  // stop jumping away from the row you just opened
        }
    }

    private func rawJSON(_ evt: SpineEvent) -> String {
        DashboardTheme.prettyJSON(evt)
    }
}
