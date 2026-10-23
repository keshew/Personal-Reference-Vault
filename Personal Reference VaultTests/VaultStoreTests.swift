import XCTest
import UIKit
import PDFKit
@testable import Personal_Reference_Vault

@MainActor
final class VaultStoreTests: XCTestCase {
    private func makeStore() throws -> (VaultStore, URL, UserDefaults) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "VaultTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { try? FileManager.default.removeItem(at: directory); UserDefaults.standard.removePersistentDomain(forName: suite) }
        return (VaultStore(directory: directory, defaults: defaults), directory, defaults)
    }
    private func reference(_ store: VaultStore, title: String = "Kitchen filter", value: String = "DA29") -> ReferenceItem {
        var item = ReferenceItem(categoryID: store.categories[0].id); item.title = title; item.value = value; return item
    }

    func testClientIDIsGeneratedAndStable() async throws {
        let (store, directory, defaults) = try makeStore()
        let reopened = VaultStore(directory: directory, defaults: defaults)
        XCTAssertEqual(store.clientID, reopened.clientID)
        XCTAssertNotEqual(store.clientID, try makeStore().0.clientID)
        XCTAssertNotNil(UUID(uuidString: store.clientID.uuidString))
    }

    func testPersistenceAfterReopening() async throws {
        let (store, directory, defaults) = try makeStore()
        let item = reference(store)
        XCTAssertTrue(store.save(item))
        XCTAssertEqual(VaultStore(directory: directory, defaults: defaults).item(item.id)?.title, item.title)
    }

    func testEmptyTitleIsRejectedWithoutChangingLibrary() async throws {
        let (store, _, _) = try makeStore()
        let before = store.data
        XCTAssertFalse(store.save(reference(store, title: "  \n  ")))
        XCTAssertEqual(store.data, before)
    }

    func testSearchFindsEverySupportedFieldAndCombinesTerms() async throws {
        let (store, _, _) = try makeStore()
        let tag = VaultTag(name: "Seasonal")
        XCTAssertTrue(store.commit { $0.tags.append(tag) })
        var item = reference(store, title: "Café machine")
        item.notes = "Use descaling tablets"; item.manufacturer = "Acme"; item.model = "Coffee Pro"; item.serial = "SN1024"; item.tagIDs = [tag.id]
        item.fields["Setting"] = "Gentle mode"
        XCTAssertTrue(store.save(item))
        for query in ["CAFE", "DA29", "descaling", "Acme", "coffee pro", "SN1024", "seasonal", "Personal", "gentle", "cafe seasonal sn1024"] {
            XCTAssertEqual(store.matching(query: query).map(\.id), [item.id], query)
        }
        XCTAssertTrue(store.matching(query: "missing").isEmpty)
    }

    func testFiltersAndSorting() async throws {
        let (store, _, _) = try makeStore()
        var older = reference(store, title: "Zebra"); older.createdAt = Date(timeIntervalSince1970: 1)
        var newer = reference(store, title: "Alpha"); newer.isFavorite = true; newer.type = .paint
        XCTAssertTrue(store.save(older)); XCTAssertTrue(store.save(newer))
        XCTAssertEqual(store.matching(filter: ReferenceFilter(favorites: true)).map(\.id), [newer.id])
        XCTAssertEqual(store.matching(filter: ReferenceFilter(recentAdded: true)).map(\.id), [newer.id])
        XCTAssertEqual(store.matching(filter: ReferenceFilter(type: .paint)).map(\.id), [newer.id])
        XCTAssertEqual(store.matching(sort: .name).map(\.title), ["Alpha", "Zebra"])
        XCTAssertEqual(store.matching(sort: .oldest).map(\.id), [older.id, newer.id])
    }

    func testDeletionCleansCollectionsRelationshipsAndHistory() async throws {
        let (store, _, _) = try makeStore()
        let first = reference(store)
        XCTAssertTrue(store.save(first))
        var second = reference(store, title: "Coffee machine"); second.relatedIDs = [first.id]
        XCTAssertTrue(store.save(second))
        store.commit { $0.collections.append(VaultCollection(name: "Kitchen", referenceIDs: [first.id, second.id])) }
        store.viewed(first.id)
        XCTAssertTrue(store.delete([first.id]))
        XCTAssertTrue(try XCTUnwrap(store.item(second.id)).relatedIDs.isEmpty)
        XCTAssertEqual(store.data.collections[0].referenceIDs, [second.id])
        XCTAssertTrue(store.data.history.isEmpty)
    }

    func testHistoryIsUniqueAndCanBeDisabled() async throws {
        let (store, _, _) = try makeStore()
        let item = reference(store); XCTAssertTrue(store.save(item))
        store.viewed(item.id); store.viewed(item.id)
        XCTAssertEqual(store.data.history.count, 1)
        store.setSettings { $0.trackHistory = false }
        store.commit { $0.history = [] }; store.viewed(item.id)
        XCTAssertTrue(store.data.history.isEmpty)
    }

    func testDuplicateHasIndependentIdentityAndPhotos() async throws {
        let (store, _, _) = try makeStore()
        var item = reference(store); item.isPinned = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 4, height: 4)) }
        item.photos = [PhotoAttachment(imageData: try XCTUnwrap(image.jpegData(compressionQuality: 0.8)), caption: "Label")]
        XCTAssertTrue(store.save(item))
        let id = try XCTUnwrap(store.duplicate(item)); let copy = try XCTUnwrap(store.item(id))
        XCTAssertNotEqual(copy.id, item.id); XCTAssertNotEqual(copy.photos[0].id, item.photos[0].id)
        XCTAssertEqual(copy.photos[0].imageData, item.photos[0].imageData); XCTAssertFalse(copy.isPinned)
    }

    func testBackupRoundTripAndRestore() async throws {
        let (store, directory, _) = try makeStore()
        XCTAssertTrue(store.save(reference(store)))
        let snapshot = store.data
        let file = directory.appendingPathComponent("backup.json"); try store.backupData().write(to: file)
        let backup = try store.readBackup(file)
        XCTAssertTrue(store.reset()); XCTAssertTrue(store.references.isEmpty)
        XCTAssertTrue(store.restore(backup)); XCTAssertEqual(store.references, snapshot.references)
        XCTAssertEqual(store.categories, snapshot.categories)
        XCTAssertNotNil(store.data.lastBackupDate)
    }

    func testInvalidBackupIsRejected() async throws {
        let (store, directory, _) = try makeStore()
        var invalid = BackupEnvelope(data: store.data); invalid.version = 99
        let file = directory.appendingPathComponent("invalid.json"); try JSONEncoder().encode(invalid).write(to: file)
        XCTAssertThrowsError(try store.readBackup(file))
        var broken = store.data
        var item = reference(store); item.categoryID = UUID(); broken.references = [item]
        XCTAssertThrowsError(try VaultStore.validate(broken))
    }

    func testCorruptionPreservesOriginalFileUntilRecovery() async throws {
        let (_, directory, defaults) = try makeStore()
        let file = directory.appendingPathComponent("vault.json")
        let corrupt = Data("not a library".utf8); try corrupt.write(to: file)
        let broken = VaultStore(directory: directory, defaults: defaults)
        XCTAssertTrue(broken.loadFailed); XCTAssertFalse(broken.save(reference(broken)))
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
        XCTAssertTrue(broken.restore(BackupEnvelope(data: VaultData())))
        XCTAssertFalse(broken.loadFailed)
    }

    func testMeasurementsStayInCompatibleFamilies() async throws {
        XCTAssertEqual(try XCTUnwrap(MeasurementUnit.cm.convert(120, to: .m)), 1.2, accuracy: 0.000001)
        XCTAssertEqual(try XCTUnwrap(MeasurementUnit.inch.convert(1, to: .cm)), 2.54, accuracy: 0.000001)
        XCTAssertEqual(MeasurementUnit.kg.convert(2, to: .g), 2000)
        XCTAssertEqual(MeasurementUnit.liter.convert(3, to: .ml), 3000)
        XCTAssertNil(MeasurementUnit.cm.convert(12, to: .kg))
    }

    func testDuplicateSuggestionIsNonblocking() async throws {
        let (store, _, _) = try makeStore()
        let item = reference(store, title: "Living Room Wall Paint"); XCTAssertTrue(store.save(item))
        XCTAssertEqual(store.similar(to: "Living room wall paint", excluding: UUID())?.id, item.id)
        XCTAssertNil(store.similar(to: item.title, excluding: item.id))
        XCTAssertTrue(store.save(reference(store, title: item.title)))
        XCTAssertEqual(store.references.count, 2)
    }

    func testCSVQuotesNewlinesAndNeutralizesFormulas() async throws {
        let (store, _, _) = try makeStore()
        var item = reference(store, title: "=SUM(1,2)", value: "A \"quoted\" value"); item.notes = "Line 1\nLine 2"
        XCTAssertTrue(store.save(item))
        let csv = try XCTUnwrap(String(data: ExportBuilder.make(items: [item], format: .csv, store: store, title: "Test"), encoding: .utf8))
        XCTAssertTrue(csv.contains("\"'=SUM(1,2)\"")); XCTAssertTrue(csv.contains("\"A \"\"quoted\"\" value\"")); XCTAssertTrue(csv.contains("Line 1\nLine 2"))
    }

    func testJSONExportAndLongPDFContainSavedInformation() async throws {
        let (store, _, _) = try makeStore()
        var item = reference(store); item.notes = String(repeating: "Useful details for the next replacement. ", count: 1300)
        item.fields["Length"] = "120"; item.measurementUnits["Length"] = "cm"
        XCTAssertTrue(store.save(item))
        let bytes = try ExportBuilder.make(items: [item], format: .json, store: store, title: "Test")
        let decoded = try JSONDecoder().decode(ReferenceExport.self, from: bytes)
        XCTAssertEqual(decoded.references, [item]); XCTAssertEqual(decoded.categories.count, 1)
        let pdf = try XCTUnwrap(PDFDocument(data: ExportBuilder.make(items: [item], format: .pdf, store: store, title: "Test")))
        XCTAssertGreaterThan(pdf.pageCount, 2)
        let text = (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined()
        XCTAssertTrue(text.contains(item.title)); XCTAssertTrue(text.contains("120 cm"))
        XCTAssertEqual(text.components(separatedBy: "Useful details").count - 1, 1300)
    }
}
