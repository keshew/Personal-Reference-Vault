import SwiftUI

struct ReferenceDetailView: View {
    @EnvironmentObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    let referenceID: UUID
    @State private var edit = false
    @State private var move = false
    @State private var related = false
    @State private var delete = false
    @State private var photos = false
    @State private var viewing: PhotoFocus?
    @State private var share: SharePayload?
    @State private var export = false
    @State private var duplicateID: UUID?
    @State private var showDuplicate = false
    private var item: ReferenceItem? { store.item(referenceID) }
    var body: some View {
        Group {
            if let item {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            Label(store.categoryName(item.categoryID).uppercased(), systemImage: store.category(item.categoryID)?.icon ?? "square.grid.2x2").font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(VaultStyle.accent).padding(.horizontal, 12).padding(.vertical, 8).background(VaultStyle.accent.opacity(0.07), in: Capsule()).overlay(Capsule().stroke(VaultStyle.line, lineWidth: 0.6))
                            Spacer(); if item.isPinned { Image(systemName: "pin.fill").font(.caption).foregroundStyle(VaultStyle.accent) }
                        }
                        Text(item.title).font(.system(size: 34, weight: .regular, design: .serif)).foregroundStyle(VaultStyle.ink).fixedSize(horizontal: false, vertical: true)
                        if !item.value.isEmpty {
                            Button { store.copy(item.value + (item.unit.isEmpty ? "" : " \(item.unit)")) } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack { Text("THE ESSENTIAL DETAIL").font(.system(size: 8, weight: .semibold, design: .monospaced)).tracking(2); Spacer(); Image(systemName: "doc.on.doc").font(.subheadline) }.foregroundStyle(VaultStyle.gold)
                                    Text(item.value + (item.unit.isEmpty ? "" : " \(item.unit)")).font(.system(size: 29, weight: .light, design: .monospaced)).foregroundStyle(VaultStyle.ivory).multilineTextAlignment(.leading).textSelection(.enabled)
                                    HStack(spacing: 5) { Image(systemName: "hand.tap").font(.system(size: 9, weight: .light)); Text("Tap to copy").font(.system(size: 9)) }.foregroundStyle(VaultStyle.ivory.opacity(0.4)).padding(.top, 7)
                                }.padding(23).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(LinearGradient(colors: [Color(red: 0.17, green: 0.27, blue: 0.22), VaultStyle.midnight], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 21))
                                    .overlay { RoundedRectangle(cornerRadius: 21).strokeBorder(VaultStyle.gold.opacity(0.3), lineWidth: 0.7) }
                                    .shadow(color: .black.opacity(0.08), radius: 15, y: 8)
                            }.buttonStyle(.plain).accessibilityHint("Copies the primary value")
                        }
                        HStack(spacing: 12) {
                            Button { store.update(item.id) { $0.isFavorite.toggle() } } label: { Label(item.isFavorite ? "Favorited" : "Favorite", systemImage: item.isFavorite ? "star.fill" : "star").frame(maxWidth: .infinity) }
                            Button { edit = true } label: { Label("Edit", systemImage: "pencil").frame(maxWidth: .infinity) }
                        }.font(.system(size: 12, weight: .medium)).padding(.vertical, 17).vaultPanel(radius: 15)
                        if !item.photos.isEmpty {
                            VStack(alignment: .leading, spacing: 13) {
                                HStack { Text("Supporting photos").font(.system(.title3, design: .serif)); Spacer(); Button("Manage") { photos = true }.font(.caption.weight(.medium)) }
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(item.photos) { photo in
                                            Button { viewing = PhotoFocus(id: photo.id) } label: {
                                                if let image = UIImage(data: photo.imageData) { Image(uiImage: image).resizable().scaledToFill().frame(width: 145, height: 120).clipShape(RoundedRectangle(cornerRadius: 13)) }
                                            }.accessibilityLabel(photo.caption.isEmpty ? "View photo" : photo.caption)
                                        }
                                    }
                                }
                            }
                        }
                        let fields = item.filledFields.filter { $0.0 != "Value" && $0.0 != "Unit" }
                        if !fields.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(fields.enumerated()), id: \.offset) { index, pair in
                                    Button { store.copy(pair.1) } label: {
                                        VStack(alignment: .leading, spacing: 7) {
                                            HStack { Text(pair.0.uppercased()).font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1.8); Spacer(); Image(systemName: "doc.on.doc").font(.caption2) }.foregroundStyle(VaultStyle.secondary)
                                            Text(pair.1).font(.body).foregroundStyle(VaultStyle.ink).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                                        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                                    }.buttonStyle(.plain)
                                    if index < fields.count - 1 { Divider().padding(.horizontal, 18) }
                                }
                            }.vaultPanel(radius: 18)
                        }
                        if !item.tagIDs.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack { ForEach(store.data.tags.filter { item.tagIDs.contains($0.id) }) { tag in NavigationLink(destination: TagDetailView(tagID: tag.id)) { TagPill(tag: tag) } } }
                            }
                        }
                        let collections = store.data.collections.filter { $0.referenceIDs.contains(item.id) }
                        if !collections.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("In collections").font(.system(.title3, design: .serif))
                                ForEach(collections) { collection in NavigationLink(destination: CollectionDetailView(collectionID: collection.id)) { CollectionRow(collection: collection) }.buttonStyle(.plain) }
                            }
                        }
                        VStack(alignment: .leading, spacing: 13) {
                            HStack { Text("Connected details").font(.system(.title3, design: .serif)); Spacer(); Button { related = true } label: { Image(systemName: "plus.circle") }.accessibilityLabel("Add Related Reference") }
                            if item.relatedIDs.isEmpty { Text("Link useful details that belong together.").font(.subheadline).foregroundStyle(VaultStyle.secondary) }
                            ForEach(item.relatedIDs.compactMap { store.item($0) }) { reference in NavigationLink(destination: ReferenceDetailView(referenceID: reference.id)) { ReferenceRow(item: reference, card: true) }.buttonStyle(.plain) }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.type.rawValue)
                            Text("Created \(item.createdAt.formatted(date: .abbreviated, time: .omitted))")
                            Text("Edited \(item.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        }.font(.caption).foregroundStyle(VaultStyle.secondary).padding(.top, 5)
                    }.padding(22).padding(.bottom, 25)
                }.background(VaultStyle.background)
            } else { VaultEmptyState(icon: "tray", title: "Reference Unavailable", message: "This reference has been removed from your library.") }
        }.navigationTitle("Reference").navigationBarTitleDisplayMode(.inline)
            .onAppear { store.viewed(referenceID) }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let item {
                        Menu {
                            Button("Edit", systemImage: "pencil") { edit = true }
                            Button(item.isPinned ? "Unpin" : "Pin to Home", systemImage: "pin") { store.update(item.id) { $0.isPinned.toggle() } }
                            Button("Duplicate", systemImage: "plus.square.on.square") { if let id = store.duplicate(item) { duplicateID = id; showDuplicate = true } }
                            Button("Move", systemImage: "folder") { move = true }
                            Button("Manage Photos", systemImage: "photo") { photos = true }
                            Button("Copy Value", systemImage: "doc.on.doc") { store.copy(item.value.isEmpty ? item.title : item.value + (item.unit.isEmpty ? "" : " \(item.unit)")) }
                            Button("Copy All Information", systemImage: "doc.on.clipboard") { store.copy(store.text(for: item)) }
                            Button("Share Text", systemImage: "square.and.arrow.up") { share = SharePayload(items: [store.text(for: item)]) }
                            Button("Export / PDF", systemImage: "doc") { export = true }
                            Button("Delete", systemImage: "trash", role: .destructive) { delete = true }
                        } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("Reference actions")
                    }
                }
            }
            .sheet(isPresented: $edit) { if let item { ReferenceEditor(reference: item) } }
            .sheet(isPresented: $move) { MoveReferencesView(ids: [referenceID]) }
            .sheet(isPresented: $related) { ReferenceSelectionView(title: "Related References", excluded: [referenceID], selected: Set(item?.relatedIDs ?? [])) { ids in
                store.commit { state in if let i = state.references.firstIndex(where: { $0.id == referenceID }) { state.references[i].relatedIDs = Array(ids); state.references[i].updatedAt = Date() } }
            } }
            .sheet(isPresented: $photos) { NavigationStack { PhotosEditView(photos: Binding(get: { item?.photos ?? [] }, set: { photos in store.update(referenceID) { $0.photos = photos } })).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { photos = false } } } } }
            .fullScreenCover(item: $viewing) { focus in PhotoViewer(photos: item?.photos ?? [], selectedID: focus.id) }
            .sheet(item: $share) { ActivitySheet(items: $0.items) }
            .sheet(isPresented: $export) { NavigationStack { ExportView(initialIDs: [referenceID], presented: true) } }
            .navigationDestination(isPresented: $showDuplicate) { if let duplicateID { ReferenceDetailView(referenceID: duplicateID) } }
            .confirmationDialog("Delete this reference?", isPresented: $delete, titleVisibility: .visible) { Button("Delete Reference", role: .destructive) { if store.delete([referenceID]) { dismiss() } } } message: { Text("Its photos and links will also be removed. This cannot be undone.") }
    }
}
