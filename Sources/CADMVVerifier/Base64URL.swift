import Foundation

enum Base64URL {
    static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }

    static func decode(_ value: String) -> Data? {
        let compactedScalars = value.unicodeScalars.filter { scalar in
            switch scalar.value {
            case 0x09, 0x0a, 0x0c, 0x0d, 0x20:
                return false
            default:
                return true
            }
        }
        let compacted = String(String.UnicodeScalarView(compactedScalars))
        guard !compacted.isEmpty,
              isBase64URL(compacted) else {
            return nil
        }

        let paddingStart = compacted.firstIndex(of: "=") ?? compacted.endIndex
        let unpaddedLength = compacted.distance(from: compacted.startIndex, to: paddingStart)
        let explicitPaddingLength = compacted.distance(from: paddingStart, to: compacted.endIndex)
        guard unpaddedLength % 4 != 1 else {
            return nil
        }
        if explicitPaddingLength > 0 {
            let unpaddedRemainder = unpaddedLength % 4
            guard compacted.count % 4 == 0,
                  unpaddedRemainder != 0,
                  explicitPaddingLength == 4 - unpaddedRemainder else {
                return nil
            }
        }

        var base64 = compacted
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

enum CADMVInternalError: Equatable, Error {
    case malformedBarcode
    case malformedCBOR
    case unsupportedCBOR
    case unsupportedVCB
    case environmentMismatch(expected: CADMVVerificationMode)
    case didResolutionFailed
    case unsupportedDIDKey
    case statusListDecodeFailed
}
