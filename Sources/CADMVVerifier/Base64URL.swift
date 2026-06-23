import Foundation

enum Base64URL {
    static func decode(_ value: String) -> Data? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              isBase64URL(trimmed) else {
            return nil
        }

        let paddingStart = trimmed.firstIndex(of: "=") ?? trimmed.endIndex
        let unpaddedLength = trimmed.distance(from: trimmed.startIndex, to: paddingStart)
        let explicitPaddingLength = trimmed.distance(from: paddingStart, to: trimmed.endIndex)
        guard unpaddedLength % 4 != 1 else {
            return nil
        }
        if explicitPaddingLength > 0 {
            let unpaddedRemainder = unpaddedLength % 4
            guard trimmed.count % 4 == 0,
                  unpaddedRemainder != 0,
                  explicitPaddingLength == 4 - unpaddedRemainder else {
                return nil
            }
        }

        var base64 = trimmed
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder != 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }

        return Data(base64Encoded: base64)
    }

    private static func isBase64URL(_ value: String) -> Bool {
        var sawPadding = false
        var paddingCount = 0

        for byte in value.utf8 {
            switch byte {
            case UInt8(ascii: "A")...UInt8(ascii: "Z"),
                 UInt8(ascii: "a")...UInt8(ascii: "z"),
                 UInt8(ascii: "0")...UInt8(ascii: "9"),
                 UInt8(ascii: "-"),
                 UInt8(ascii: "_"),
                 UInt8(ascii: "+"),
                 UInt8(ascii: "/"):
                guard !sawPadding else {
                    return false
                }
            case UInt8(ascii: "="):
                sawPadding = true
                paddingCount += 1
                guard paddingCount <= 2 else {
                    return false
                }
            default:
                return false
            }
        }

        return true
    }
}

enum CADMVInternalError: Error {
    case malformedBarcode
    case malformedCBOR
    case unsupportedCBOR
    case unsupportedVCB
    case didResolutionFailed
    case unsupportedDIDKey
    case statusListDecodeFailed
}
