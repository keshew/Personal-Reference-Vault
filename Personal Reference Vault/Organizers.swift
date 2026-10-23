import SwiftUI

let vaultIcons = ["square.grid.2x2", "house", "person.crop.square", "tshirt", "shoeprints.fill", "chair.lounge", "washer", "desktopcomputer", "ruler", "paintpalette", "gearshape.2", "drop", "cable.connector", "battery.100percent", "wrench.and.screwdriver", "paperclip", "square.stack", "bed.double", "leaf", "tent", "cup.and.saucer", "lightbulb", "archivebox", "tag", "bookmark", "shippingbox", "camera", "book", "car", "suitcase"]

struct CategoryCard: View {
    @EnvironmentObject var store: VaultStore
    let category: VaultCategory
    private var count: Int { store.references.filter { $0.categoryID == category.id }.count }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                IconTile(icon: category.icon, color: category.color.color, size: 40)
                Spacer()
                Text(String(format: "%02d", count)).font(.system(size: 24, weight: .light, design: .serif)).foregroundStyle(VaultStyle.secondary.opacity(0.7))
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(category.name).font(.system(size: 20, weight: .regular, design: .serif)).foregroundStyle(VaultStyle.ink).lineLimit(2).frame(minHeight: 44, alignment: .bottom)
                Rectangle().fill(category.color.color.opacity(0.25)).frame(height: 0.7)
                HStack {
                    Text("\(count) reference\(count == 1 ? "" : "s")").font(.system(size: 10)).foregroundStyle(VaultStyle.secondary)
                    Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .light)).foregroundStyle(category.color.color)
                }
            }
        }.padding(17).frame(maxWidth: .infinity, alignment: .leading).vaultPanel(radius: 19)
    }
}

struct CategoriesView: View {
    @EnvironmentObject var store: VaultStore
    @State private var create = false
    @State private var reorder = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    VaultEyebrow(text: "The art of being organized")
                    HStack(alignment: .lastTextBaseline) {
                        Text("A place for\nevery detail.").font(.system(size: 29, weight: .regular, design: .serif)).foregroundStyle(VaultStyle.ink)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 5) { Text("\(store.categories.count)").font(.system(size: 34, weight: .light, design: .serif)); VaultEyebrow(text: "Categories") }.foregroundStyle(VaultStyle.accent)
                    }
                }.padding(.bottom, 3)
                HStack(spacing: 12) {
                    NavigationLink(destination: TagsView()) { Label("Tags", systemImage: "tag").frame(maxWidth: .infinity).padding(16).vaultPanel(radius: 14) }
                    NavigationLink(destination: CollectionsView()) { Label("Collections", systemImage: "square.stack").frame(maxWidth: .infinity).padding(16).vaultPanel(radius: 14) }
                }.font(.subheadline.weight(.medium))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(store.categories) { category in
                        NavigationLink(destination: CategoryDetailView(categoryID: category.id)) { CategoryCard(category: category) }.buttonStyle(.plain)
                    }
                }
            }.padding(22)
        }.background(VaultStyle.background).navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button { reorder = true } label: { Image(systemName: "arrow.up.arrow.down") }.accessibilityLabel("Reorder Categories") }
                ToolbarItem(placement: .navigationBarTrailing) { Button { create = true } label: { Image(systemName: "plus") }.accessibilityLabel("Create Category") }
            }
            .sheet(isPresented: $create) { CategoryEditor() }
            .sheet(isPresented: $reorder) { CategoryOrderView() }
    }
}

struct CategoryOrderView: View {
    @EnvironmentObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                ForEach(store.categories) { Label($0.name, systemImage: $0.icon) }
                    .onMove { source, target in store.commit { $0.categories.move(fromOffsets: source, toOffset: target) } }
            }.environment(\.editMode, .constant(.active)).vaultBackground().navigationTitle("Reorder Categories").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct CategoryDetailView: View {
    @EnvironmentObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    let categoryID: UUID
    @State private var edit = false
    var body: some View {
        ReferenceListView(title: store.categoryName(categoryID), scope: .category(categoryID))
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { edit = true } label: { Image(systemName: "pencil") }.accessibilityLabel("Edit Category") } }
            .sheet(isPresented: $edit) { if let category = store.category(categoryID) { CategoryEditor(category: category) } }
            .onChange(of: store.categories) { _ in if store.category(categoryID) == nil { dismiss() } }
    }
}

struct CategoryEditor: View {
    @EnvironmentObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: VaultCategory
    @State private var deleting = false
    @State private var confirm = false
    @State private var destination: UUID?
    let existing: Bool
    init(category: VaultCategory? = nil) { _draft = State(initialValue: category ?? VaultCategory(name: "", icon: "square.grid.2x2")); existing = category != nil }
    private var count: Int { store.references.filter { $0.categoryID == draft.id }.count }
    private var valid: Bool { !draft.name.trimmed.isEmpty && !store.categories.contains { $0.id != draft.id && $0.name.searchKey == draft.name.trimmed.searchKey } }
    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    TextField("Name", text: $draft.name)
                    NavigationLink(destination: IconPickerView(selection: $draft.icon, color: draft.color.color)) { HStack { Text("Icon"); Spacer(); Image(systemName: draft.icon).foregroundStyle(draft.color.color) } }
                    ColorPickerRow(selection: $draft.color)
                }
                if !draft.name.trimmed.isEmpty && !valid { Text("A category with this name already exists.").font(.caption).foregroundStyle(.red) }
                if existing && !draft.isBuiltIn {
                    Section {
                        if deleting {
                            if count > 0 {
                                Picker("Move references to", selection: $destination) { Text("Choose a category").tag(nil as UUID?); ForEach(store.categories.filter { $0.id != draft.id }) { Text($0.name).tag(Optional($0.id)) } }
                            }
                            Button("Confirm Delete Category", role: .destructive) { confirm = true }.disabled(count > 0 && destination == nil)
                        } else { Button("Delete Category", role: .destructive) { deleting = true } }
                    } footer: { if deleting { Text(count > 0 ? "Choose where to move \(count) references before deleting this category." : "This category has no references.") } }
                }
            }.vaultBackground().dismissKeyboardOnScroll().navigationTitle(existing ? "Edit Category" : "Create Category").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(!valid) }
                }
                .confirmationDialog("Delete this category?", isPresented: $confirm, titleVisibility: .visible) { Button("Delete Category", role: .destructive) { delete() } } message: { Text("References will be moved to the category you selected.") }
        }
    }
    private func save() {
        draft.name = draft.name.trimmed
        if store.commit({ state in
            if let i = state.categories.firstIndex(where: { $0.id == draft.id }) { state.categories[i] = draft } else { state.categories.append(draft) }
        }) { dismiss() }
    }
    private func delete() {
        if store.commit({ state in
            if let destination { for i in state.references.indices where state.references[i].categoryID == draft.id { state.references[i].categoryID = destination; state.references[i].updatedAt = Date() } }
            state.categories.removeAll { $0.id == draft.id }
        }) { dismiss() }
    }
}

struct ColorPickerRow: View {
    @Binding var selection: VaultColor
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color").font(.subheadline)
            HStack(spacing: 14) {
                ForEach(VaultColor.allCases) { color in
                    Button { selection = color } label: {
                        Circle().fill(color.color).frame(width: 30, height: 30).overlay { if selection == color { Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(VaultStyle.background) } }
                    }.buttonStyle(.plain).accessibilityLabel(color.title).accessibilityAddTraits(selection == color ? .isSelected : [])
                }
            }.padding(.vertical, 4)
        }.padding(.vertical, 6)
    }
}

struct IconPickerView: View {
    @Binding var selection: String
    var color = VaultStyle.accent
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 65))], spacing: 16) {
                ForEach(vaultIcons, id: \.self) { icon in
                    Button { selection = icon } label: { IconTile(icon: icon, color: color, size: 58).overlay { RoundedRectangle(cornerRadius: 16).stroke(selection == icon ? color : .clear, lineWidth: 2) } }
                        .accessibilityLabel(icon.replacingOccurrences(of: ".", with: " ")).accessibilityAddTraits(selection == icon ? .isSelected : [])
                }
            }.padding(24)
        }.background(VaultStyle.background).navigationTitle("Choose Icon").navigationBarTitleDisplayMode(.inline)
    }
}

struct TagsView: View {
    @EnvironmentObject var store: VaultStore
    @State private var create = false
    @State private var editing: VaultTag?
    var body: some View {
        List {
            if store.data.tags.isEmpty { VaultEmptyState(icon: "tag", title: "No Tags", message: "Create reusable tags to connect details across your library.", actionTitle: "Create Tag", action: { create = true }).listRowBackground(Color.clear) }
            ForEach(store.data.tags) { tag in
                NavigationLink(destination: TagDetailView(tagID: tag.id)) {
                    HStack { Circle().fill(tag.color.color).frame(width: 10, height: 10); Text(tag.name); Spacer(); Text("\(store.references.filter { $0.tagIDs.contains(tag.id) }.count)").foregroundStyle(VaultStyle.secondary) }.padding(.vertical, 7)
                }.swipeActions { Button("Edit") { editing = tag }.tint(VaultStyle.accent) }.contextMenu { Button("Edit Tag", systemImage: "pencil") { editing = tag } }
            }
        }.vaultBackground().navigationTitle("Tags")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { create = true } label: { Image(systemName: "plus") }.accessibilityLabel("Create Tag") } }
            .sheet(isPresented: $create) { TagEditor() }.sheet(item: $editing) { TagEditor(tag: $0) }
    }
}

struct TagDetailView: View {
    @EnvironmentObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    let tagID: UUID
    @State private var editing = false
    private var tag: VaultTag? { store.data.tags.first { $0.id == tagID } }
    var body: some View {
        ReferenceListView(title: tag?.name ?? "Tag", scope: .tag(tagID))
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { editing = true } label: { Image(systemName: "pencil") }.accessibilityLabel("Edit Tag") } }
            .sheet(isPresented: $editing) { if let tag { TagEditor(tag: tag) } }
            .onChange(of: store.data.tags) { _ in if tag == nil { dismiss() } }
    }
}

struct TagEditor: View {
    @EnvironmentObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: VaultTag
    @State private var confirm = false
    let existing: Bool
    init(tag: VaultTag? = nil) { _draft = State(initialValue: tag ?? VaultTag(name: "")); existing = tag != nil }
    private var valid: Bool { !draft.name.trimmed.isEmpty && !store.data.tags.contains { $0.id != draft.id && $0.name.searchKey == draft.name.trimmed.searchKey } }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Tag name", text: $draft.name)
                ColorPickerRow(selection: $draft.color)
                if !draft.name.trimmed.isEmpty && !valid { Text("A tag with this name already exists.").font(.caption).foregroundStyle(.red) }
                if existing { Section { Button("Delete Tag", role: .destructive) { confirm = true } } footer: { Text("Deleting a tag removes it from references. References are kept.") } }
            }.vaultBackground().navigationTitle(existing ? "Edit Tag" : "Create Tag").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") {
                        draft.name = draft.name.trimmed
                        if store.commit({ state in if let i = state.tags.firstIndex(where: { $0.id == draft.id }) { state.tags[i] = draft } else { state.tags.append(draft) } }) { dismiss() }
                    }.disabled(!valid) }
                }
                .confirmationDialog("Delete this tag?", isPresented: $confirm, titleVisibility: .visible) { Button("Delete Tag", role: .destructive) {
                    if store.commit({ state in
                        state.tags.removeAll { $0.id == draft.id }
                        for i in state.references.indices { state.references[i].tagIDs.removeAll { $0 == draft.id } }
                    }) { dismiss() }
                } }
        }
    }
}

struct CollectionRow: View {
    let collection: VaultCollection
    var body: some View {
        HStack(spacing: 15) {
            ZStack(alignment: .bottomTrailing) {
                IconTile(icon: collection.icon, color: collection.color.color, size: 53)
                Circle().fill(VaultStyle.surface).frame(width: 17, height: 17).overlay(Image(systemName: "square.stack").font(.system(size: 8, weight: .light)).foregroundStyle(collection.color.color)).offset(x: 3, y: 3)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(collection.name).font(.system(.body, design: .serif).weight(.medium)).foregroundStyle(VaultStyle.ink)
                Text("\(collection.referenceIDs.count) REFERENCES").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1.3).foregroundStyle(VaultStyle.secondary)
            }; Spacer()
        }.padding(.vertical, 10)
    }
}

struct CollectionsView: View {
    @EnvironmentObject var store: VaultStore
    @State private var create = false
    var body: some View {
        List {
            if store.data.collections.isEmpty { VaultEmptyState(icon: "square.stack", title: "No Collections", message: "Create collections to group related references.", actionTitle: "Create Collection", action: { create = true }).listRowBackground(Color.clear) }
            ForEach(store.data.collections) { collection in NavigationLink(destination: CollectionDetailView(collectionID: collection.id)) { CollectionRow(collection: collection) } }
        }.vaultBackground().navigationTitle("Collections")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { create = true } label: { Image(systemName: "plus") }.accessibilityLabel("Create Collection") } }
            .sheet(isPresented: $create) { CollectionEditor() }
    }
}

struct CollectionEditor: View {
    @EnvironmentObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: VaultCollection
    @State private var confirm = false
    let existing: Bool
    init(collection: VaultCollection? = nil) { _draft = State(initialValue: collection ?? VaultCollection(name: "")); existing = collection != nil }
    var body: some View {
        NavigationStack {
            Form {
                Section("Collection") {
                    TextField("Title", text: $draft.name)
                    TextField("Description (optional)", text: $draft.description, axis: .vertical).lineLimit(3...6)
                    NavigationLink(destination: IconPickerView(selection: $draft.icon, color: draft.color.color)) { HStack { Text("Cover Icon"); Spacer(); Image(systemName: draft.icon) } }
                    ColorPickerRow(selection: $draft.color)
                }
                if existing { Section { Button("Delete Collection", role: .destructive) { confirm = true } } footer: { Text("References inside this collection will be kept.") } }
            }.vaultBackground().dismissKeyboardOnScroll().navigationTitle(existing ? "Edit Collection" : "Create Collection").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") {
                        draft.name = draft.name.trimmed
                        if store.commit({ state in if let i = state.collections.firstIndex(where: { $0.id == draft.id }) { state.collections[i] = draft } else { state.collections.append(draft) } }) { dismiss() }
                    }.disabled(draft.name.trimmed.isEmpty) }
                }
                .confirmationDialog("Delete this collection?", isPresented: $confirm, titleVisibility: .visible) { Button("Delete Collection", role: .destructive) { if store.commit({ $0.collections.removeAll { $0.id == draft.id } }) { dismiss() } } }
        }
    }
}

struct CollectionDetailView: View {
    @EnvironmentObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    let collectionID: UUID
    @State private var edit = false
    @State private var createReference = false
    @State private var add = false
    @State private var export = false
    @State private var sort: ReferenceSort = .name
    @State private var share: SharePayload?
    private var collection: VaultCollection? { store.data.collections.first { $0.id == collectionID } }
    var body: some View {
        List {
            if let collection {
                Section {
                    VStack(alignment: .leading, spacing: 13) {
                        IconTile(icon: collection.icon, color: collection.color.color, size: 55)
                        if !collection.description.isEmpty { Text(collection.description).foregroundStyle(VaultStyle.secondary) }
                        Text("\(collection.referenceIDs.count) references").font(.caption).foregroundStyle(VaultStyle.secondary)
                    }.padding(.vertical, 10)
                    Button { add = true } label: { Label("Add / Remove References", systemImage: "plus.circle") }
                }
                Section {
                    let items = ReferenceScope.collection(collectionID).items(in: store, query: "", sort: sort)
                    if items.isEmpty { Text("Add references from your library to this collection.").font(.subheadline).foregroundStyle(VaultStyle.secondary).padding(.vertical, 15) }
                    ForEach(items) { item in
                        NavigationLink(destination: ReferenceDetailView(referenceID: item.id)) { ReferenceRow(item: item) }
                            .swipeActions { Button("Remove", role: .destructive) { store.commit { state in if let i = state.collections.firstIndex(where: { $0.id == collectionID }) { state.collections[i].referenceIDs.removeAll { $0 == item.id } } } } }
                    }
                }
            }
        }.vaultBackground().navigationTitle(collection?.name ?? "Collection")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Create New Reference", systemImage: "plus") { createReference = true }
                        Button("Edit Collection", systemImage: "pencil") { edit = true }
                        Picker("Sort", selection: $sort) { ForEach(ReferenceSort.allCases) { Text($0.rawValue).tag($0) } }
                        Button("Share Summary", systemImage: "square.and.arrow.up") { shareCollection() }
                        Button("Export / PDF", systemImage: "doc") { export = true }
                    } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("Collection options")
                }
            }
            .sheet(isPresented: $edit) { if let collection { CollectionEditor(collection: collection) } }
            .sheet(isPresented: $createReference) { ReferenceEditor(collectionID: collectionID) }
            .sheet(isPresented: $add) {
                ReferenceSelectionView(title: "Collection References", selected: Set(collection?.referenceIDs ?? [])) { ids in
                    store.commit { state in if let i = state.collections.firstIndex(where: { $0.id == collectionID }) { state.collections[i].referenceIDs = Array(ids) } }
                }
            }
            .sheet(isPresented: $export) { NavigationStack { ExportView(initialCollection: collectionID, presented: true) } }
            .sheet(item: $share) { ActivitySheet(items: $0.items) }
            .onChange(of: store.data.collections) { _ in if collection == nil { dismiss() } }
    }
    private func shareCollection() {
        guard let collection else { return }
        let text = [collection.name, collection.description, "\(collection.referenceIDs.count) references", ReferenceScope.collection(collectionID).items(in: store, query: "", sort: sort).map { store.text(for: $0) }.joined(separator: "\n\n")].filter { !$0.isEmpty }.joined(separator: "\n\n")
        share = SharePayload(items: [text])
    }
}

struct ReferenceSelectionView: View {
    @EnvironmentObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    let title: String
    var excluded: Set<UUID> = []
    @State var selected: Set<UUID>
    let save: (Set<UUID>) -> Bool
    @State private var query = ""
    var body: some View {
        NavigationStack {
            List {
                let items = store.matching(query: query, sort: .name).filter { !excluded.contains($0.id) }
                if items.isEmpty { VaultEmptyState(icon: "tray", title: "No References", message: "Save a reference in your library first.").listRowBackground(Color.clear) }
                ForEach(items) { item in
                    Button { if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) } } label: {
                        HStack { ReferenceRow(item: item); Image(systemName: selected.contains(item.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(VaultStyle.accent) }
                    }.buttonStyle(.plain)
                }
            }.vaultBackground().searchable(text: $query).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Done (\(selected.count))") { if save(selected) { dismiss() } } }
                }
        }
    }
}
