import SwiftUI

@MainActor
struct QuicklinksSettingsView: View {
    @State private var quicklinkManager = QuicklinkManager()
    @State private var selection: Quicklink.ID?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(quicklinkManager.quicklinks) { quicklink in
                    QuicklinkRow(quicklink: quicklink) { updated in
                        quicklinkManager.update(updated)
                    }
                }
                .onDelete { quicklinkManager.remove(at: $0) }
            }

            Divider()

            HStack {
                Button(action: addQuicklink) {
                    Image(systemName: "plus")
                }
                Button(action: deleteSelected) {
                    Image(systemName: "minus")
                }
                .disabled(selection == nil)
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(8)
        }
    }

    private func addQuicklink() {
        let quicklink = Quicklink(name: "New Quicklink", url: "https://", keyword: "")
        quicklinkManager.add(quicklink)
        selection = quicklink.id
    }

    private func deleteSelected() {
        guard let id = selection,
              let index = quicklinkManager.quicklinks.firstIndex(where: { $0.id == id }) else { return }
        quicklinkManager.remove(at: IndexSet(integer: index))
        selection = nil
    }
}

@MainActor
private struct QuicklinkRow: View {
    var quicklink: Quicklink
    var onUpdate: (Quicklink) -> Void

    @State private var expanded = false
    @State private var name: String
    @State private var keyword: String
    @State private var url: String

    init(quicklink: Quicklink, onUpdate: @escaping (Quicklink) -> Void) {
        self.quicklink = quicklink
        self.onUpdate = onUpdate
        _name = State(initialValue: quicklink.name)
        _keyword = State(initialValue: quicklink.keyword)
        _url = State(initialValue: quicklink.url)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Name", text: $name)
                    .onSubmit { save() }
                TextField("Keyword", text: $keyword)
                    .onSubmit { save() }
                TextField("URL", text: $url)
                    .onSubmit { save() }
                HStack {
                    Spacer()
                    Button("Save") { save() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
            .padding(.vertical, 4)
        } label: {
            HStack {
                Text(quicklink.name.isEmpty ? "Untitled" : quicklink.name)
                Spacer()
                Text(quicklink.keyword)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }

    private func save() {
        var updated = quicklink
        updated.name = name
        updated.keyword = keyword
        updated.url = url
        onUpdate(updated)
    }
}
