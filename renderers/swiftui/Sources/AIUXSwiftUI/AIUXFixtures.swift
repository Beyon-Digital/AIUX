import Foundation

// MARK: - Conformance fixture support
//
// The conformance catalog (`conformance/fixtures/*.json`, indexed by
// `manifest.txt`) is the shared contract between the Rust core and every
// renderer. `AIUXFixture` decodes a fixture file's event array for replay
// through any `AIUXSessionBackend`, and `AIUXSnapshot(fromPersistedJSON:)`
// (in AIUXProtocol.swift) decodes `conformance/expected/*.json` for parity
// checks. Renderers never mutate fixture contents.

/// One conformance fixture: `{name, protocolVersion, events: [...]}`.
/// Events are kept as raw JSON so replay happens verbatim.
public struct AIUXFixture: Sendable {
    /// Fixture name from the file (`name` field, else filename).
    public var name: String
    /// Protocol version declared by the fixture.
    public var protocolVersion: String?
    /// The raw `events` array as compact JSON objects.
    public var events: [String]

    /// Decode a fixture file's `events` array into raw JSON strings.
    /// A payload that is not a `{... , "events": [...]}` object throws.
    public init(json: String, name: String = "fixture") throws {
        let data = Data(json.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dict = object as? [String: Any] else {
            throw AIUXFixtureError.notAnObject
        }
        self.name = dict["name"] as? String ?? name
        protocolVersion = dict["protocolVersion"] as? String
        guard let rawEvents = dict["events"] as? [Any] else {
            throw AIUXFixtureError.missingEvents
        }
        events = try rawEvents.map { event in
            guard JSONSerialization.isValidJSONObject(event) else {
                throw AIUXFixtureError.badEvent
            }
            let eventData = try JSONSerialization.data(withJSONObject: event, options: [.sortedKeys])
            guard let string = String(data: eventData, encoding: .utf8) else {
                throw AIUXFixtureError.badEvent
            }
            return string
        }
    }

    /// Load a fixture from a file URL.
    public init(contentsOf url: URL) throws {
        let json = try String(contentsOf: url, encoding: .utf8)
        let name = url.deletingPathExtension().lastPathComponent
        try self.init(json: json, name: name)
    }

    /// The `events` array serialized as one JSON array — the exact argument
    /// `dispatchBatch`/`ingest(eventsJson:)` expects.
    public func eventsJSON() -> String {
        "[" + events.joined(separator: ",") + "]"
    }
}

public enum AIUXFixtureError: Error, Equatable {
    /// Top-level JSON was not an object.
    case notAnObject
    /// Fixture object lacked an `events` array.
    case missingEvents
    /// An `events` entry was not JSON-serializable.
    case badEvent
}

/// Reads the fixture directory (fixtures + manifest + expected states).
/// Pure I/O — no session or view logic.
public enum AIUXFixtureCatalog {
    /// Fixture names in the directory — per `manifest.txt`, every `*.json`
    /// file in `conformance/fixtures/` is a conformance case. Sorted for a
    /// stable catalog order.
    public static func manifest(in directory: URL) throws -> [String] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        return contents
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    /// Load every fixture listed in the directory's manifest, in order.
    public static func loadAll(in directory: URL) throws -> [AIUXFixture] {
        try manifest(in: directory).map { name in
            try AIUXFixture(contentsOf: directory.appendingPathComponent("\(name).json"))
        }
    }
}
