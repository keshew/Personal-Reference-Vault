import Foundation
import SwiftUI
import UIKit
import Combine
import CryptoKit

@MainActor
final class VaultStore: ObservableObject {
    @Published private(set) var data: VaultData
    @Published var errorMessage: String?
    @Published var toast: String?
    private(set) var loadFailed = false
    private let fileURL: URL
    private let photosDirectory: URL
    private var toastTask: Task<Void, Never>?
    let clientID: UUID

    init(directory: URL? = nil, defaults: UserDefaults = .standard) {
        let key = "vault.localClientID"
        if let saved = defaults.string(forKey: key), let id = UUID(uuidString: saved) { clientID = id }
        else { let id = UUID(); clientID = id; defaults.set(id.uuidString, forKey: key) }
        let root = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("PersonalReferenceVault", isDirectory: true)
        fileURL = root.appendingPathComponent("vault.json")
        photosDirectory = root.appendingPathComponent("Photos", isDirectory: true)
        data = VaultData()
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let decoder = JSONDecoder()
                let folder = photosDirectory
                decoder.dataDecodingStrategy = .custom { decoder in
                    let value = try decoder.singleValueContainer().decode(String.self)
                    if value.hasPrefix("vault-photo:") {
                        let name = String(value.dropFirst("vault-photo:".count))
                        guard name.count == 68, name.hasSuffix(".jpg"), name.dropLast(4).allSatisfy({ $0.isHexDigit && $0.isASCII }) else { throw VaultError.invalid("A photo filename is invalid.") }
                        return try Data(contentsOf: folder.appendingPathComponent(name))
                    }
                    guard let bytes = Data(base64Encoded: value) else { throw VaultError.invalid("A photo could not be decoded.") }
                    return bytes
                }
                let decoded = try decoder.decode(VaultData.self, from: Data(contentsOf: fileURL))
                try Self.validate(decoded)
                data = decoded
            }
        } catch {
            loadFailed = true
            errorMessage = "Your saved library could not be opened. It has been kept intact. Restore a backup in Settings, or try opening the app again. \(error.localizedDescription)"
        }
    }

    var references: [ReferenceItem] { data.references }
    var categories: [VaultCategory] { data.categories }
    var settings: AppSettings { data.settings }
    func item(_ id: UUID) -> ReferenceItem? { references.first { $0.id == id } }
    func category(_ id: UUID) -> VaultCategory? { categories.first { $0.id == id } }
    func categoryName(_ id: UUID) -> String { category(id)?.name ?? "Other" }

    @discardableResult
    func commit(allowRecovery: Bool = false, _ change: (inout VaultData) -> Void) -> Bool {
        guard !loadFailed || allowRecovery else {
            errorMessage = "The saved library needs recovery. Restore a backup or reset the library in Settings before making changes."
            return false
        }
        var next = data
        change(&next)
        do {
            try Self.validate(next, checkingPhotos: false)
            let folder = photosDirectory
            var usedPhotos: Set<String> = []
            let encoder = JSONEncoder()
            encoder.dataEncodingStrategy = .custom { bytes, encoder in
                let filename = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() + ".jpg"
                let destination = folder.appendingPathComponent(filename)
                if allowRecovery || !FileManager.default.fileExists(atPath: destination.path) {
                    try bytes.write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                }
                usedPhotos.insert(filename)
                var container = encoder.singleValueContainer()
                try container.encode("vault-photo:" + filename)
            }
            let encoded = try encoder.encode(next)
            try encoded.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            data = next
            loadFailed = false
            if let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
                for file in files where file.pathExtension == "jpg" && !usedPhotos.contains(file.lastPathComponent) { try? FileManager.default.removeItem(at: file) }
            }
            return true
        } catch {
            errorMessage = "Changes could not be saved. Your previous library is still available. \(error.localizedDescription)"
            return false
        }
    }

    static func validate(_ data: VaultData, checkingPhotos: Bool = true) throws {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw VaultError.invalid(message) }
        }
        try require(data.version == 1, "This library version is not supported.")
        try require(!data.categories.isEmpty, "The library must contain at least one category.")
        let refs = Set(data.references.map(\.id)), cats = Set(data.categories.map(\.id)), tags = Set(data.tags.map(\.id))
        try require(refs.count == data.references.count && cats.count == data.categories.count && tags.count == data.tags.count, "The library contains duplicate identifiers.")
        try require(Set(data.collections.map(\.id)).count == data.collections.count, "Collections contain duplicate identifiers.")
        try require(data.categories.allSatisfy { !$0.name.trimmed.isEmpty } && data.tags.allSatisfy { !$0.name.trimmed.isEmpty } && data.collections.allSatisfy { !$0.name.trimmed.isEmpty }, "An organizer name is empty.")
        for item in data.references {
            try require(!item.title.trimmed.isEmpty && cats.contains(item.categoryID), "A reference has a missing title or category.")
            try require(Set(item.tagIDs).isSubset(of: tags), "A reference contains an unknown tag.")
            try require(Set(item.tagIDs).count == item.tagIDs.count && Set(item.relatedIDs).count == item.relatedIDs.count, "A reference contains duplicate links.")
            try require(Set(item.relatedIDs).isSubset(of: refs) && !item.relatedIDs.contains(item.id), "A related reference is invalid.")
            try require(Set(item.photos.map(\.id)).count == item.photos.count, "Photos contain duplicate identifiers.")
            if checkingPhotos { try require(item.photos.allSatisfy { UIImage(data: $0.imageData) != nil }, "A photo could not be read.") }
        }
        try require(data.collections.allSatisfy { Set($0.referenceIDs).isSubset(of: refs) }, "A collection contains an unknown reference.")
        try require(data.history.allSatisfy { refs.contains($0.referenceID) } && Set(data.history.map(\.referenceID)).count == data.history.count, "Recent history is invalid.")
        try require(Set(data.settings.homeOrder) == Set(HomeSection.allCases) && data.settings.homeOrder.count == HomeSection.allCases.count, "The dashboard order is invalid.")
        try require(["System", "Light", "Dark"].contains(data.settings.theme) && ["Comfortable", "Compact"].contains(data.settings.density) && ["List", "Cards"].contains(data.settings.referenceView), "Appearance settings are invalid.")
    }

    @discardableResult
    func save(_ reference: ReferenceItem, collectionID: UUID? = nil) -> Bool {
        var reference = reference
        reference.title = reference.title.trimmed
        reference.updatedAt = Date()
        let result = commit { state in
            if let i = state.references.firstIndex(where: { $0.id == reference.id }) { state.references[i] = reference }
            else { state.references.append(reference) }
            if let collectionID, let i = state.collections.firstIndex(where: { $0.id == collectionID }), !state.collections[i].referenceIDs.contains(reference.id) { state.collections[i].referenceIDs.append(reference.id) }
        }
        if result { feedback(); notify("Reference saved") }
        return result
    }

    func update(_ id: UUID, _ change: (inout ReferenceItem) -> Void) {
        guard var reference = item(id) else { return }
        change(&reference)
        reference.updatedAt = Date()
        if commit({ state in
            if let index = state.references.firstIndex(where: { $0.id == id }) { state.references[index] = reference }
        }) { feedback() }
    }

    @discardableResult
    func delete(_ ids: Set<UUID>) -> Bool {
        commit { state in
            state.references.removeAll { ids.contains($0.id) }
            state.history.removeAll { ids.contains($0.referenceID) }
            for i in state.references.indices { state.references[i].relatedIDs.removeAll { ids.contains($0) } }
            for i in state.collections.indices { state.collections[i].referenceIDs.removeAll { ids.contains($0) } }
        }
    }

    @discardableResult
    func duplicate(_ item: ReferenceItem) -> UUID? {
        var copy = item
        copy.id = UUID(); copy.title += " Copy"; copy.createdAt = Date(); copy.updatedAt = Date()
        copy.photos = copy.photos.map { PhotoAttachment(imageData: $0.imageData, caption: $0.caption) }
        copy.isPinned = false
        return save(copy) ? copy.id : nil
    }

    func viewed(_ id: UUID) {
        guard settings.trackHistory, item(id) != nil else { return }
        commit { state in
            state.history.removeAll { $0.referenceID == id }
            state.history.insert(RecentEntry(referenceID: id, viewedAt: Date()), at: 0)
            state.history = Array(state.history.prefix(100))
        }
    }

    func setSettings(_ change: (inout AppSettings) -> Void) { commit { change(&$0.settings) } }
    func feedback() { if settings.haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() } }
    func copy(_ text: String) {
        UIPasteboard.general.string = text
        feedback()
        if settings.copyConfirmation { notify("Copied") }
    }
    func notify(_ message: String) {
        toastTask?.cancel()
        withAnimation { toast = message }
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { self?.toast = nil }
        }
    }

    func matching(query: String = "", filter: ReferenceFilter = ReferenceFilter(), sort: ReferenceSort = .newest) -> [ReferenceItem] {
        let terms = query.searchKey.split(whereSeparator: \.isWhitespace).map(String.init)
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let result = references.filter { item in
            if let id = filter.categoryID, item.categoryID != id { return false }
            if let id = filter.tagID, !item.tagIDs.contains(id) { return false }
            if let type = filter.type, item.type != type { return false }
            if filter.favorites && !item.isFavorite || filter.hasPhoto && item.photos.isEmpty { return false }
            if filter.recentAdded && item.createdAt < weekAgo || filter.recentUpdated && item.updatedAt < weekAgo { return false }
            let tagNames = data.tags.filter { item.tagIDs.contains($0.id) }.map(\.name)
            let text = ([item.title, item.type.rawValue, categoryName(item.categoryID)] + item.filledFields.map(\.1) + tagNames + item.photos.map(\.caption)).joined(separator: " ").searchKey
            return terms.allSatisfy { text.contains($0) }
        }
        let viewedDates = Dictionary(uniqueKeysWithValues: data.history.map { ($0.referenceID, $0.viewedAt) })
        return result.sorted { a, b in
            switch sort {
            case .name: return a.title.localizedStandardCompare(b.title) == .orderedAscending
            case .reverseName: return a.title.localizedStandardCompare(b.title) == .orderedDescending
            case .newest: return a.createdAt > b.createdAt
            case .oldest: return a.createdAt < b.createdAt
            case .updated: return a.updatedAt > b.updatedAt
            case .viewed: return (viewedDates[a.id] ?? .distantPast) > (viewedDates[b.id] ?? .distantPast)
            case .favorites: return a.isFavorite == b.isFavorite ? a.title.localizedStandardCompare(b.title) == .orderedAscending : a.isFavorite
            }
        }
    }

    func similar(to title: String, excluding id: UUID) -> ReferenceItem? {
        let key = title.trimmed.searchKey
        guard key.count >= 3 else { return nil }
        let words = Set(key.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        return references.first {
            guard $0.id != id else { return false }
            let other = $0.title.searchKey
            let otherWords = Set(other.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
            let union = words.union(otherWords)
            return key == other || other.contains(key) || key.contains(other) || (!union.isEmpty && Double(words.intersection(otherWords).count) / Double(union.count) >= 0.7)
        }
    }

    func text(for item: ReferenceItem) -> String {
        let tags = data.tags.filter { item.tagIDs.contains($0.id) }.map(\.name).joined(separator: ", ")
        let collections = data.collections.filter { $0.referenceIDs.contains(item.id) }.map(\.name).joined(separator: ", ")
        let related = item.relatedIDs.compactMap { self.item($0)?.title }.joined(separator: ", ")
        var lines = [item.title, "Category: \(categoryName(item.categoryID))", "Type: \(item.type.rawValue)"]
        lines += item.filledFields.map { "\($0.0): \($0.1)" }
        if !tags.isEmpty { lines.append("Tags: \(tags)") }
        if !collections.isEmpty { lines.append("Collections: \(collections)") }
        if !related.isEmpty { lines.append("Related: \(related)") }
        if !item.photos.isEmpty {
            lines.append("Photos: \(item.photos.count)")
            lines += item.photos.enumerated().compactMap { index, photo in photo.caption.isEmpty ? nil : "Photo \(index + 1): \(photo.caption)" }
        }
        if item.isFavorite { lines.append("Favorite: Yes") }
        if item.isPinned { lines.append("Pinned: Yes") }
        lines.append("Created: \(item.createdAt.formatted(date: .abbreviated, time: .shortened))")
        lines.append("Edited: \(item.updatedAt.formatted(date: .abbreviated, time: .shortened))")
        return lines.joined(separator: "\n")
    }

    func backupData() throws -> Data {
        guard !loadFailed else { throw VaultError.invalid("Recover the library before creating a backup.") }
        var snapshot = data
        snapshot.lastBackupDate = Date()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(BackupEnvelope(data: snapshot))
    }

    func readBackup(_ url: URL) throws -> BackupEnvelope {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let bytes = try Data(contentsOf: url)
        let backup = try JSONDecoder().decode(BackupEnvelope.self, from: bytes)
        guard backup.format == "PersonalReferenceVault", backup.version == 1 else { throw VaultError.invalid("This is not a supported Diamond Luck backup.") }
        try Self.validate(backup.data)
        return backup
    }

    func restore(_ backup: BackupEnvelope) -> Bool {
        do {
            guard backup.format == "PersonalReferenceVault", backup.version == 1 else { throw VaultError.invalid("This backup format is not supported.") }
            try Self.validate(backup.data)
        } catch { errorMessage = "The backup could not be restored. \(error.localizedDescription)"; return false }
        let restored = commit(allowRecovery: true) { $0 = backup.data }
        if restored { notify("Library restored") }
        return restored
    }

    func reset() -> Bool { commit(allowRecovery: true) { $0 = VaultData() } }
}

enum VaultError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { switch self { case .invalid(let message): return message } }
}
