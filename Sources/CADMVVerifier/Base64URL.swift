import Foundation

enum Base64URL {
    static func decode(_ value: String) -> Data? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
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
