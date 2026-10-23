import SwiftUI

struct ReferenceEditor: View {
    @EnvironmentObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ReferenceItem
    @State private var baseline: ReferenceItem?
    @State private var templatePicker = false
    @State private var createTag = false
    @State private var related = false
    @State private var customField = false
    @State private var discard = false
    @State private var advanced = false
    let existing: Bool
    private let initialCategory: UUID?
    private let collectionID: UUID?
    init(reference: ReferenceItem? = nil, categoryID: UUID? = nil, template: ReferenceType = .general, favorite: Bool = false, pinned: Bool = false, tagIDs: [UUID] = [], collectionID: UUID? = nil) {
        var initial = reference ?? ReferenceItem(categoryID: categoryID ?? UUID(), type: template)
        if reference == nil { initial.isFavorite = favorite; initial.isPinned = pinned; initial.tagIDs = tagIDs }
        _draft = State(initialValue: initial)
        existing = reference != nil; initialCategory = categoryID
        self.collectionID = collectionID
    }
    private func field(_ key: String) -> Binding<String> { Binding(get: { draft.fields[key] ?? "" }, set: { draft.fields[key] = $0 }) }
    private var validMeasurements: Bool {
        guard draft.type.usesDimensions else { return true }
        return draft.type.fields.allSatisfy { key in
            let text = (draft.fields[key] ?? "").trimmed
            guard !text.isEmpty else { return true }
            guard let number = Double(text.replacingOccurrences(of: ",", with: ".")) else { return false }
            return number.isFinite && number >= 0
        }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { templatePicker = true } label: {
                        HStack(spacing: 12) { IconTile(icon: draft.type.icon, color: VaultStyle.gold, size: 43); VStack(alignment: .leading, spacing: 4) { Text(draft.type.rawValue).font(.system(.body, design: .serif)).foregroundStyle(VaultStyle.ivory); Text("CHOOSE YOUR TEMPLATE").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1.5).foregroundStyle(VaultStyle.gold) }; Spacer(); Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(VaultStyle.gold) }.padding(.vertical, 10)
                    }.buttonStyle(.plain)
                }.listRowBackground(VaultStyle.midnight)
                Section("The essentials") {
                    TextField("Title (required)", text: $draft.title, axis: .vertical).lineLimit(1...3).accessibilityIdentifier("referenceTitle")
                    TextField("Primary value", text: $draft.value, axis: .vertical).lineLimit(1...4).accessibilityIdentifier("referenceValue")
                    Picker("Category", selection: $draft.categoryID) { ForEach(store.categories) { Text($0.name).tag($0.id) } }
                }
                if let similar = store.similar(to: draft.title, excluding: draft.id) {
                    Section {
                        Label("Similar reference found", systemImage: "square.on.square").font(.subheadline.weight(.medium))
                        Text(similar.title).font(.subheadline).foregroundStyle(VaultStyle.secondary)
                        Text("You can still save this as a separate reference.").font(.caption).foregroundStyle(VaultStyle.secondary)
                    }
                }
                if !draft.type.fields.isEmpty {
                    Section(draft.type.usesDimensions ? "Measurements" : "\(draft.type.rawValue) details") {
                        ForEach(draft.type.fields, id: \.self) { key in
                            if draft.type.usesDimensions { measurementRow(key) }
                            else { TextField(key, text: field(key), axis: .vertical).lineLimit(1...5) }
                        }
                        if draft.type.usesDimensions { NavigationLink(destination: UnitConverterView()) { Label("Convert Units", systemImage: "arrow.left.arrow.right") } }
                    }
                    if !validMeasurements { Text("Enter a valid, nonnegative number for each measurement, or leave it blank.").font(.caption).foregroundStyle(.red) }
                }
                if [.device, .appliance, .part, .consumable, .paint, .model, .serial, .battery].contains(draft.type) {
                    Section("Product details") {
                        TextField("Manufacturer / brand", text: $draft.manufacturer)
                        if draft.type != .paint { TextField("Model number", text: $draft.model).textInputAutocapitalization(.never) }
                        if [.device, .appliance, .serial].contains(draft.type) { TextField("Serial number", text: $draft.serial).textInputAutocapitalization(.never) }
                    }
                }
                Section("Notes") {
                    TextField("Useful context for later…", text: $draft.notes, axis: .vertical).lineLimit(4...12)
                }
                Section("Supporting photos") {
                    NavigationLink(destination: PhotosEditView(photos: $draft.photos)) {
                        HStack(spacing: 12) {
                            IconTile(icon: "photo.on.rectangle", size: 34)
                            Text(draft.photos.isEmpty ? "Add Photos" : "Manage Photos (\(draft.photos.count))")
                            Spacer()
                            if let data = draft.photos.first?.imageData, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill().frame(width: 34, height: 34).clipShape(RoundedRectangle(cornerRadius: 6)) }
                        }
                    }
                }
                Section("Organize") {
                    Toggle(isOn: $draft.isFavorite) { Label("Favorite", systemImage: "star") }
                    Toggle(isOn: $draft.isPinned) { Label("Pin to Home", systemImage: "pin") }
                    DisclosureGroup("Tags (\(draft.tagIDs.count))") {
                        ForEach(store.data.tags) { tag in
                            Toggle(isOn: Binding(get: { draft.tagIDs.contains(tag.id) }, set: { value in if value { draft.tagIDs.append(tag.id) } else { draft.tagIDs.removeAll { $0 == tag.id } } })) { TagPill(tag: tag) }
                        }
                        Button("Create Tag") { createTag = true }
                    }
                    Button { related = true } label: { HStack { Label("Related References", systemImage: "link"); Spacer(); Text("\(draft.relatedIDs.count)").foregroundStyle(VaultStyle.secondary) } }
                }
                Section {
                    DisclosureGroup("More Details", isExpanded: $advanced) {
                        TextField("Secondary value", text: $draft.secondaryValue, axis: .vertical)
                        TextField("Description", text: $draft.description, axis: .vertical).lineLimit(2...5)
                        if ![.device, .appliance, .part, .consumable, .paint, .model, .serial, .battery].contains(draft.type) { TextField("Manufacturer / brand", text: $draft.manufacturer) }
                        if ![.device, .appliance, .part, .consumable, .model, .serial, .battery].contains(draft.type) { TextField("Model number", text: $draft.model) }
                        if ![.device, .appliance, .serial].contains(draft.type) { TextField("Serial number", text: $draft.serial) }
                        TextField("Location", text: $draft.location)
                        TextField("Website / source", text: $draft.website).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        Picker("Primary value unit", selection: $draft.unit) { Text("None").tag(""); ForEach(MeasurementUnit.allCases) { Text($0.rawValue).tag($0.rawValue) } }
                    }
                }
                Section("Custom fields") {
                    ForEach(draft.fields.keys.filter { !draft.type.fields.contains($0) }.sorted(), id: \.self) { key in
                        VStack(alignment: .leading, spacing: 5) { Text(key).font(.caption).foregroundStyle(VaultStyle.secondary); TextField("Value", text: field(key), axis: .vertical) }
                            .swipeActions { Button("Delete", role: .destructive) { draft.fields.removeValue(forKey: key); draft.measurementUnits.removeValue(forKey: key) } }
                    }
                    Button { customField = true } label: { Label("Add Custom Field", systemImage: "plus") }
                }
            }.vaultBackground().dismissKeyboardOnScroll().navigationTitle(existing ? "Edit Reference" : "New Reference").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if baseline != draft { discard = true } else { dismiss() } } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { if store.save(draft, collectionID: collectionID) { dismiss() } }.disabled(draft.title.trimmed.isEmpty || !validMeasurements).accessibilityIdentifier("saveReference") }
                }
                .onAppear {
                    if baseline == nil {
                        if store.category(draft.categoryID) == nil, let id = initialCategory ?? store.categories.first?.id { draft.categoryID = id }
                        baseline = draft
                    }
                }
                .interactiveDismissDisabled(baseline != nil && baseline != draft)
                .confirmationDialog("Discard changes?", isPresented: $discard, titleVisibility: .visible) { Button("Discard Changes", role: .destructive) { dismiss() } }
                .sheet(isPresented: $templatePicker) { TemplatePickerView(selection: $draft.type) }
                .sheet(isPresented: $createTag) { TagEditor() }
                .sheet(isPresented: $related) { ReferenceSelectionView(title: "Related References", excluded: [draft.id], selected: Set(draft.relatedIDs)) { draft.relatedIDs = Array($0); return true } }
                .sheet(isPresented: $customField) { CustomFieldView(existingNames: Set(draft.fields.keys).union(draft.type.fields)) { name, value in draft.fields[name] = value } }
        }
    }
    private func measurementRow(_ key: String) -> some View {
        HStack {
            Text(key).font(.subheadline).frame(minWidth: 70, alignment: .leading)
            TextField("Optional", text: field(key)).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
            let defaultUnit = key == "Weight" ? "kg" : key == "Volume" ? "L" : "cm"
            let units = MeasurementUnit.allCases.filter { key == "Custom measurement" || (key == "Weight" ? $0.family == 1 : key == "Volume" ? $0.family == 2 : $0.family == 0) }
            Picker("\(key) unit", selection: Binding(get: { draft.measurementUnits[key] ?? defaultUnit }, set: { draft.measurementUnits[key] = $0 })) { ForEach(units) { Text($0.rawValue).tag($0.rawValue) } }.labelsHidden().fixedSize()
        }.onChange(of: draft.fields[key]) { value in if let value, !value.isEmpty, draft.measurementUnits[key] == nil { draft.measurementUnits[key] = key == "Weight" ? "kg" : key == "Volume" ? "L" : "cm" } }
    }
}

struct QuickAddView: View {
    @EnvironmentObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var value = ""
    @State private var categoryID: UUID?
    @State private var discard = false
    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Title (required)", text: $title); TextField("Value", text: $value, axis: .vertical) }
                Section { Picker("Category", selection: $categoryID) { ForEach(store.categories) { Text($0.name).tag(Optional($0.id)) } } }
                if let match = store.similar(to: title, excluding: UUID()) { Section("Similar reference found") { Text(match.title).font(.subheadline); Text("You can still save this reference.").font(.caption).foregroundStyle(VaultStyle.secondary) } }
                Section { Text("Just the essentials. Add photos, notes and more whenever you need.").font(.subheadline).foregroundStyle(VaultStyle.secondary) }.listRowBackground(Color.clear)
            }.vaultBackground().navigationTitle("Quick Add").navigationBarTitleDisplayMode(.inline)
                .onAppear { if categoryID == nil { categoryID = store.categories.first?.id } }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if !title.isEmpty || !value.isEmpty { discard = true } else { dismiss() } } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") {
                        guard let categoryID else { return }
                        var reference = ReferenceItem(categoryID: categoryID); reference.title = title; reference.value = value
                        if store.save(reference) { dismiss() }
                    }.disabled(title.trimmed.isEmpty || categoryID == nil) }
                }
                .interactiveDismissDisabled(!title.isEmpty || !value.isEmpty)
                .confirmationDialog("Discard this reference?", isPresented: $discard, titleVisibility: .visible) { Button("Discard", role: .destructive) { dismiss() } }
        }.presentationDetents([.medium, .large])
    }
}

struct CustomFieldView: View {
    @Environment(\.dismiss) private var dismiss
    let existingNames: Set<String>
    let save: (String, String) -> Void
    @State private var name = ""
    @State private var value = ""
    var body: some View {
        NavigationStack {
            Form { TextField("Field name", text: $name); TextField("Value", text: $value, axis: .vertical) }
                .vaultBackground().navigationTitle("Custom Field").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Add") { save(name.trimmed, value); dismiss() }.disabled(name.trimmed.isEmpty || existingNames.contains { $0.searchKey == name.trimmed.searchKey }) }
                }
        }.presentationDetents([.medium, .large])
    }
}

struct TemplatePickerView: View {
    @EnvironmentObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: ReferenceType
    var body: some View {
        NavigationStack {
            List(ReferenceType.allCases.filter { !store.settings.hiddenTemplates.contains($0) || $0 == selection }) { type in
                Button { selection = type; dismiss() } label: {
                    HStack(spacing: 13) { IconTile(icon: type.icon); VStack(alignment: .leading, spacing: 5) { Text(type.rawValue).font(.subheadline.weight(.medium)); Text(type.summary).font(.caption).foregroundStyle(VaultStyle.secondary) }; Spacer(); if selection == type { Image(systemName: "checkmark") } }.padding(.vertical, 6)
                }.buttonStyle(.plain)
            }.vaultBackground().navigationTitle("Choose Template").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

struct UnitConverterView: View {
    @EnvironmentObject var store: VaultStore
    @State private var value = ""
    @State private var from: MeasurementUnit = .cm
    @State private var to: MeasurementUnit = .m
    private var result: String? {
        guard let input = Double(value.trimmed.replacingOccurrences(of: ",", with: ".")), input.isFinite, input >= 0,
              let converted = from.convert(input, to: to), converted.isFinite else { return nil }
        return converted.formatted(.number.precision(.significantDigits(1...12)).grouping(.never))
    }
    var body: some View {
        Form {
            Section("Convert a measurement") {
                TextField("Value", text: $value).keyboardType(.decimalPad)
                Picker("From", selection: $from) { ForEach(MeasurementUnit.allCases) { Text($0.rawValue).tag($0) } }
                Picker("To", selection: $to) { ForEach(MeasurementUnit.allCases.filter { $0.family == from.family }) { Text($0.rawValue).tag($0) } }
            }
            Section("Result") {
                if let result {
                    Button { store.copy("\(result) \(to.rawValue)") } label: { HStack { Text("\(result) \(to.rawValue)").font(.title2.weight(.medium)); Spacer(); Image(systemName: "doc.on.doc") }.padding(.vertical, 12) }
                    Button("Swap Units") { let previous = from; from = to; to = previous; value = result }
                } else { Text(value.isEmpty ? "Enter a value to convert." : "Enter a valid, nonnegative number.").foregroundStyle(VaultStyle.secondary) }
            }
        }.vaultBackground().navigationTitle("Unit Converter").navigationBarTitleDisplayMode(.inline)
            .onChange(of: from) { unit in if to.family != unit.family { to = MeasurementUnit.allCases.first { $0.family == unit.family && $0 != unit } ?? unit } }
    }
}
