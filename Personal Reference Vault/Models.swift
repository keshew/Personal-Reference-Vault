import Foundation

enum ReferenceType: String, Codable, CaseIterable, Identifiable {
    case general = "General Reference", measurement = "Measurement", clothing = "Clothing Size"
    case shoes = "Shoe Size", paint = "Color / Paint", device = "Device Information"
    case appliance = "Appliance", part = "Replacement Part", consumable = "Consumable"
    case cable = "Cable / Connector", battery = "Battery", furniture = "Furniture"
    case room = "Room Measurement", material = "Material", model = "Model Number"
    case serial = "Serial Number", specification = "Product Specification", custom = "Custom"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .general, .custom: return "square.stack.3d.up"
        case .measurement, .room: return "ruler"
        case .clothing: return "tshirt"
        case .shoes: return "shoeprints.fill"
        case .paint: return "paintbrush.pointed"
        case .device: return "desktopcomputer"
        case .appliance: return "washer"
        case .part: return "gearshape.2"
        case .consumable: return "drop"
        case .cable: return "cable.connector"
        case .battery: return "battery.100percent"
        case .furniture: return "chair.lounge"
        case .material: return "square.3.layers.3d"
        case .model: return "number"
        case .serial: return "barcode"
        case .specification: return "list.bullet.rectangle"
        }
    }
    var fields: [String] {
        switch self {
        case .measurement, .room, .furniture: return ["Length", "Width", "Height", "Diameter", "Depth", "Weight", "Volume", "Custom measurement"]
        case .clothing: return ["Size", "Fit", "Chest", "Waist", "Inseam"]
        case .shoes: return ["Size", "Sizing system", "Width", "Fit"]
        case .paint: return ["Color name", "Color code", "Room", "Finish"]
        case .device: return ["Purchase notes", "Accessories"]
        case .appliance: return ["Settings", "Accessories", "Purchase notes"]
        case .part: return ["Part number", "Compatible with"]
        case .consumable: return ["Replacement model", "Compatible with"]
        case .cable: return ["Connector A", "Connector B", "Length", "Standard"]
        case .battery: return ["Battery type", "Voltage", "Capacity"]
        case .material: return ["Material code", "Finish", "Dimensions"]
        case .specification: return ["Specifications", "Compatibility"]
        default: return []
        }
    }
    var summary: String {
        switch self {
        case .measurement, .room: return "Dimensions, units and useful measurements."
        case .paint: return "Keep the exact color, brand and finish."
        case .device, .appliance: return "Models, serial numbers and settings."
        case .clothing, .shoes: return "Sizes and fit details, always within reach."
        case .part, .consumable: return "Find the right replacement next time."
        default: return "Save useful details in a structured reference."
        }
    }
    var usesDimensions: Bool { [.measurement, .room, .furniture].contains(self) }
}

enum VaultColor: String, Codable, CaseIterable, Identifiable {
    case teal, blue, amber, green, rose, slate
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct VaultCategory: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var icon: String
    var color: VaultColor = .teal
    var isBuiltIn = false
    static func defaults() -> [VaultCategory] {
        let entries: [(String, String, VaultColor)] = [
            ("Personal", "person.crop.square", .teal), ("Clothing", "tshirt", .rose),
            ("Home", "house", .amber), ("Furniture", "chair.lounge", .amber),
            ("Appliances", "washer", .blue), ("Electronics", "desktopcomputer", .blue),
            ("Measurements", "ruler", .teal), ("Colors & Materials", "paintpalette", .rose),
            ("Parts", "gearshape.2", .slate), ("Consumables", "drop", .green),
            ("Cables", "cable.connector", .slate), ("Batteries", "battery.100percent", .green),
            ("Tools", "wrench.and.screwdriver", .amber), ("Office", "paperclip", .blue),
            ("Other", "square.grid.2x2", .slate)
        ]
        return entries.map { VaultCategory(name: $0.0, icon: $0.1, color: $0.2, isBuiltIn: true) }
    }
}

struct VaultTag: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var color: VaultColor = .teal
}

struct VaultCollection: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var description = ""
    var icon = "square.stack"
    var color: VaultColor = .teal
    var referenceIDs: [UUID] = []
}

struct PhotoAttachment: Identifiable, Codable, Equatable {
    var id = UUID()
    var imageData: Data
    var caption = ""
}

struct ReferenceItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title = ""
    var value = ""
    var secondaryValue = ""
    var categoryID: UUID
    var type: ReferenceType = .general
    var description = ""
    var notes = ""
    var tagIDs: [UUID] = []
    var photos: [PhotoAttachment] = []
    var isFavorite = false
    var isPinned = false
    var createdAt = Date()
    var updatedAt = Date()
    var relatedIDs: [UUID] = []
    var unit = ""
    var website = ""
    var manufacturer = ""
    var model = ""
    var serial = ""
    var location = ""
    var fields: [String: String] = [:]
    var measurementUnits: [String: String] = [:]
    var displayValue: String { value.isEmpty ? (model.isEmpty ? type.rawValue : model) : value + (unit.isEmpty ? "" : " \(unit)") }
    var filledFields: [(String, String)] {
        let standard = [("Value", value), ("Secondary value", secondaryValue), ("Unit", unit),
                        ("Description", description), ("Manufacturer", manufacturer), ("Model", model),
                        ("Serial number", serial), ("Location", location), ("Website / source", website)]
        let keys = type.fields + fields.keys.filter { !type.fields.contains($0) }.sorted()
        let custom = keys.map { key -> (String, String) in
            let value = fields[key] ?? ""
            let suffix = measurementUnits[key].map { " \($0)" } ?? ""
            return (key, value.isEmpty ? "" : value + suffix)
        }
        return (standard + custom + [("Notes", notes)]).filter { !$0.1.trimmed.isEmpty }
    }
}

struct RecentEntry: Identifiable, Codable, Equatable {
    var id: UUID { referenceID }
    var referenceID: UUID
    var viewedAt: Date
}

enum HomeSection: String, Codable, CaseIterable, Identifiable {
    case pinned = "Pinned", favorites = "Favorites", viewed = "Recently Viewed"
    case added = "Recently Added", categories = "Categories", collections = "Collections", statistics = "Statistics"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .pinned: return "pin"
        case .favorites: return "star"
        case .viewed: return "clock"
        case .added: return "clock.badge.plus"
        case .categories: return "square.grid.2x2"
        case .collections: return "square.stack"
        case .statistics: return "chart.bar"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var theme = "System"
    var density = "Comfortable"
    var referenceView = "List"
    var trackHistory = true
    var copyConfirmation = true
    var haptics = true
    var homeOrder = HomeSection.allCases
    var hiddenSections: [HomeSection] = []
    var hiddenTemplates: [ReferenceType] = []
}

struct VaultData: Codable, Equatable {
    var version = 1
    var references: [ReferenceItem] = []
    var categories = VaultCategory.defaults()
    var tags: [VaultTag] = []
    var collections: [VaultCollection] = []
    var history: [RecentEntry] = []
    var settings = AppSettings()
    var lastBackupDate: Date?
}

struct BackupEnvelope: Codable {
    var format = "PersonalReferenceVault"
    var version = 1
    var createdAt = Date()
    var data: VaultData
}

enum ReferenceSort: String, CaseIterable, Identifiable {
    case name = "Name A–Z", reverseName = "Name Z–A", newest = "Newest", oldest = "Oldest"
    case updated = "Recently Updated", viewed = "Recently Viewed", favorites = "Favorites First"
    var id: String { rawValue }
}

struct ReferenceFilter: Equatable {
    var categoryID: UUID?
    var tagID: UUID?
    var type: ReferenceType?
    var favorites = false
    var hasPhoto = false
    var recentAdded = false
    var recentUpdated = false
    var isActive: Bool { categoryID != nil || tagID != nil || type != nil || favorites || hasPhoto || recentAdded || recentUpdated }
}

enum MeasurementUnit: String, CaseIterable, Identifiable {
    case mm, cm, m, inch = "in", ft, g, kg, ml, liter = "L"
    var id: String { rawValue }
    var family: Int {
        switch self { case .mm, .cm, .m, .inch, .ft: return 0; case .g, .kg: return 1; case .ml, .liter: return 2 }
    }
    var factor: Double {
        switch self { case .mm: return 0.001; case .cm: return 0.01; case .m: return 1
        case .inch: return 0.0254; case .ft: return 0.3048; case .g: return 1; case .kg: return 1000
        case .ml: return 1; case .liter: return 1000 }
    }
    func convert(_ value: Double, to target: MeasurementUnit) -> Double? {
        guard family == target.family else { return nil }
        return value * factor / target.factor
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var searchKey: String { folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX")) }
}
