import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: VaultStore
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 27) {
                VStack(alignment: .leading, spacing: 21) {
                    HStack(spacing: 16) {
                        BrandMark(size: 55)
                        VStack(alignment: .leading, spacing: 7) {
                            VaultEyebrow(text: "Diamond Luck", color: VaultStyle.gold)
                            Text("Considered.\nDown to the details.").font(.system(size: 24, weight: .regular, design: .serif)).foregroundStyle(VaultStyle.ivory)
                        }
                        Spacer(minLength: 0)
                    }
                    Rectangle().fill(VaultStyle.gold.opacity(0.25)).frame(height: 0.7)
                    HStack {
                        Label("Stored on your device", systemImage: "iphone").font(.system(size: 11, weight: .light))
                        Spacer()
                        Text("\(store.references.count) REFERENCES").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1)
                    }.foregroundStyle(VaultStyle.ivory.opacity(0.55))
                }.padding(22).background(VaultStyle.midnight, in: RoundedRectangle(cornerRadius: 22)).overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(VaultStyle.gold.opacity(0.25), lineWidth: 0.7) }
                VStack(alignment: .leading, spacing: 12) {
                    VaultEyebrow(text: "01 / Make it yours")
                    VStack(spacing: 0) {
                        settingsLink("Appearance", subtitle: "Theme, density & reference style", icon: "circle.lefthalf.filled", destination: AppearanceSettingsView())
                        Divider().padding(.leading, 70)
                        settingsLink("Customize Home", subtitle: "Arrange your personal dashboard", icon: "square.grid.2x2", destination: HomeCustomizationView())
                    }.vaultPanel()
                }
                VStack(alignment: .leading, spacing: 12) {
                    VaultEyebrow(text: "02 / The finer details")
                    VStack(spacing: 0) {
                        settingsLink("App Behavior", subtitle: "History, feedback & shortcuts", icon: "slider.horizontal.3", destination: BehaviorSettingsView())
                        Divider().padding(.leading, 70)
                        settingsLink("Manage Templates", subtitle: "A starting point for every detail", icon: "rectangle.stack", destination: ManageTemplatesView())
                    }.vaultPanel()
                }
                VStack(alignment: .leading, spacing: 12) {
                    VaultEyebrow(text: "03 / Your library")
                    VStack(spacing: 0) {
                        settingsLink("Backup & Restore", subtitle: "Keep a complete copy of your vault", icon: "externaldrive", destination: BackupView())
                        Divider().padding(.leading, 70)
                        settingsLink("Export Data", subtitle: "Beautifully portable information", icon: "square.and.arrow.up", destination: ExportView())
                        Divider().padding(.leading, 70)
                        settingsLink("Statistics", subtitle: "Your collection at a glance", icon: "chart.bar", destination: StatisticsView())
                        Divider().padding(.leading, 70)
                        settingsLink("Data Management", subtitle: "Manage your local library", icon: "tray.full", destination: DataManagementView())
                    }.vaultPanel()
                }
            }.padding(22).padding(.bottom, 20)
        }.background(VaultStyle.background).navigationTitle("Settings")
    }
    private func settingsLink<Destination: View>(_ title: String, subtitle: String, icon: String, destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                IconTile(icon: icon, size: 39)
                VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(.body, design: .serif)).foregroundStyle(VaultStyle.ink); Text(subtitle).font(.system(size: 10)).foregroundStyle(VaultStyle.secondary) }
                Spacer(minLength: 2)
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .light)).foregroundStyle(VaultStyle.secondary)
            }.padding(16).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

struct AppearanceSettingsView: View {
    @EnvironmentObject var store: VaultStore
    private func setting(_ key: WritableKeyPath<AppSettings, String>) -> Binding<String> { Binding(get: { store.settings[keyPath: key] }, set: { value in store.setSettings { $0[keyPath: key] = value } }) }
    var body: some View {
        Form {
            Section("Theme") { Picker("Theme", selection: setting(\.theme)) { ForEach(["System", "Light", "Dark"], id: \.self) { Text($0).tag($0) } }.pickerStyle(.inline).labelsHidden() }
            Section("List Density") { Picker("List Density", selection: setting(\.density)) { Text("Comfortable").tag("Comfortable"); Text("Compact").tag("Compact") }.pickerStyle(.segmented).labelsHidden() }
            Section("Default Reference View") { Picker("Reference View", selection: setting(\.referenceView)) { Text("List").tag("List"); Text("Cards").tag("Cards") }.pickerStyle(.segmented).labelsHidden() }
        }.vaultBackground().navigationTitle("Appearance").navigationBarTitleDisplayMode(.inline)
    }
}

struct BehaviorSettingsView: View {
    @EnvironmentObject var store: VaultStore
    private func setting(_ key: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> { Binding(get: { store.settings[keyPath: key] }, set: { value in store.setSettings { $0[keyPath: key] = value } }) }
    private func visible(_ section: HomeSection) -> Binding<Bool> { Binding(get: { !store.settings.hiddenSections.contains(section) }, set: { value in store.setSettings { if value { $0.hiddenSections.removeAll { $0 == section } } else if !$0.hiddenSections.contains(section) { $0.hiddenSections.append(section) } } }) }
    var body: some View {
        Form {
            Section("Library") {
                Toggle("Show Recently Viewed", isOn: setting(\.trackHistory))
                Toggle("Show Favorites on Home", isOn: visible(.favorites))
                Toggle("Show Pinned References", isOn: visible(.pinned))
            }
            Section("Feedback") { Toggle("Copy Confirmation", isOn: setting(\.copyConfirmation)); Toggle("Haptic Feedback", isOn: setting(\.haptics)) }
            Section { NavigationLink(destination: ReferenceListView(title: "Recently Viewed", scope: .history)) { Label("Recently Viewed", systemImage: "clock") } } footer: { Text("Viewing history stays on this device. Turning history off stops recording new views; clear existing history from Data Management.") }
        }.vaultBackground().navigationTitle("App Behavior").navigationBarTitleDisplayMode(.inline)
    }
}

struct HomeCustomizationView: View {
    @EnvironmentObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            Section {
                ForEach(store.settings.homeOrder) { section in
                    Toggle(isOn: Binding(get: { !store.settings.hiddenSections.contains(section) }, set: { visible in store.setSettings { settings in
                        if visible { settings.hiddenSections.removeAll { $0 == section } }
                        else if !settings.hiddenSections.contains(section) { settings.hiddenSections.append(section) }
                    } })) { Label(section.rawValue, systemImage: section.icon) }
                }.onMove { source, destination in store.setSettings { $0.homeOrder.move(fromOffsets: source, toOffset: destination) } }
            } footer: { Text("Choose the sections you use and drag them into your preferred order. Empty reference sections appear once they contain items.") }
        }.vaultBackground().environment(\.editMode, .constant(.active)).navigationTitle("Customize Home").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}

struct StatisticsView: View {
    @EnvironmentObject var store: VaultStore
    private var mostUsed: VaultCategory? { store.categories.max { a, b in store.references.filter { $0.categoryID == a.id }.count < store.references.filter { $0.categoryID == b.id }.count } }
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your library, in detail.").font(.system(.title2, design: .serif))
                    Text("A simple overview of what you’ve saved.").font(.subheadline).foregroundStyle(VaultStyle.secondary)
                }.padding(.vertical, 15)
            }.listRowBackground(Color.clear)
            Section("Library") {
                NavigationLink(destination: ReferenceListView(title: "All References")) { stat("Total References", store.references.count, "tray.full") }
                NavigationLink(destination: ReferenceListView(title: "Favorites", scope: .favorites)) { stat("Favorites", store.references.filter(\.isFavorite).count, "star") }
                NavigationLink(destination: CategoriesView()) { stat("Categories", store.categories.count, "square.grid.2x2") }
                NavigationLink(destination: CollectionsView()) { stat("Collections", store.data.collections.count, "square.stack") }
                stat("References with Photos", store.references.filter { !$0.photos.isEmpty }.count, "photo")
                stat("Added in the Last 7 Days", store.matching(filter: ReferenceFilter(recentAdded: true)).count, "clock.badge.plus")
            }
            Section("Most Used Category") {
                if !store.references.isEmpty, let category = mostUsed { NavigationLink(destination: CategoryDetailView(categoryID: category.id)) { Label(category.name, systemImage: category.icon) } }
                else { Text("Save a reference to get started.").foregroundStyle(VaultStyle.secondary) }
            }
        }.vaultBackground().navigationTitle("Statistics").navigationBarTitleDisplayMode(.inline)
    }
    private func stat(_ title: String, _ count: Int, _ icon: String) -> some View { HStack { Label(title, systemImage: icon); Spacer(); Text("\(count)").monospacedDigit().foregroundStyle(VaultStyle.secondary) }.padding(.vertical, 5) }
}

struct DataManagementView: View {
    @EnvironmentObject var store: VaultStore
    @State private var delete = false
    @State private var clear = false
    var body: some View {
        Form {
            Section {
                NavigationLink(destination: BackupView()) { Label("Backup & Restore", systemImage: "externaldrive") }
                NavigationLink(destination: ExportView()) { Label("Export Data", systemImage: "square.and.arrow.up") }
            }
            Section {
                Button("Clear Recently Viewed", role: .destructive) { clear = true }.disabled(store.data.history.isEmpty)
            } footer: { Text("Clearing history keeps all references and photos.") }
            Section {
                Button("Delete All Data", role: .destructive) { delete = true }
            } footer: { Text("Removes all references, photos, custom categories, tags, collections and history, and resets settings. This cannot be undone. Export a backup first if you want to keep a copy.") }
        }.vaultBackground().navigationTitle("Data Management").navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Delete all library data?", isPresented: $delete, titleVisibility: .visible) { Button("Delete All Data", role: .destructive) { if store.reset() { store.notify("Library cleared") } } } message: { Text("Your entire library will be permanently removed from this device.") }
            .confirmationDialog("Clear recently viewed history?", isPresented: $clear, titleVisibility: .visible) { Button("Clear History", role: .destructive) { store.commit { $0.history = [] } } }
    }
}

struct ManageTemplatesView: View {
    @EnvironmentObject var store: VaultStore
    var body: some View {
        List {
            Section {
                ForEach(ReferenceType.allCases) { type in
                    NavigationLink(destination: TemplateDetailView(type: type)) {
                        HStack(spacing: 13) {
                            IconTile(icon: type.icon, size: 37)
                            Text(type.rawValue).font(.subheadline)
                            Spacer()
                            if store.settings.hiddenTemplates.contains(type) { Text("Hidden").font(.caption).foregroundStyle(VaultStyle.secondary) }
                        }.padding(.vertical, 4)
                    }
                }
            } footer: { Text("Choose which templates appear when creating a reference. Existing references keep their details.") }
        }.vaultBackground().navigationTitle("Manage Templates").navigationBarTitleDisplayMode(.inline)
    }
}

struct TemplateDetailView: View {
    @EnvironmentObject var store: VaultStore
    let type: ReferenceType
    @State private var create = false
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 13) { IconTile(icon: type.icon, size: 52); Text(type.summary).foregroundStyle(VaultStyle.secondary) }.padding(.vertical, 10)
                Toggle("Show in Template Picker", isOn: Binding(get: { !store.settings.hiddenTemplates.contains(type) }, set: { visible in store.setSettings { settings in
                    if visible { settings.hiddenTemplates.removeAll { $0 == type } }
                    else if !settings.hiddenTemplates.contains(type) { settings.hiddenTemplates.append(type) }
                } })).disabled(type == .general)
            }
            Section("Fields") {
                Text("Title"); Text("Primary value"); Text("Category")
                ForEach(type.fields, id: \.self) { Text($0) }
                Text("Notes, photos, tags and optional details").foregroundStyle(VaultStyle.secondary)
            }
            Button { create = true } label: { Label("Create \(type.rawValue)", systemImage: "plus") }
        }.vaultBackground().navigationTitle(type.rawValue).navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $create) { ReferenceEditor(template: type) }
    }
}
