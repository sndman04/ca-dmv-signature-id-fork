import Foundation

enum DMVVCBDecoder {
    private static let cborldTag: UInt64 = 51997
    private static let supportedCBORLDVersion: UInt64 = 31_000_000

    static func decode(_ data: Data) throws -> DMVVerifiableCredential {
        let value = try CBORReader.decode(data)
        guard case let .tagged(tag, taggedValue) = value,
              tag == cborldTag,
              case let .array(topLevel) = taggedValue,
              topLevel.count == 2,
              topLevel[0] == .unsigned(supportedCBORLDVersion),
              case let .map(map) = topLevel[1] else {
            throw CADMVInternalError.unsupportedVCB
        }

        return DMVVerifiableCredential(
            context: try context(from: requiredArray(map, key: 1)),
            type: try credentialTypes(from: requiredArray(map, key: 157)),
            issuer: try url(from: requiredByteString(map, key: 180)),
            credentialSubject: try credentialSubject(from: requiredMap(map, key: 176)),
            credentialStatus: try credentialStatus(from: requiredMap(map, key: 174)),
            proof: try proof(from: requiredMap(map, key: 182))
        )
    }

    private static func context(from values: [CBORValue]) throws -> [String] {
        try values.map { value in
            switch try unsigned(value) {
            case 1:
                "https://www.w3.org/ns/credentials/v2"
            case 2:
                "https://w3id.org/vc-barcodes/v1"
            default:
                throw CADMVInternalError.unsupportedVCB
            }
        }
    }

    private static func credentialTypes(from values: [CBORValue]) throws -> [String] {
        try values.map { value in
            switch try unsigned(value) {
            case 118:
                "VerifiableCredential"
            case 164:
                "OpticalBarcodeCredential"
            default:
                throw CADMVInternalError.unsupportedVCB
            }
        }
    }

    private static func credentialSubject(from map: [CBORValue: CBORValue]) throws -> DMVVerifiableCredential.CredentialSubject {
        let type = try typeValue(from: requiredUnsigned(map, key: 156))
        guard type == "AamvaDriversLicenseScannableInformation" else {
            throw CADMVInternalError.unsupportedVCB
        }

        return DMVVerifiableCredential.CredentialSubject(
            type: type,
            protectedComponentIndex: try protectedComponentIndex(from: requiredByteString(map, key: 168))
        )
    }

    private static func credentialStatus(from map: [CBORValue: CBORValue]) throws -> DMVVerifiableCredential.CredentialStatus {
        let type = try typeValue(from: requiredUnsigned(map, key: 156))
        guard type == "TerseBitstringStatusListEntry" else {
            throw CADMVInternalError.unsupportedVCB
        }

        return DMVVerifiableCredential.CredentialStatus(
            type: type,
            terseStatusListBaseURL: try url(from: requiredByteString(map, key: 196)),
            terseStatusListIndex: try requiredUnsigned(map, key: 198)
        )
    }

    private static func proof(from map: [CBORValue: CBORValue]) throws -> DMVVerifiableCredential.Proof {
        let type = try typeValue(from: requiredUnsigned(map, key: 156))
        guard type == "DataIntegrityProof" else {
            throw CADMVInternalError.unsupportedVCB
        }

        return DMVVerifiableCredential.Proof(
            type: type,
            cryptosuite: try cryptosuite(from: requiredUnsigned(map, key: 204)),
            proofPurpose: try proofPurpose(from: requiredUnsigned(map, key: 214)),
            proofValue: try multibaseBase58BTCString(from: requiredByteString(map, key: 216)),
            verificationMethod: try url(from: requiredByteString(map, key: 218))
        )
    }

    private static func typeValue(from id: UInt64) throws -> String {
        switch id {
        case 108:
            "DataIntegrityProof"
        case 160:
            "AamvaDriversLicenseScannableInformation"
        case 166:
            "TerseBitstringStatusListEntry"
        default:
            throw CADMVInternalError.unsupportedVCB
        }
    }

    private static func cryptosuite(from id: UInt64) throws -> String {
        guard id == 1 else {
            throw CADMVInternalError.unsupportedVCB
        }
        return "ecdsa-xi-2023"
    }

    private static func proofPurpose(from id: UInt64) throws -> String {
        guard id == 220 else {
            throw CADMVInternalError.unsupportedVCB
        }
        return "assertionMethod"
    }

    private static func url(from data: Data) throws -> String {
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

    private static func protectedComponentIndex(from data: Data) throws -> String {
        if data == Data([0x75, 0xff, 0x70, 0x60]) {
            return "u_3Bg"
        }
        throw CADMVInternalError.unsupportedVCB
    }

    private static func multibaseBase58BTCString(from data: Data) throws -> String {
        guard data.first == 0x7a else {
            throw CADMVInternalError.unsupportedVCB
        }
        return "z" + Base58BTC.encode(data.dropFirst())
    }

    private static func requiredArray(_ map: [CBORValue: CBORValue], key: UInt64) throws -> [CBORValue] {
        guard case let .array(values) = map[.unsigned(key)] else {
            throw CADMVInternalError.unsupportedVCB
        }
        return values
    }

    private static func requiredMap(_ map: [CBORValue: CBORValue], key: UInt64) throws -> [CBORValue: CBORValue] {
        guard case let .map(values) = map[.unsigned(key)] else {
            throw CADMVInternalError.unsupportedVCB
        }
        return values
    }

    private static func requiredUnsigned(_ map: [CBORValue: CBORValue], key: UInt64) throws -> UInt64 {
        guard let value = map[.unsigned(key)] else {
            throw CADMVInternalError.unsupportedVCB
        }
        return try unsigned(value)
    }

    private static func requiredByteString(_ map: [CBORValue: CBORValue], key: UInt64) throws -> Data {
        guard case let .byteString(data) = map[.unsigned(key)] else {
            throw CADMVInternalError.unsupportedVCB
        }
        return data
    }

    private static func unsigned(_ value: CBORValue) throws -> UInt64 {
        guard case let .unsigned(number) = value else {
            throw CADMVInternalError.unsupportedVCB
        }
        return number
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
