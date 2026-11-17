import SwiftUI
import UniformTypeIdentifiers
import UIKit
import PDFKit

struct VaultDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .plainText, .commaSeparatedText, .pdf, .data] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else { throw VaultError.invalid("Select a regular file.") }
        data = contents
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case text = "Plain Text", csv = "CSV", json = "JSON", pdf = "PDF Summary"
    var id: String { rawValue }
    var fileExtension: String { switch self { case .text: return "txt"; case .csv: return "csv"; case .json: return "json"; case .pdf: return "pdf" } }
    var contentType: UTType { switch self { case .text: return .plainText; case .csv: return .commaSeparatedText; case .json: return .json; case .pdf: return .pdf } }
}

enum ExportScope: String, CaseIterable, Identifiable {
    case all = "All References", category = "Category", collection = "Collection", selected = "Selected References"
    var id: String { rawValue }
}

struct ReferenceExport: Codable {
    var app = "Diamond Luck"
    var version = 1
    var exportedAt = Date()
    var references: [ReferenceItem]
    var categories: [VaultCategory]
    var tags: [VaultTag]
    var collections: [VaultCollection]
}

@MainActor enum ExportBuilder {
    static func make(items: [ReferenceItem], format: ExportFormat, store: VaultStore, title: String) throws -> Data {
        let text = ([title, "Diamond Luck · \(items.count) references", Date().formatted(date: .long, time: .omitted)] + items.map { store.text(for: $0) }).joined(separator: "\n\n")
        switch format {
        case .text: return Data(text.utf8)
        case .json:
            let ids = Set(items.map(\.id)), catIDs = Set(items.map(\.categoryID)), tagIDs = Set(items.flatMap(\.tagIDs))
            let collections = store.data.collections.filter { !Set($0.referenceIDs).intersection(ids).isEmpty }.map { c in var c = c; c.referenceIDs.removeAll { !ids.contains($0) }; return c }
            let export = ReferenceExport(references: items, categories: store.categories.filter { catIDs.contains($0.id) }, tags: store.data.tags.filter { tagIDs.contains($0.id) }, collections: collections)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; return try encoder.encode(export)
        case .csv:
            let header = ["Title", "Value", "Secondary Value", "Category", "Type", "Description", "Notes", "Unit", "Manufacturer", "Model", "Serial Number", "Location", "Website / Source", "Tags", "Favorite", "Pinned", "Created", "Updated", "Custom Fields", "Collections", "Related References", "Photo Count", "Photo Captions", "Measurement Units"]
            let rows = try items.map { item -> [String] in
                let custom = try JSONSerialization.data(withJSONObject: item.fields, options: [.sortedKeys])
                let measurementUnits = try JSONSerialization.data(withJSONObject: item.measurementUnits, options: [.sortedKeys])
                return [item.title, item.value, item.secondaryValue, store.categoryName(item.categoryID), item.type.rawValue, item.description, item.notes, item.unit, item.manufacturer, item.model, item.serial, item.location, item.website,
                        store.data.tags.filter { item.tagIDs.contains($0.id) }.map(\.name).joined(separator: "; "), item.isFavorite ? "Yes" : "No", item.isPinned ? "Yes" : "No", item.createdAt.ISO8601Format(), item.updatedAt.ISO8601Format(), String(data: custom, encoding: .utf8) ?? "{}", store.data.collections.filter { $0.referenceIDs.contains(item.id) }.map(\.name).joined(separator: "; "), item.relatedIDs.compactMap { store.item($0)?.title }.joined(separator: "; "), String(item.photos.count), item.photos.map(\.caption).joined(separator: "; "), String(data: measurementUnits, encoding: .utf8) ?? "{}"]
            }
            func cell(_ value: String) -> String {
                let safe = ["=", "+", "-", "@", "\t", "\r"].contains(where: { value.trimmed.hasPrefix($0) || value.hasPrefix($0) }) ? "'" + value : value
                return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return Data(("\u{feff}" + ([header] + rows).map { $0.map(cell).joined(separator: ",") }.joined(separator: "\r\n")).utf8)
        case .pdf: return PDFSummary.render(title: title, items: items, store: store)
        }
    }
}

@MainActor enum PDFSummary {
    static func render(title: String, items: [ReferenceItem], store: VaultStore) -> Data {
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        return renderer.pdfData { context in
            var y: CGFloat = 0
            var page = 0
            let width: CGFloat = 499
            func newPage() {
                context.beginPage(); page += 1
                UIColor(red: 0.14, green: 0.43, blue: 0.41, alpha: 1).setFill(); context.fill(CGRect(x: 48, y: 40, width: 26, height: 3))
                ("PERSONAL REFERENCE VAULT" as NSString).draw(at: CGPoint(x: 48, y: 55), withAttributes: [.font: UIFont.systemFont(ofSize: 9, weight: .semibold), .foregroundColor: UIColor.darkGray])
                ("\(page)" as NSString).draw(at: CGPoint(x: 530, y: 800), withAttributes: [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.gray])
                y = 91
            }
            func draw(_ text: String, font: UIFont, color: UIColor = .black, spacing: CGFloat = 9) {
                let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 3; paragraph.lineBreakMode = .byWordWrapping
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
                let attributed = NSAttributedString(string: text, attributes: attributes)
                let storage = NSTextStorage(attributedString: attributed)
                let layout = NSLayoutManager(); storage.addLayoutManager(layout)
                var glyph = 0
                while glyph < layout.numberOfGlyphs {
                    if y > 750 { newPage() }
                    let container = NSTextContainer(size: CGSize(width: width, height: 775 - y)); container.lineFragmentPadding = 0
                    layout.addTextContainer(container)
                    let range = layout.glyphRange(for: container)
                    guard range.length > 0 else { newPage(); continue }
                    layout.drawBackground(forGlyphRange: range, at: CGPoint(x: 48, y: y))
                    layout.drawGlyphs(forGlyphRange: range, at: CGPoint(x: 48, y: y))
                    y += ceil(layout.usedRect(for: container).height) + spacing
                    glyph = NSMaxRange(range)
                    if glyph < layout.numberOfGlyphs { newPage() }
                }
            }
            newPage()
            draw(title, font: .systemFont(ofSize: 26, weight: .semibold), spacing: 10)
            draw("\(items.count) references · \(Date().formatted(date: .long, time: .omitted))", font: .systemFont(ofSize: 10), color: .darkGray, spacing: 24)
            for item in items {
                if y > 670 { newPage() }
                draw(item.title, font: .systemFont(ofSize: 17, weight: .semibold), spacing: 8)
                draw(store.categoryName(item.categoryID) + " · " + item.type.rawValue, font: .systemFont(ofSize: 9), color: .darkGray, spacing: 13)
                for (label, value) in item.filledFields {
                    draw(label.uppercased(), font: .systemFont(ofSize: 8, weight: .semibold), color: .darkGray, spacing: 4)
                    draw(value, font: .systemFont(ofSize: 11), spacing: 12)
                }
                let tags = store.data.tags.filter { item.tagIDs.contains($0.id) }.map(\.name).joined(separator: ", ")
                if !tags.isEmpty { draw("Tags: " + tags, font: .systemFont(ofSize: 10), color: .darkGray) }
                let related = item.relatedIDs.compactMap { store.item($0)?.title }.joined(separator: ", ")
                if !related.isEmpty { draw("Related: " + related, font: .systemFont(ofSize: 10), color: .darkGray) }
                if let photo = item.photos.first, let image = UIImage(data: photo.imageData) {
                    if y > 620 { newPage() }
                    let ratio = min(150 / image.size.width, 120 / image.size.height)
                    image.draw(in: CGRect(x: 48, y: y, width: image.size.width * ratio, height: image.size.height * ratio)); y += image.size.height * ratio + 10
                    if !photo.caption.isEmpty { draw(photo.caption, font: .systemFont(ofSize: 9), color: .darkGray) }
                }
                y += 18
                if y < 775 { UIColor(white: 0.87, alpha: 1).setFill(); context.fill(CGRect(x: 48, y: y, width: width, height: 0.5)); y += 22 }
            }
        }
    }
}

struct ExportView: View {
    @EnvironmentObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    private let presented: Bool
    @State private var scope: ExportScope
    @State private var categoryID: UUID?
    @State private var collectionID: UUID?
    @State private var selected: Set<UUID>
    @State private var format: ExportFormat = .text
    @State private var select = false
    @State private var preview: ExportPreviewPayload?
    init(initialIDs: Set<UUID>? = nil, initialCollection: UUID? = nil, presented: Bool = false) {
        self.presented = presented
        _scope = State(initialValue: initialIDs != nil ? .selected : initialCollection != nil ? .collection : .all)
        _selected = State(initialValue: initialIDs ?? [])
        _collectionID = State(initialValue: initialCollection)
    }
    private var items: [ReferenceItem] {
        let sorted = store.matching(sort: .name)
        switch scope {
        case .all: return sorted
        case .category: return sorted.filter { $0.categoryID == categoryID }
        case .collection: return sorted.filter { store.data.collections.first { $0.id == collectionID }?.referenceIDs.contains($0.id) == true }
        case .selected: return sorted.filter { selected.contains($0.id) }
        }
    }
    private var title: String {
        if scope == .collection { return store.data.collections.first { $0.id == collectionID }?.name ?? "Collection" }
        if scope == .category, let categoryID { return store.categoryName(categoryID) }
        return "Reference Library"
    }
    var body: some View {
        Form {
            Section("Include") {
                Picker("References", selection: $scope) { ForEach(ExportScope.allCases) { Text($0.rawValue).tag($0) } }
                if scope == .category { Picker("Category", selection: $categoryID) { ForEach(store.categories) { Text($0.name).tag(Optional($0.id)) } } }
                if scope == .collection {
                    if store.data.collections.isEmpty { Text("Create a collection to export it.").font(.subheadline).foregroundStyle(VaultStyle.secondary) }
                    else { Picker("Collection", selection: $collectionID) { ForEach(store.data.collections) { Text($0.name).tag(Optional($0.id)) } } }
                }
                if scope == .selected { Button("Choose References (\(selected.count))") { select = true } }
            }
            Section("Format") { Picker("File Format", selection: $format) { ForEach(ExportFormat.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.inline).labelsHidden() }
            Section {
                LabeledContent("References to export", value: "\(items.count)")
                Button { prepare() } label: { Label("Preview Export", systemImage: "doc.text.magnifyingglass") }.disabled(items.isEmpty)
            } footer: { Text("Export a readable summary or structured data. Use Backup & Restore for a complete, restorable copy of your library.") }
        }.vaultBackground().navigationTitle("Export Data").navigationBarTitleDisplayMode(.inline)
            .toolbar { if presented { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } } }
            .onAppear { if categoryID == nil { categoryID = store.categories.first?.id }; if collectionID == nil { collectionID = store.data.collections.first?.id } }
            .sheet(isPresented: $select) { ReferenceSelectionView(title: "Select References", selected: selected) { selected = $0; return true } }
            .sheet(item: $preview) { ExportPreviewView(payload: $0) }
    }
    private func prepare() {
        do { let bytes = try ExportBuilder.make(items: items, format: format, store: store, title: title); preview = ExportPreviewPayload(data: bytes, format: format, count: items.count, title: title) }
        catch { store.errorMessage = "Export could not be created. \(error.localizedDescription)" }
    }
}

struct ExportPreviewPayload: Identifiable { let id = UUID(); let data: Data; let format: ExportFormat; let count: Int; let title: String }

struct ExportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let payload: ExportPreviewPayload
    @State private var save = false
    @State private var share: SharePayload?
    @State private var shareFolder: URL?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Group {
                if payload.format == .pdf { PDFPreview(data: payload.data) }
                else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            let text = String(data: payload.data, encoding: .utf8) ?? ""
                            if text.count > 30_000 { Text("Preview shows the first 30,000 characters. The saved file includes all information and photos.").font(.caption).foregroundStyle(VaultStyle.secondary) }
                            Text(String(text.prefix(30_000))).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(22)
                    }.background(VaultStyle.background)
                }
            }.navigationTitle("Export Preview").navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) { Text(payload.format.rawValue).font(.subheadline.weight(.semibold)); Text("\(payload.count) references · \(ByteCountFormatter.string(fromByteCount: Int64(payload.data.count), countStyle: .file))").font(.caption).foregroundStyle(VaultStyle.secondary) }; Spacer()
                        Button("Save") { save = true }.buttonStyle(.borderedProminent)
                        Button { shareFile() } label: { Image(systemName: "square.and.arrow.up") }.buttonStyle(.bordered).accessibilityLabel("Share Export")
                    }.padding(18).background(.regularMaterial)
                }
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .fileExporter(isPresented: $save, document: VaultDocument(data: payload.data), contentType: payload.format.contentType, defaultFilename: "Reference-Vault.\(payload.format.fileExtension)") { result in if case .failure(let failure) = result { error = failure.localizedDescription } }
                .sheet(item: $share, onDismiss: { if let shareFolder { try? FileManager.default.removeItem(at: shareFolder); self.shareFolder = nil } }) { ActivitySheet(items: $0.items) }
                .alert("Export notice", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        }
    }
    private func shareFile() {
        do {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            shareFolder = folder
            let file = folder.appendingPathComponent("Reference-Vault.\(payload.format.fileExtension)")
            try payload.data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]); share = SharePayload(items: [file])
        } catch { self.error = error.localizedDescription }
    }
}

struct PDFPreview: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView { let view = PDFView(); view.autoScales = true; view.displayMode = .singlePageContinuous; view.document = PDFDocument(data: data); return view }
    func updateUIView(_ view: PDFView, context: Context) {}
}

struct BackupView: View {
    @EnvironmentObject var store: VaultStore
    @State private var document = VaultDocument()
    @State private var save = false
    @State private var importing = false
    @State private var backup: PendingBackup?
    @State private var backupDate: Date?
    @State private var error: String?
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    IconTile(icon: "externaldrive", size: 52)
                    Text("A copy you control.").font(.system(.title2, design: .serif))
                    Text("Save all references, photos, categories, tags, collections and settings in one local backup file.").font(.subheadline).foregroundStyle(VaultStyle.secondary)
                }.padding(.vertical, 12)
                LabeledContent("Last backup", value: store.data.lastBackupDate?.formatted(date: .abbreviated, time: .shortened) ?? "Not yet created")
            }
            Section {
                Button { create() } label: { Label("Create Backup", systemImage: "square.and.arrow.up") }.disabled(store.loadFailed)
                Button { importing = true } label: { Label("Restore Backup", systemImage: "arrow.counterclockwise") }
            } footer: { Text("Backups may contain personal information and photos. Save them somewhere you trust. Automatic cloud backup is not provided.") }
        }.vaultBackground().navigationTitle("Backup & Restore").navigationBarTitleDisplayMode(.inline)
            .fileExporter(isPresented: $save, document: document, contentType: .json, defaultFilename: "Reference-Vault-Backup-\(Date().formatted(.iso8601.year().month().day().dateSeparator(.dash))).json") { result in
                switch result { case .success: store.commit { $0.lastBackupDate = backupDate }; store.notify("Backup saved"); case .failure(let failure): error = failure.localizedDescription }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .data]) { result in
                do { let url = try result.get(); backup = PendingBackup(envelope: try store.readBackup(url)) }
                catch { self.error = "The backup could not be opened. \(error.localizedDescription)" }
            }
            .sheet(item: $backup) { pending in RestoreConfirmationView(backup: pending.envelope) }
            .alert("Backup notice", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
    private func create() {
        do { document = VaultDocument(data: try store.backupData()); backupDate = Date(); save = true }
        catch { self.error = error.localizedDescription }
    }
}

struct PendingBackup: Identifiable { let id = UUID(); let envelope: BackupEnvelope }

struct RestoreConfirmationView: View {
    @EnvironmentObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    let backup: BackupEnvelope
    @State private var acknowledged = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Replace your library", systemImage: "exclamationmark.triangle").font(.headline)
                    Text("Restoring replaces all current references, photos, categories, tags, collections and settings with this backup. Create a backup of your current library first if you want to keep it.").font(.subheadline).foregroundStyle(VaultStyle.secondary)
                }
                Section("Backup contents") {
                    LabeledContent("Created", value: backup.createdAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("References", value: "\(backup.data.references.count)")
                    LabeledContent("Photos", value: "\(backup.data.references.reduce(0) { $0 + $1.photos.count })")
                    LabeledContent("Collections", value: "\(backup.data.collections.count)")
                }
                Section { Toggle("I understand this replaces my current library", isOn: $acknowledged); Button("Restore Library", role: .destructive) { if store.restore(backup) { dismiss() } }.disabled(!acknowledged) }
            }.vaultBackground().navigationTitle("Restore Confirmation").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
