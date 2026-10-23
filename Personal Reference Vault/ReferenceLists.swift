import SwiftUI

enum ReferenceScope: Equatable {
    case all, favorites, pinned, history, category(UUID), tag(UUID), collection(UUID)
    @MainActor func items(in store: VaultStore, query: String, sort: ReferenceSort) -> [ReferenceItem] {
        let sorted = store.matching(query: query, sort: sort)
        switch self {
        case .all: return sorted
        case .favorites: return sorted.filter(\.isFavorite)
        case .pinned: return sorted.filter(\.isPinned)
        case .history:
            let ids = Set(sorted.map(\.id))
            return store.data.history.compactMap { ids.contains($0.referenceID) ? store.item($0.referenceID) : nil }
        case .category(let id): return sorted.filter { $0.categoryID == id }
        case .tag(let id): return sorted.filter { $0.tagIDs.contains(id) }
        case .collection(let id):
            let ids = Set(store.data.collections.first { $0.id == id }?.referenceIDs ?? [])
            return sorted.filter { ids.contains($0.id) }
        }
    }
    var emptyMessage: String {
        switch self {
        case .favorites: return "Your favorite references will appear here."
        case .pinned: return "Pin a reference to keep it within reach on Home."
        case .history: return "References you open will appear here when history is enabled."
        default: return "You haven’t saved any references here yet."
        }
    }
    var emptyTitle: String {
        switch self {
        case .favorites: return "No Favorites"
        case .pinned: return "No Pinned References"
        case .history: return "Nothing Viewed Yet"
        default: return "No References"
        }
    }
}

struct ReferenceListView: View {
    @EnvironmentObject var store: VaultStore
    let title: String
    var scope: ReferenceScope = .all
    @State private var query = ""
    @State private var sort: ReferenceSort = .newest
    @State private var add = false
    @State private var selecting = false
    @State private var selected: Set<UUID> = []
    @State private var deleteIDs: Set<UUID> = []
    @State private var confirmDelete = false
    @State private var clearHistory = false
    @State private var move = false
    @State private var export = false
    @State private var share: SharePayload?
    private var items: [ReferenceItem] { scope.items(in: store, query: query, sort: sort) }

    var body: some View {
        List {
            if items.isEmpty {
                VaultEmptyState(icon: query.isEmpty ? "tray" : "magnifyingglass", title: query.isEmpty ? scope.emptyTitle : "No Search Results", message: query.isEmpty ? scope.emptyMessage : "No matching references found.", actionTitle: query.isEmpty && scope != .history ? "Add Reference" : nil, action: { add = true }).listRowBackground(Color.clear).listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(items) { item in
                        if selecting {
                            Button { if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) } } label: {
                                HStack { Image(systemName: selected.contains(item.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(VaultStyle.accent); ReferenceRow(item: item) }
                            }.buttonStyle(.plain)
                        } else {
                            NavigationLink(destination: ReferenceDetailView(referenceID: item.id)) { ReferenceRow(item: item, card: store.settings.referenceView == "Cards") }
                                .contextMenu {
                                    Button(item.isFavorite ? "Remove Favorite" : "Favorite", systemImage: "star") { store.update(item.id) { $0.isFavorite.toggle() } }
                                    Button(item.isPinned ? "Unpin" : "Pin", systemImage: "pin") { store.update(item.id) { $0.isPinned.toggle() } }
                                    Button("Copy Value", systemImage: "doc.on.doc") { store.copy(item.value.isEmpty ? item.displayValue : item.value + (item.unit.isEmpty ? "" : " \(item.unit)")) }
                                    Button("Duplicate", systemImage: "plus.square.on.square") { store.duplicate(item) }
                                    if scope == .history { Button("Remove from History", systemImage: "clock.badge.xmark") { removeHistory(item.id) } }
                                    Button("Delete", systemImage: "trash", role: .destructive) { askDelete([item.id]) }
                                }
                                .swipeActions(edge: .trailing) {
                                    if scope == .history { Button("Remove", role: .destructive) { removeHistory(item.id) } }
                                    else { Button("Delete", role: .destructive) { askDelete([item.id]) } }
                                }
                                .swipeActions(edge: .leading) { Button { store.update(item.id) { $0.isFavorite.toggle() } } label: { Label(item.isFavorite ? "Unfavorite" : "Favorite", systemImage: "star") }.tint(VaultColor.amber.color) }
                        }
                    }
                } header: { Text(selecting ? "\(selected.count) selected" : "\(items.count) reference\(items.count == 1 ? "" : "s")") }
            }
        }.listStyle(.insetGrouped).vaultBackground().dismissKeyboardOnScroll()
            .navigationTitle(title).navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: "Search references")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if scope != .history { Picker("Sort", selection: $sort) { ForEach(ReferenceSort.allCases) { Text($0.rawValue).tag($0) } } }
                        Button(selecting ? "Done Selecting" : "Select References", systemImage: "checkmark.circle") { selecting.toggle(); selected = [] }.disabled(items.isEmpty && !selecting)
                        if selecting { Button("Select All") { selected = Set(items.map(\.id)) } }
                        if scope == .history { Button("Clear History", systemImage: "clock.badge.xmark", role: .destructive) { clearHistory = true }.disabled(store.data.history.isEmpty) }
                    } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("List options")
                }
                ToolbarItem(placement: .navigationBarTrailing) { Button { add = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add Reference") }
                if selecting {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Text("\(selected.count) selected").font(.caption)
                        Spacer()
                        Menu {
                            Button("Favorite Selected", systemImage: "star") { bulkFavorite() }
                            Button("Move to Category", systemImage: "folder") { move = true }
                            Button("Share Text", systemImage: "square.and.arrow.up") { share = SharePayload(items: [store.references.filter { selected.contains($0.id) }.map { store.text(for: $0) }.joined(separator: "\n\n──────────\n\n")]) }
                            Button("Export Selected", systemImage: "square.and.arrow.up.on.square") { export = true }
                            Button("Delete Selected", systemImage: "trash", role: .destructive) { askDelete(selected) }
                        } label: { Label("Actions", systemImage: "ellipsis.circle") }.disabled(selected.isEmpty)
                    }
                }
            }
            .sheet(isPresented: $add) { ReferenceEditor(categoryID: initialCategory, favorite: scope == .favorites, pinned: scope == .pinned, tagIDs: initialTags, collectionID: initialCollection) }
            .sheet(isPresented: $move) { MoveReferencesView(ids: selected) }
            .sheet(isPresented: $export) { NavigationStack { ExportView(initialIDs: selected, presented: true) } }
            .sheet(item: $share) { ActivitySheet(items: $0.items) }
            .onChange(of: store.references.map(\.id)) { ids in selected.formIntersection(Set(ids)) }
            .confirmationDialog("Delete \(deleteIDs.count) reference\(deleteIDs.count == 1 ? "" : "s")?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { if store.delete(deleteIDs) { selected.subtract(deleteIDs) } }
            } message: { Text("This also removes their photos and links. This cannot be undone.") }
            .confirmationDialog("Clear recently viewed history?", isPresented: $clearHistory, titleVisibility: .visible) { Button("Clear History", role: .destructive) { store.commit { $0.history = [] } } } message: { Text("Your references will be kept.") }
    }
    private var initialCategory: UUID? { if case .category(let id) = scope { return id }; return nil }
    private var initialTags: [UUID] { if case .tag(let id) = scope { return [id] }; return [] }
    private var initialCollection: UUID? { if case .collection(let id) = scope { return id }; return nil }
    private func removeHistory(_ id: UUID) { store.commit { $0.history.removeAll { $0.referenceID == id } } }
    private func askDelete(_ ids: Set<UUID>) { deleteIDs = ids; confirmDelete = true }
    private func bulkFavorite() {
        store.commit { data in for i in data.references.indices where selected.contains(data.references[i].id) { data.references[i].isFavorite = true; data.references[i].updatedAt = Date() } }
    }
}

struct SearchView: View {
    @EnvironmentObject var store: VaultStore
    @State private var query = ""
    @State private var filter = ReferenceFilter()
    @State private var sort: ReferenceSort = .newest
    @State private var filters = false
    private var results: [ReferenceItem] { store.matching(query: query, filter: filter, sort: sort) }
    var body: some View {
        List {
            if query.isEmpty && !filter.isActive {
                Section {
                    HStack(alignment: .center, spacing: 20) {
                        VStack(alignment: .leading, spacing: 14) {
                            VaultEyebrow(text: "Your library, at your fingertips", color: VaultStyle.gold)
                            Text("Find the detail.\nKeep your flow.").font(.system(size: 28, weight: .regular, design: .serif)).foregroundStyle(VaultStyle.ivory)
                            Text("Search values, notes, tags\nand the things worth remembering.").font(.system(size: 11)).foregroundStyle(VaultStyle.ivory.opacity(0.5)).lineSpacing(4)
                        }
                        Spacer(minLength: 0)
                        ZStack {
                            Circle().stroke(VaultStyle.gold.opacity(0.20), lineWidth: 0.6).frame(width: 58, height: 58)
                            Image(systemName: "magnifyingglass").font(.system(size: 25, weight: .ultraLight)).foregroundStyle(VaultStyle.gold)
                        }
                    }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(VaultStyle.midnight, in: RoundedRectangle(cornerRadius: 21)).overlay { RoundedRectangle(cornerRadius: 21).strokeBorder(VaultStyle.gold.opacity(0.3), lineWidth: 0.7) }
                }.listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 12, trailing: 0))
                Section("Find faster") {
                    Button { filter.favorites = true } label: { Label("Favorites", systemImage: "star") }
                    Button { filter.hasPhoto = true } label: { Label("With Photos", systemImage: "photo") }
                    Button { filter.recentAdded = true } label: { Label("Added This Week", systemImage: "clock.badge.plus") }
                    NavigationLink(destination: UnitConverterView()) { Label("Unit Converter", systemImage: "ruler") }
                }
            }
            if filter.isActive {
                Section { Button("Clear All Filters") { filter = ReferenceFilter() } } footer: { Text("Recent filters include the last 7 days.") }
            }
            Section("\(results.count) result\(results.count == 1 ? "" : "s")") {
                if results.isEmpty {
                    VaultEmptyState(icon: "magnifyingglass", title: "No Search Results", message: "No matching references found.").listRowBackground(Color.clear)
                } else {
                    ForEach(results) { item in NavigationLink(destination: ReferenceDetailView(referenceID: item.id)) { ReferenceRow(item: item) } }
                }
            }
        }.vaultBackground().dismissKeyboardOnScroll().navigationTitle("Search")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search your library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button { filters = true } label: { Image(systemName: filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle") }.accessibilityLabel("Search Filters") }
                ToolbarItem(placement: .navigationBarTrailing) { Menu { Picker("Sort", selection: $sort) { ForEach(ReferenceSort.allCases) { Text($0.rawValue).tag($0) } } } label: { Image(systemName: "arrow.up.arrow.down") }.accessibilityLabel("Sort results") }
            }
            .sheet(isPresented: $filters) { SearchFiltersView(filter: $filter) }
    }
}

struct SearchFiltersView: View {
    @EnvironmentObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: ReferenceFilter
    var body: some View {
        NavigationStack {
            Form {
                Section("Organize") {
                    Picker("Category", selection: $filter.categoryID) { Text("All Categories").tag(nil as UUID?); ForEach(store.categories) { Text($0.name).tag(Optional($0.id)) } }
                    Picker("Tag", selection: $filter.tagID) { Text("All Tags").tag(nil as UUID?); ForEach(store.data.tags) { Text($0.name).tag(Optional($0.id)) } }
                    Picker("Reference Type", selection: $filter.type) { Text("All Types").tag(nil as ReferenceType?); ForEach(ReferenceType.allCases) { Text($0.rawValue).tag(Optional($0)) } }
                }
                Section("Show only") { Toggle("Favorites", isOn: $filter.favorites); Toggle("Has Photo", isOn: $filter.hasPhoto) }
                Section { Toggle("Recently Added", isOn: $filter.recentAdded); Toggle("Recently Updated", isOn: $filter.recentUpdated) } footer: { Text("Within the last 7 days.") }
                Button("Reset Filters") { filter = ReferenceFilter() }
            }.vaultBackground().navigationTitle("Search Filters").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct MoveReferencesView: View {
    @EnvironmentObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    let ids: Set<UUID>
    var body: some View {
        NavigationStack {
            List(store.categories) { category in
                Button {
                    if store.commit({ data in for i in data.references.indices where ids.contains(data.references[i].id) { data.references[i].categoryID = category.id; data.references[i].updatedAt = Date() } }) { store.notify("References moved"); dismiss() }
                } label: { Label(category.name, systemImage: category.icon).foregroundStyle(category.color.color) }.padding(.vertical, 6)
            }.vaultBackground().navigationTitle("Move to Category").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
