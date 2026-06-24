import Foundation

enum DMVVCBDecoder {
    private static let cborldTag: UInt64 = 51997
    private static let legacyRangeUncompressedTag: UInt64 = 1536
    private static let legacySingletonUncompressedTag: UInt64 = 1280
    private static let supportedCBORLDVersion: UInt64 = 31_000_000

    static func decode(_ data: Data) throws -> DMVVerifiableCredential {
        let value = try CBORReader.decode(data)
        guard case let .tagged(tag, taggedValue) = value else {
            throw CADMVInternalError.unsupportedVCB
        }

        switch tag {
        case cborldTag:
            return try decodeCurrentCBORLD(taggedValue)
        case legacyRangeUncompressedTag, legacySingletonUncompressedTag:
            guard case let .map(map) = taggedValue else {
                throw CADMVInternalError.unsupportedVCB
            }
            return try expandedCredential(from: map)
        default:
            throw CADMVInternalError.unsupportedVCB
        }
    }

    private static func decodeCurrentCBORLD(_ value: CBORValue) throws -> DMVVerifiableCredential {
        guard case let .array(topLevel) = value,
              topLevel.count == 2,
              case let .unsigned(registryEntryID) = topLevel[0],
              case let .map(map) = topLevel[1] else {
            throw CADMVInternalError.unsupportedVCB
        }

        guard registryEntryID == supportedCBORLDVersion else {
            if registryEntryID == 0 {
                return try expandedCredential(from: map)
            }
            throw CADMVInternalError.unsupportedVCB
        }

        return DMVVerifiableCredential(
            context: try context(from: requiredArray(map, key: 1)),
            type: try credentialTypes(from: requiredArray(map, key: 157)),
            issuer: try url(from: requiredValue(map, key: 180)),
            credentialSubject: try credentialSubject(from: requiredMap(map, key: 176)),
            credentialStatus: try optionalMap(map, key: 174).map(credentialStatus(from:)),
            proof: try proof(from: requiredMap(map, key: 182))
        )
    }

    private static func expandedCredential(from map: [CBORValue: CBORValue]) throws -> DMVVerifiableCredential {
        DMVVerifiableCredential(
            context: try textArrayOrString(requiredValue(map, key: "@context")),
            type: try textArrayOrString(requiredValue(map, key: "type")),
            issuer: try url(from: requiredValue(map, key: "issuer")),
            credentialSubject: try expandedCredentialSubject(from: requiredMap(map, key: "credentialSubject")),
            credentialStatus: try optionalMap(map, key: "credentialStatus").map(expandedCredentialStatus(from:)),
            proof: try expandedProof(from: requiredMap(map, key: "proof"))
        )
    }

    private static func expandedCredentialSubject(
        from map: [CBORValue: CBORValue]
    ) throws -> DMVVerifiableCredential.CredentialSubject {
        DMVVerifiableCredential.CredentialSubject(
            type: try requiredText(map, key: "type"),
            protectedComponentIndex: try protectedComponentIndex(from: requiredValue(map, key: "protectedComponentIndex"))
        )
    }

    private static func expandedCredentialStatus(
        from map: [CBORValue: CBORValue]
    ) throws -> DMVVerifiableCredential.CredentialStatus {
        DMVVerifiableCredential.CredentialStatus(
            type: try requiredText(map, key: "type"),
            terseStatusListBaseURL: try url(from: requiredValue(map, key: "terseStatusListBaseUrl")),
            terseStatusListIndex: try unsigned(requiredValue(map, key: "terseStatusListIndex"))
        )
    }

    private static func expandedProof(from map: [CBORValue: CBORValue]) throws -> DMVVerifiableCredential.Proof {
        DMVVerifiableCredential.Proof(
            type: try requiredText(map, key: "type"),
            cryptosuite: try requiredText(map, key: "cryptosuite"),
            proofPurpose: try proofPurpose(from: requiredValue(map, key: "proofPurpose")),
            proofValue: try multibaseBase58BTCString(from: requiredValue(map, key: "proofValue")),
            verificationMethod: try url(from: requiredValue(map, key: "verificationMethod"))
        )
    }

    private static func context(from values: [CBORValue]) throws -> [String] {
        try values.map { value in
            switch value {
            case .unsigned(1), .textString("https://www.w3.org/ns/credentials/v2"):
                "https://www.w3.org/ns/credentials/v2"
            case .unsigned(2), .textString("https://w3id.org/vc-barcodes/v1"):
                "https://w3id.org/vc-barcodes/v1"
            default:
                throw CADMVInternalError.unsupportedVCB
            }
        }
    }

    private static func credentialTypes(from values: [CBORValue]) throws -> [String] {
        try values.map { value in
            switch value {
            case .unsigned(118), .textString("VerifiableCredential"):
                "VerifiableCredential"
            case .unsigned(164), .textString("OpticalBarcodeCredential"):
                "OpticalBarcodeCredential"
            default:
                throw CADMVInternalError.unsupportedVCB
            }
        }
    }

    private static func credentialSubject(from map: [CBORValue: CBORValue]) throws -> DMVVerifiableCredential.CredentialSubject {
        let type = try typeValue(from: requiredValue(map, key: 156))
        guard type == "AamvaDriversLicenseScannableInformation" else {
            throw CADMVInternalError.unsupportedVCB
        }

        return DMVVerifiableCredential.CredentialSubject(
            type: type,
            protectedComponentIndex: try protectedComponentIndex(from: requiredValue(map, key: 168))
        )
    }

    private static func credentialStatus(from map: [CBORValue: CBORValue]) throws -> DMVVerifiableCredential.CredentialStatus {
        let type = try typeValue(from: requiredValue(map, key: 156))
        guard type == "TerseBitstringStatusListEntry" else {
            throw CADMVInternalError.unsupportedVCB
        }

        return DMVVerifiableCredential.CredentialStatus(
            type: type,
            terseStatusListBaseURL: try url(from: requiredValue(map, key: 196)),
            terseStatusListIndex: try requiredUnsigned(map, key: 198)
        )
    }

    private static func proof(from map: [CBORValue: CBORValue]) throws -> DMVVerifiableCredential.Proof {
        let type = try typeValue(from: requiredValue(map, key: 156))
        guard type == "DataIntegrityProof" else {
            throw CADMVInternalError.unsupportedVCB
        }

        return DMVVerifiableCredential.Proof(
            type: type,
            cryptosuite: try cryptosuite(from: requiredValue(map, key: 204)),
            proofPurpose: try proofPurpose(from: requiredValue(map, key: 214)),
            proofValue: try multibaseBase58BTCString(from: requiredValue(map, key: 216)),
            verificationMethod: try url(from: requiredValue(map, key: 218))
        )
    }

    private static func typeValue(from value: CBORValue) throws -> String {
        switch value {
        case .unsigned(108), .textString("DataIntegrityProof"):
            "DataIntegrityProof"
        case .unsigned(160), .textString("AamvaDriversLicenseScannableInformation"):
            "AamvaDriversLicenseScannableInformation"
        case .unsigned(166), .textString("TerseBitstringStatusListEntry"):
            "TerseBitstringStatusListEntry"
        default:
            throw CADMVInternalError.unsupportedVCB
        }
    }

    private static func cryptosuite(from value: CBORValue) throws -> String {
        guard value == .unsigned(1) || value == .textString("ecdsa-xi-2023") else {
            throw CADMVInternalError.unsupportedVCB
        }
        return "ecdsa-xi-2023"
    }

    private static func proofPurpose(from value: CBORValue) throws -> String {
        switch value {
        case .unsigned(220), .textString("assertionMethod"):
            return "assertionMethod"
        case .textString("https://w3id.org/security#assertionMethod"):
            return "assertionMethod"
        default:
            throw CADMVInternalError.unsupportedVCB
        }
    }

    private static func url(from value: CBORValue) throws -> String {
        switch value {
        case let .byteString(data):
            return try compactURL(from: data)
        case let .textString(text):
            guard isSafeURLText(text) else {
                throw CADMVInternalError.unsupportedVCB
            }
            return text
        default:
            throw CADMVInternalError.unsupportedVCB
        }
    }

    private static func compactURL(from data: Data) throws -> String {
        guard data.count == 1, let id = data.first else {
            throw CADMVInternalError.unsupportedVCB
        }

        switch UInt64(id) {
        case 1:
            return "did:web:credentials.dmv.ca.gov"
        case 2:
            return "https://api.credentials.dmv.ca.gov/status/dlid/1/status-lists"
        case 3:
            return "https://api.credentials.dmv.ca.gov/status/dlid/2/status-lists"
        case 4:
            return "https://api.credentials.dmv.ca.gov/status/dlid/3/status-lists"
        case 5:
            return "did:web:credentials.dmv.ca.gov#vm-vcb-1"
        case 6:
            return "did:web:credentials.dmv.ca.gov#vm-vcb-2"
        case 7:
            return "did:web:credentials.dmv.ca.gov#vm-vcb-3"
        case 8:
            return "did:web:credentials.dmv.ca.gov#vm-vcb-4"
        case 9:
            return "did:web:credentials.dmv.ca.gov#vm-vcb-5"
        case 10:
            return "did:web:credentials.dmv.ca.gov#vm-vcb-6"
        case 11:
            return "did:web:credentials.dmv.ca.gov#vm-vcb-7"
        case 12:
            return "did:web:credentials.dmv.ca.gov#vm-vcb-8"
        case 13:
            return "did:web:credentials.dmv.ca.gov#vm-vcb-9"
        case 14:
            return "did:web:credentials.dmv.ca.gov#vm-vcb-10"
        case 15:
            return "did:web:credentials.dmv.ca.gov#vm-vcb-11"
        case 16:
            return "did:web:credentials.dmv.ca.gov#vm-vcb-12"
        case 17:
            return "did:web:credentials.dmv.ca.gov#vm-vcb-13"
        case 18:
            return "did:web:credentials.dmv.ca.gov#vm-vcb-14"
        case 19:
            return "did:web:credentials.dmv.ca.gov#vm-vcb-15"
        case 20:
            return "did:web:uat-credentials.dmv.ca.gov"
        case 21:
            return "https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists"
        case 22:
            return "did:web:uat-credentials.dmv.ca.gov#vm-vcb-1"
        case 23:
            return "did:web:uat-credentials.dmv.ca.gov#vm-vcb-2"
        case 24:
            return "did:web:uat-credentials.dmv.ca.gov#vm-vcb-3"
        case 25:
            return "did:web:uat-credentials.dmv.ca.gov#vm-vcb-4"
        case 26:
            return "did:web:uat-credentials.dmv.ca.gov#vm-vcb-5"
        case 27:
            return "https://api.uat-credentials.dmv.ca.gov/status/dlid/2/status-lists"
        case 28:
            return "https://api.uat-credentials.dmv.ca.gov/status/dlid/3/status-lists"
        default:
            throw CADMVInternalError.unsupportedVCB
        }
    }

    private static func protectedComponentIndex(from value: CBORValue) throws -> String {
        switch value {
        case let .unsigned(number):
            guard number <= 0x00ff_ffff else {
                throw CADMVInternalError.unsupportedVCB
            }
            let bytes = Data([
                UInt8((number >> 16) & 0xff),
                UInt8((number >> 8) & 0xff),
                UInt8(number & 0xff)
            ])
            return "u" + Base64URL.encode(bytes)
        case let .byteString(data):
            guard data.count == 4,
                  data.first == UInt8(ascii: "u") else {
                throw CADMVInternalError.unsupportedVCB
            }
            return "u" + Base64URL.encode(data.dropFirst())
        case let .textString(text):
            guard isValidProtectedComponentIndex(text) else {
                throw CADMVInternalError.unsupportedVCB
            }
            return text
        default:
            throw CADMVInternalError.unsupportedVCB
        }
    }

    private static func multibaseBase58BTCString(from value: CBORValue) throws -> String {
        switch value {
        case let .byteString(data):
            guard data.first == 0x7a else {
                throw CADMVInternalError.unsupportedVCB
            }
            return "z" + Base58BTC.encode(data.dropFirst())
        case let .textString(text):
            guard text.first == "z",
                  Base58BTC.decode(String(text.dropFirst())) != nil else {
                throw CADMVInternalError.unsupportedVCB
            }
            return text
        default:
            throw CADMVInternalError.unsupportedVCB
        }
    }

    private static func requiredArray(_ map: [CBORValue: CBORValue], key: UInt64) throws -> [CBORValue] {
        guard case let .array(values) = map[.unsigned(key)] else {
            throw CADMVInternalError.unsupportedVCB
        }
        return values
    }

    private static func textArrayOrString(_ value: CBORValue) throws -> [String] {
        switch value {
        case let .textString(text):
            return [text]
        case let .array(values):
            return try values.map { value in
                guard case let .textString(text) = value else {
                    throw CADMVInternalError.unsupportedVCB
                }
                return text
            }
        default:
            throw CADMVInternalError.unsupportedVCB
        }
    }

    private static func requiredMap(_ map: [CBORValue: CBORValue], key: UInt64) throws -> [CBORValue: CBORValue] {
        guard case let .map(values) = map[.unsigned(key)] else {
            throw CADMVInternalError.unsupportedVCB
        }
        return values
    }

    private static func requiredMap(_ map: [CBORValue: CBORValue], key: String) throws -> [CBORValue: CBORValue] {
        guard case let .map(values) = map[.textString(key)] else {
            throw CADMVInternalError.unsupportedVCB
        }
        return values
    }

    private static func optionalMap(_ map: [CBORValue: CBORValue], key: UInt64) throws -> [CBORValue: CBORValue]? {
        guard let value = map[.unsigned(key)] else {
            return nil
        }
        guard case let .map(values) = value else {
            throw CADMVInternalError.unsupportedVCB
        }
        return values
    }

    private static func optionalMap(_ map: [CBORValue: CBORValue], key: String) throws -> [CBORValue: CBORValue]? {
        guard let value = map[.textString(key)] else {
            return nil
        }
        guard case let .map(values) = value else {
            throw CADMVInternalError.unsupportedVCB
        }
        return values
    }

    private static func requiredValue(_ map: [CBORValue: CBORValue], key: UInt64) throws -> CBORValue {
        guard let value = map[.unsigned(key)] else {
            throw CADMVInternalError.unsupportedVCB
        }
        return value
    }

    private static func requiredValue(_ map: [CBORValue: CBORValue], key: String) throws -> CBORValue {
        guard let value = map[.textString(key)] else {
            throw CADMVInternalError.unsupportedVCB
        }
        return value
    }

    private static func requiredText(_ map: [CBORValue: CBORValue], key: String) throws -> String {
        guard case let .textString(value) = map[.textString(key)] else {
            throw CADMVInternalError.unsupportedVCB
        }
        return value
    }

    private static func requiredUnsigned(_ map: [CBORValue: CBORValue], key: UInt64) throws -> UInt64 {
        guard let value = map[.unsigned(key)] else {
            throw CADMVInternalError.unsupportedVCB
        }
        return try unsigned(value)
    }

    private static func unsigned(_ value: CBORValue) throws -> UInt64 {
        guard case let .unsigned(number) = value else {
            throw CADMVInternalError.unsupportedVCB
        }
        return number
    }

    private static func isValidProtectedComponentIndex(_ text: String) -> Bool {
        guard text.count == 5,
              text.first == "u",
              let bytes = Base64URL.decode(String(text.dropFirst())),
              bytes.count == 3 else {
            return false
        }
        return true
    }

    private static func isSafeURLText(_ text: String) -> Bool {
        guard !text.isEmpty,
              text.utf8.allSatisfy({ byte in
                  switch byte {
                  case UInt8(ascii: "A")...UInt8(ascii: "Z"),
                       UInt8(ascii: "a")...UInt8(ascii: "z"),
                       UInt8(ascii: "0")...UInt8(ascii: "9"),
                       UInt8(ascii: "-"),
                       UInt8(ascii: "."),
                       UInt8(ascii: "_"),
                       UInt8(ascii: "~"),
                       UInt8(ascii: ":"),
                       UInt8(ascii: "/"),
                       UInt8(ascii: "?"),
                       UInt8(ascii: "#"),
                       UInt8(ascii: "["),
                       UInt8(ascii: "]"),
                       UInt8(ascii: "@"),
                       UInt8(ascii: "!"),
                       UInt8(ascii: "$"),
                       UInt8(ascii: "&"),
                       UInt8(ascii: "'"),
                       UInt8(ascii: "("),
                       UInt8(ascii: ")"),
                       UInt8(ascii: "*"),
                       UInt8(ascii: "+"),
                       UInt8(ascii: ","),
                       UInt8(ascii: ";"),
                       UInt8(ascii: "="):
                      return true
                  default:
                      return false
                  }
              }) else {
            return false
        }
        return text.hasPrefix("did:web:credentials.dmv.ca.gov") ||
            text.hasPrefix("did:web:uat-credentials.dmv.ca.gov") ||
            text.hasPrefix("https://api.credentials.dmv.ca.gov/status/dlid/") ||
            text.hasPrefix("https://api.uat-credentials.dmv.ca.gov/status/dlid/")
    }
}

enum Base58BTC {
    private static let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8)
    private static let decodeMap: [UInt8: Int] = Dictionary(
        uniqueKeysWithValues: alphabet.enumerated().map { index, byte in (byte, index) }
    )

    static func encode(_ data: Data) -> String {
        guard !data.isEmpty else {
            return ""
        }

        let leadingZeroCount = data.prefix { $0 == 0 }.count
        let payload = data.dropFirst(leadingZeroCount)
        guard !payload.isEmpty else {
            return String(repeating: "1", count: leadingZeroCount)
        }

        var digits = [Int](repeating: 0, count: 1)
        for byte in payload {
            var carry = Int(byte)
            for index in digits.indices {
                let value = digits[index] * 256 + carry
                digits[index] = value % 58
                carry = value / 58
            }
            while carry > 0 {
                digits.append(carry % 58)
                carry /= 58
            }
        }

        var encoded = String(repeating: "1", count: leadingZeroCount)
        encoded += String(decoding: digits.reversed().map { alphabet[$0] }, as: UTF8.self)
        return encoded
    }

    static func decode(_ value: String) -> Data? {
        let leadingZeroCount = value.utf8.prefix(while: { $0 == UInt8(ascii: "1") }).count
        let payload = value.utf8.dropFirst(leadingZeroCount)
        guard !payload.isEmpty else {
            return Data(repeating: 0, count: leadingZeroCount)
        }

        var bytes = [UInt8](repeating: 0, count: 1)

        for byte in payload {
            guard let digit = decodeMap[byte] else {
                return nil
            }

            var carry = digit
            for index in bytes.indices {
                let result = Int(bytes[index]) * 58 + carry
                bytes[index] = UInt8(result & 0xff)
                carry = result >> 8
            }

            while carry > 0 {
                bytes.append(UInt8(carry & 0xff))
                carry >>= 8
            }
        }

        for _ in 0..<leadingZeroCount {
            bytes.append(0)
        }

        return Data(bytes.reversed())
    }
}
