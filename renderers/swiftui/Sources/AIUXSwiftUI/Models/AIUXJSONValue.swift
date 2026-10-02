import Foundation

/// A decodable JSON value — the Swift stand-in for `serde_json::Value` used in
/// free-form protocol fields (action payloads, tool input/result, metadata).
///
/// Every entity also carries an `extra` map of these so unknown optional
/// fields survive a decode/encode round-trip untouched (plan §21).
public enum AIUXJSONValue: Equatable, Sendable {
    case string(String)
    /// Integral wire values — kept exact past Double's 2^53 precision bound
    /// (serde_json does the same split: `Number` is i64/u64/f64).
    case int(Int64)
    case number(Double)
    case bool(Bool)
    case array([AIUXJSONValue])
    case object([String: AIUXJSONValue])
    case null

    /// The value as a plain JSON type for `JSONSerialization` interop.
    public var object: Any {
        switch self {
        case .string(let s): return s
        case .int(let i): return i
        case .number(let n): return n
        case .bool(let b): return b
        case .array(let a): return a.map { $0.object }
        case .object(let o): return o.mapValues { $0.object }
        case .null: return NSNull()
        }
    }

    /// Convenience accessors for payload inspection.
    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var numberValue: Double? {
        switch self {
        case .int(let i): return Double(i)
        case .number(let n): return n
        default: return nil
        }
    }

    /// The exact integer for `.int`; nil otherwise (`.number` stays Double).
    public var intValue: Int64? {
        if case .int(let i) = self { return i }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    public subscript(key: String) -> AIUXJSONValue? {
        if case .object(let o) = self { return o[key] }
        return nil
    }
}

extension AIUXJSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int64.self) {
            self = .int(i)
        } else if let n = try? container.decode(Double.self) {
            self = .number(n)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode([AIUXJSONValue].self) {
            self = .array(a)
        } else if let o = try? container.decode([String: AIUXJSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .number(let n): try container.encode(n)
        case .bool(let b): try container.encode(b)
        case .array(let a): try container.encode(a)
        case .object(let o): try container.encode(o)
        case .null: try container.encodeNil()
        }
    }
}

extension AIUXJSONValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral,
    ExpressibleByFloatLiteral, ExpressibleByBooleanLiteral,
    ExpressibleByDictionaryLiteral, ExpressibleByArrayLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
    public init(integerLiteral value: Int) { self = .int(Int64(value)) }
    public init(floatLiteral value: Double) { self = .number(value) }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(dictionaryLiteral elements: (String, AIUXJSONValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
    public init(arrayLiteral elements: AIUXJSONValue...) {
        self = .array(elements)
    }
}
