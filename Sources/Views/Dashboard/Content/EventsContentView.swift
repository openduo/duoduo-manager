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
            Rectangle().fill(OpenDuo.borderHairline).frame(height: 1)
            scrollArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            ODKicker(text: displayName, tint: OpenDuo.textKicker)
            Text("  [\(events.count) events]")
                .font(.odMono(10))
                .foregroundStyle(OpenDuo.textFaint)
            Spacer()
            liveBadge
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var liveBadge: some View {
        HStack(spacing: 5) {
            ODSignalDot()
            ODKicker(text: L10n.Dashboard.live, tint: OpenDuo.ok)
        }
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
            .onAppear {
                scrollToBottom(proxy)
            }
            .onChange(of: sessionKey) { _, _ in
                autoFollow = true
                expandedIDs.removeAll()
                scrollToBottom(proxy)
            }
            .onChange(of: events.count) { old, new in
                if autoFollow { scrollToBottom(proxy) }
            }
            .onChange(of: events.last?.id) { _, _ in
                if autoFollow { scrollToBottom(proxy) }
            }
            .onChange(of: autoFollow) { old, new in
                if autoFollow { scrollToBottom(proxy) }
            }
        }
    }

    private var eventRows: some View {
        LazyVStack(spacing: 0) {
            if events.isEmpty {
                Text("no events")
                    .font(.odMono(11))
                    .foregroundStyle(OpenDuo.textMuted)
                    .padding(40)
            } else {
                ForEach(events) { evt in
                    row(for: evt)
                }
            }
            Color.clear.frame(height: 1).id(bottomAnchor)
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
        Button(expandedIDs.contains(evt.id) ? L10n.Dashboard.collapseJson : L10n.Dashboard.expandJson) {
            toggleExpand(evt.id)
        }
        Divider()
        Button(L10n.Dashboard.copyEventId) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(evt.id, forType: .string)
        }
        Button(L10n.Dashboard.copyRawJson) {
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
        SharedPresentationFormatting.prettyJSON(evt)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            proxy.scrollTo(bottomAnchor, anchor: .bottom)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                proxy.scrollTo(bottomAnchor, anchor: .bottom)
            }
        }
    }
}
