import SwiftUI

@MainActor
struct SnippetsSettingsView: View {
    var snippetManager: SnippetManager
    @State private var selection: Snippet.ID?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(snippetManager.snippets) { snippet in
                    SnippetRow(snippet: snippet) { updated in
                        snippetManager.update(updated)
                    }
                }
                .onDelete { snippetManager.remove(at: $0) }
            }

            Divider()

            HStack {
                Button(action: addSnippet) {
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

    private func addSnippet() {
        let snippet = Snippet(keyword: "", expansion: "", name: "New Snippet")
        snippetManager.add(snippet)
        selection = snippet.id
    }

    private func deleteSelected() {
        guard let id = selection,
              let index = snippetManager.snippets.firstIndex(where: { $0.id == id }) else { return }
        snippetManager.remove(at: IndexSet(integer: index))
        selection = nil
    }
}

@MainActor
private struct SnippetRow: View {
    var snippet: Snippet
    var onUpdate: (Snippet) -> Void

    @State private var expanded = false
    @State private var name: String
    @State private var keyword: String
    @State private var expansion: String

    init(snippet: Snippet, onUpdate: @escaping (Snippet) -> Void) {
        self.snippet = snippet
        self.onUpdate = onUpdate
        _name = State(initialValue: snippet.name)
        _keyword = State(initialValue: snippet.keyword)
        _expansion = State(initialValue: snippet.expansion)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Name", text: $name).onSubmit { save() }
                TextField("Keyword", text: $keyword).onSubmit { save() }
                TextField("Expansion", text: $expansion, axis: .vertical)
                    .lineLimit(3...6)
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
                Text(snippet.name.isEmpty ? "Untitled" : snippet.name)
                Spacer()
                Text(snippet.keyword)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }

    private func save() {
        var updated = snippet
        updated.name = name
        updated.keyword = keyword
        updated.expansion = expansion
        onUpdate(updated)
    }
}
