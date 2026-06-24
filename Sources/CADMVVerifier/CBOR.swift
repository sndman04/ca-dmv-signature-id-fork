import Foundation

indirect enum CBORValue: Hashable, Sendable {
    case unsigned(UInt64)
    case negative(Int64)
    case byteString(Data)
    case textString(String)
    case array([CBORValue])
    case map([CBORValue: CBORValue])
    case tagged(UInt64, CBORValue)
    case bool(Bool)
    case null
}

enum CBORReader {
    private static let maxDepth = 32

    static func decode(_ data: Data) throws -> CBORValue {
        var cursor = data.startIndex
        let value = try readValue(from: data, cursor: &cursor, depth: 0)
        guard cursor == data.endIndex else {
            throw CADMVInternalError.malformedCBOR
        }
        return value
    }

    private static func readValue(
        from data: Data,
        cursor: inout Data.Index,
        depth: Int
    ) throws -> CBORValue {
        guard depth <= maxDepth else {
            throw CADMVInternalError.malformedCBOR
        }
        guard cursor < data.endIndex else {
            throw CADMVInternalError.malformedCBOR
        }

        let initialByte = data[cursor]
        cursor = data.index(after: cursor)
        let majorType = initialByte >> 5
        let additionalInfo = initialByte & 0x1f

        switch majorType {
        case 0:
            return .unsigned(try readArgument(additionalInfo, from: data, cursor: &cursor))
        case 1:
            let value = try readArgument(additionalInfo, from: data, cursor: &cursor)
            guard value <= UInt64(Int64.max) else {
                throw CADMVInternalError.malformedCBOR
            }
            return .negative(-1 - Int64(value))
        case 2:
            let length = try readLength(additionalInfo, from: data, cursor: &cursor)
            return .byteString(try readBytes(length: length, from: data, cursor: &cursor))
        case 3:
            let length = try readLength(additionalInfo, from: data, cursor: &cursor)
            let bytes = try readBytes(length: length, from: data, cursor: &cursor)
            guard let string = String(data: bytes, encoding: .utf8) else {
                throw CADMVInternalError.malformedCBOR
            }
            return .textString(string)
        case 4:
            let count = try readLength(additionalInfo, from: data, cursor: &cursor)
            var values: [CBORValue] = []
            values.reserveCapacity(count)
            for _ in 0..<count {
                values.append(try readValue(from: data, cursor: &cursor, depth: depth + 1))
            }
            return .array(values)
        case 5:
            let count = try readLength(additionalInfo, from: data, cursor: &cursor)
            var values: [CBORValue: CBORValue] = [:]
            values.reserveCapacity(count)
            for _ in 0..<count {
                let key = try readValue(from: data, cursor: &cursor, depth: depth + 1)
                let value = try readValue(from: data, cursor: &cursor, depth: depth + 1)
                guard values[key] == nil else {
                    throw CADMVInternalError.malformedCBOR
                }
                values[key] = value
            }
            return .map(values)
        case 6:
            let tag = try readArgument(additionalInfo, from: data, cursor: &cursor)
            return .tagged(tag, try readValue(from: data, cursor: &cursor, depth: depth + 1))
        case 7:
            switch additionalInfo {
            case 20:
                return .bool(false)
            case 21:
                return .bool(true)
            case 22, 23:
                return .null
            default:
                throw CADMVInternalError.unsupportedCBOR
            }
        default:
            throw CADMVInternalError.unsupportedCBOR
        }
    }

    private static func readArgument(
        _ additionalInfo: UInt8,
        from data: Data,
        cursor: inout Data.Index
    ) throws -> UInt64 {
        switch additionalInfo {
        case 0..<24:
            return UInt64(additionalInfo)
        case 24:
            return UInt64(try readIntegerByte(from: data, cursor: &cursor))
        case 25:
            return UInt64(try readBigEndianInteger(byteCount: 2, from: data, cursor: &cursor))
        case 26:
            return UInt64(try readBigEndianInteger(byteCount: 4, from: data, cursor: &cursor))
        case 27:
            return try readBigEndianInteger(byteCount: 8, from: data, cursor: &cursor)
        default:
            throw CADMVInternalError.unsupportedCBOR
        }
    }

    private static func readLength(
        _ additionalInfo: UInt8,
        from data: Data,
        cursor: inout Data.Index
    ) throws -> Int {
        let length = try readArgument(additionalInfo, from: data, cursor: &cursor)
        guard length <= UInt64(Int.max) else {
            throw CADMVInternalError.malformedCBOR
        }
        return Int(length)
    }

    private static func readBytes(length: Int, from data: Data, cursor: inout Data.Index) throws -> Data {
        guard let end = data.index(cursor, offsetBy: length, limitedBy: data.endIndex) else {
            throw CADMVInternalError.malformedCBOR
        }
        let bytes = data[cursor..<end]
        cursor = end
        return Data(bytes)
    }

    private static func readIntegerByte(from data: Data, cursor: inout Data.Index) throws -> UInt8 {
        guard cursor < data.endIndex else {
            throw CADMVInternalError.malformedCBOR
        }
        let byte = data[cursor]
        cursor = data.index(after: cursor)
        return byte
    }

    private static func readBigEndianInteger(
        byteCount: Int,
        from data: Data,
        cursor: inout Data.Index
    ) throws -> UInt64 {
        let bytes = try readBytes(length: byteCount, from: data, cursor: &cursor)
        return bytes.reduce(UInt64(0)) { partial, byte in
            (partial << 8) | UInt64(byte)
        }
    }
}
