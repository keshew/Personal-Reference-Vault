import SwiftUI

struct ContentView: View {
    @StateObject private var store = VaultStore()
    @AppStorage("vault.onboarded") private var onboarded = false
    @State private var tab = 0

    var body: some View {
        ZStack(alignment: .top) {
            if onboarded {
                TabView(selection: $tab) {
                    NavigationStack { HomeView(selectedTab: $tab) }.tabItem { Label("Home", systemImage: "square.stack.3d.up") }.tag(0)
                    NavigationStack { CategoriesView() }.tabItem { Label("Categories", systemImage: "square.grid.2x2") }.tag(1)
                    NavigationStack { SearchView() }.tabItem { Label("Search", systemImage: "magnifyingglass") }.tag(2)
                    NavigationStack { SettingsView() }.tabItem { Label("Settings", systemImage: "slider.horizontal.3") }.tag(3)
                }
            } else { OnboardingView { withAnimation { onboarded = true } } }
            if let toast = store.toast {
                Label(toast, systemImage: "checkmark.circle.fill").font(.subheadline.weight(.medium))
                    .padding(.horizontal, 20).padding(.vertical, 13).background(.regularMaterial, in: Capsule())
                    .padding(.top, 8).transition(.move(edge: .top).combined(with: .opacity)).allowsHitTesting(false)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .environmentObject(store).tint(VaultStyle.accent)
        .preferredColorScheme(store.settings.theme == "System" ? nil : store.settings.theme == "Dark" ? .dark : .light)
        .background(LibraryNoticePresenter(message: $store.errorMessage).frame(width: 0, height: 0))
    }
}

struct OnboardingView: View {
    let complete: () -> Void
    @State private var page = 0
    private let titles = ["Keep Useful Details\nWithin Reach", "Organize Your\nReferences", "Find Anything\nQuickly", "Your Reference\nLibrary"]
    private let descriptions = [
        "Save measurements, model numbers, sizes, product details, color codes and other information you may need again.",
        "Use categories, tags and collections to keep everything easy to find.",
        "Search across your saved information and copy important values instantly.",
        "A quiet place for the details that matter. Stored on your device, ready whenever you need them."
    ]
    private let icons = ["rectangle.stack", "square.grid.2x2", "magnifyingglass", "bookmark"]
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) { BrandMark(size: 31); Text("REFERENCE VAULT").font(.caption.weight(.semibold)).tracking(2); Spacer() }.padding(26)
            TabView(selection: $page) {
                ForEach(0..<4) { i in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            OnboardingArtwork(icon: icons[i], index: i).padding(.vertical, 20)
                            Text("0\(i + 1) / THE EVERYDAY DETAILS").font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(VaultStyle.accent)
                            Text(titles[i]).font(.system(.largeTitle, design: .serif).weight(.medium)).foregroundStyle(VaultStyle.ink).fixedSize(horizontal: false, vertical: true)
                            Text(descriptions[i]).font(.body).foregroundStyle(VaultStyle.secondary).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                        }.padding(.horizontal, 28).padding(.bottom, 25)
                    }.tag(i)
                }
            }.tabViewStyle(.page(indexDisplayMode: .never))
            VStack(spacing: 23) {
                HStack(spacing: 7) { ForEach(0..<4) { i in Capsule().fill(i == page ? VaultStyle.accent : VaultStyle.line).frame(width: i == page ? 24 : 6, height: 6) } }
                Button { if page == 3 { complete() } else { withAnimation { page += 1 } } } label: {
                    HStack { Spacer(); Text(page == 3 ? "Get Started" : "Continue"); Spacer(); Image(systemName: "arrow.right") }.frame(maxWidth: .infinity)
                }.buttonStyle(VaultPrimaryButton())
                Label("Offline. No account needed.", systemImage: "iphone").font(.caption).foregroundStyle(VaultStyle.secondary)
            }.padding(.horizontal, 28).padding(.bottom, 22)
        }.background(VaultStyle.background)
    }
}

struct OnboardingArtwork: View {
    let icon: String
    let index: Int
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26).fill(LinearGradient(colors: [Color(red: 0.17, green: 0.27, blue: 0.22), VaultStyle.midnight], startPoint: .topLeading, endPoint: .bottomTrailing))
            VaultArtwork(size: 154).rotationEffect(.degrees(-3)).padding(.top, 3)
            VStack {
                HStack { VaultEyebrow(text: "The everyday collection", color: VaultStyle.gold); Spacer() }
                Spacer()
                HStack { Image(systemName: icon).font(.system(size: 15, weight: .light)); Spacer(); Text("0\(index + 1)").font(.system(size: 23, weight: .light, design: .serif)) }.foregroundStyle(VaultStyle.gold)
            }.padding(22)
        }.frame(height: 253).overlay { RoundedRectangle(cornerRadius: 26).strokeBorder(VaultStyle.gold.opacity(0.3), lineWidth: 0.7) }.accessibilityHidden(true)
    }
}

struct HomeView: View {
    @EnvironmentObject var store: VaultStore
    @Binding var selectedTab: Int
    @State private var add = false
    @State private var quick = false
    @State private var customize = false
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        VaultEyebrow(text: Date().formatted(.dateTime.month(.wide).day()))
                        Text("The Vault").font(.system(size: 37, weight: .regular, design: .serif)).foregroundStyle(VaultStyle.ink)
                    }
                    Spacer()
                    Button { customize = true } label: { Image(systemName: "slider.horizontal.3").font(.system(size: 16, weight: .light)).frame(width: 43, height: 43).vaultPanel(radius: 14) }.accessibilityLabel("Customize Home")
                }.padding(.top, 6)
                libraryHero
                Button { selectedTab = 2 } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass").font(.system(size: 17, weight: .light))
                        Text("Find something worth keeping").font(.system(size: 13))
                        Spacer(minLength: 0)
                        Image(systemName: "line.3.horizontal.decrease").font(.system(size: 12))
                    }.foregroundStyle(VaultStyle.secondary).padding(18).vaultPanel(radius: 15)
                }.buttonStyle(.plain)
                HStack(spacing: 12) {
                    actionTile(title: "New Reference", subtitle: "Give a detail a home", icon: "plus", primary: true) { add = true }.accessibilityIdentifier("addReference")
                    actionTile(title: "Quick Add", subtitle: "Capture the essentials", icon: "bolt", primary: false) { quick = true }
                }
                HStack(spacing: 0) {
                    shortcut("Favorites", icon: "star", destination: ReferenceListView(title: "Favorites", scope: .favorites))
                    Spacer(minLength: 5)
                    shortcut("Pinned", icon: "pin", destination: ReferenceListView(title: "Pinned References", scope: .pinned))
                    Spacer(minLength: 5)
                    shortcut("History", icon: "clock", destination: ReferenceListView(title: "Recently Viewed", scope: .history))
                }.padding(.vertical, 1)
                if store.loadFailed {
                    NavigationLink(destination: BackupView()) { Label("Open Backup & Restore to recover your library", systemImage: "exclamationmark.triangle") }.font(.subheadline)
                }
                ForEach(store.settings.homeOrder.filter { !store.settings.hiddenSections.contains($0) }) { section in homeSection(section) }
                HStack(spacing: 12) {
                    Rectangle().fill(VaultStyle.line).frame(height: 1)
                    Image(systemName: "rectangle.stack").font(.system(size: 13, weight: .ultraLight)).foregroundStyle(VaultStyle.gold)
                    Rectangle().fill(VaultStyle.line).frame(height: 1)
                }.padding(.top, 5)
                Button { customize = true } label: { VaultEyebrow(text: "Make this space yours", color: VaultStyle.accent).frame(maxWidth: .infinity) }.padding(.bottom, 5)
            }.padding(.horizontal, 22).padding(.bottom, 25)
        }.background(VaultStyle.background).navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { HStack(spacing: 8) { BrandMark(size: 25); Text("PERSONAL REFERENCE VAULT").font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(VaultStyle.ink) } }
            }
            .sheet(isPresented: $add) { ReferenceEditor() }
            .sheet(isPresented: $quick) { QuickAddView() }
            .sheet(isPresented: $customize) { NavigationStack { HomeCustomizationView() } }
    }

    private var libraryHero: some View {
        VStack(alignment: .leading, spacing: 21) {
            HStack {
                VaultEyebrow(text: "Your personal archive", color: VaultStyle.gold)
                Spacer()
                Circle().fill(Color(red: 0.57, green: 0.73, blue: 0.58)).frame(width: 4, height: 4)
                Text("ON DEVICE").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1).foregroundStyle(VaultStyle.ivory.opacity(0.5))
            }
            HStack(alignment: .center, spacing: 3) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("The details\nthat matter.").font(.system(size: 31, weight: .regular, design: .serif)).foregroundStyle(VaultStyle.ivory).fixedSize(horizontal: false, vertical: true)
                    Text("Thoughtfully collected.\nEffortlessly found.").font(.system(size: 11)).foregroundStyle(VaultStyle.ivory.opacity(0.52)).lineSpacing(4)
                }.frame(maxWidth: .infinity, alignment: .leading)
                VaultArtwork(size: 107).padding(.trailing, 1)
            }
            Rectangle().fill(VaultStyle.gold.opacity(0.23)).frame(height: 0.7)
            NavigationLink(destination: ReferenceListView(title: "All References", scope: .all)) {
                HStack(alignment: .center) {
                    Text(String(format: "%02d", store.references.count)).font(.system(size: 29, weight: .light, design: .serif)).foregroundStyle(VaultStyle.ivory)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("SAVED REFERENCES").font(.system(size: 8, weight: .semibold, design: .monospaced)).tracking(1.3)
                        Text(store.references.isEmpty ? "Your collection begins here" : "A little less to remember").font(.system(size: 10))
                    }.foregroundStyle(VaultStyle.ivory.opacity(0.48))
                    Spacer(minLength: 5)
                    Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .light)).foregroundStyle(VaultStyle.gold).frame(width: 33, height: 33).overlay(Circle().stroke(VaultStyle.gold.opacity(0.35), lineWidth: 0.7))
                }
            }.buttonStyle(.plain).accessibilityLabel("Open all references")
        }.padding(22)
            .background(LinearGradient(colors: [Color(red: 0.14, green: 0.23, blue: 0.19), VaultStyle.midnight], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(VaultStyle.gold.opacity(0.28), lineWidth: 0.7) }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: VaultStyle.midnight.opacity(0.18), radius: 20, x: 0, y: 10)
    }
    private func actionTile(title: String, subtitle: String, icon: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 13) {
                HStack { Image(systemName: icon).font(.system(size: 18, weight: .light)); Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 9)) }
                    .foregroundStyle(primary ? VaultStyle.gold : VaultStyle.accent)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 14, weight: .medium, design: .serif)).foregroundStyle(primary ? VaultStyle.ivory : VaultStyle.ink)
                    Text(subtitle).font(.system(size: 9)).foregroundStyle(primary ? VaultStyle.ivory.opacity(0.5) : VaultStyle.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(17)
                .background(primary ? VaultStyle.midnight : VaultStyle.surface, in: RoundedRectangle(cornerRadius: 17))
                .overlay { RoundedRectangle(cornerRadius: 17).strokeBorder(primary ? VaultStyle.gold.opacity(0.35) : VaultStyle.line, lineWidth: 0.7) }
        }.buttonStyle(.plain)
    }
    private func shortcut<Destination: View>(_ title: String, icon: String, destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 6) { Image(systemName: icon).font(.system(size: 11, weight: .light)); Text(title).font(.system(size: 11, weight: .medium)) }.foregroundStyle(VaultStyle.secondary).padding(.vertical, 7)
        }
    }

    @ViewBuilder private func homeSection(_ section: HomeSection) -> some View {
        switch section {
        case .pinned: referenceSection("Pinned References", scope: .pinned, items: store.references.filter(\.isPinned))
        case .favorites: referenceSection("Favorites", scope: .favorites, items: store.references.filter(\.isFavorite))
        case .viewed:
            if store.settings.trackHistory { referenceSection("Recently Viewed", scope: .history, items: store.data.history.compactMap { store.item($0.referenceID) }) }
        case .added: referenceSection("Recently Added", scope: .all, items: store.matching())
        case .categories:
            VStack(alignment: .leading, spacing: 16) {
                SectionHeading(title: "Categories", destination: CategoriesView())
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 11) {
                    ForEach(Array(store.categories.prefix(4))) { category in
                        NavigationLink(destination: CategoryDetailView(categoryID: category.id)) { CategoryCard(category: category) }.buttonStyle(.plain)
                    }
                }
            }
        case .collections:
            VStack(alignment: .leading, spacing: 16) {
                SectionHeading(title: "Collections", destination: CollectionsView())
                if store.data.collections.isEmpty {
                    NavigationLink(destination: CollectionsView()) {
                        HStack(spacing: 13) { IconTile(icon: "square.stack"); VStack(alignment: .leading, spacing: 4) { Text("Bring related details together").font(.subheadline.weight(.medium)); Text("Create your first collection").font(.caption).foregroundStyle(VaultStyle.secondary) }; Spacer(); Image(systemName: "plus").font(.subheadline) }.padding(16).background(VaultStyle.surface, in: RoundedRectangle(cornerRadius: 15))
                    }.buttonStyle(.plain)
                } else {
                    ForEach(Array(store.data.collections.prefix(3))) { collection in
                        NavigationLink(destination: CollectionDetailView(collectionID: collection.id)) { CollectionRow(collection: collection) }.buttonStyle(.plain)
                    }
                }
            }
        case .statistics:
            VStack(alignment: .leading, spacing: 16) {
                SectionHeading(title: "At a glance", destination: StatisticsView())
                HStack(spacing: 0) {
                    miniStat(store.references.count, "References")
                    Divider().frame(height: 34)
                    miniStat(store.references.filter(\.isFavorite).count, "Favorites")
                    Divider().frame(height: 34)
                    miniStat(store.references.filter { !$0.photos.isEmpty }.count, "With photos")
                }.padding(.vertical, 23).vaultPanel()
            }
        }
    }
    @ViewBuilder private func referenceSection(_ title: String, scope: ReferenceScope, items: [ReferenceItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(title: title, destination: ReferenceListView(title: title, scope: scope))
                VStack(spacing: 9) {
                    ForEach(Array(items.prefix(3))) { item in
                        NavigationLink(destination: ReferenceDetailView(referenceID: item.id)) { ReferenceRow(item: item, card: true) }.buttonStyle(.plain)
                    }
                }
            }
        }
    }
    private func miniStat(_ count: Int, _ name: String) -> some View {
        VStack(spacing: 6) { Text("\(count)").font(.system(size: 30, weight: .regular, design: .serif)).foregroundStyle(VaultStyle.ink); Text(name).font(.caption2).foregroundStyle(VaultStyle.secondary) }.frame(maxWidth: .infinity)
    }
}
