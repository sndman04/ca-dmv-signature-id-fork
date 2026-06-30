import Foundation

struct DMVStatusListCredential: Equatable, Sendable {
    let id: String
    let type: [String]
    let issuer: String
    let validFrom: String?
    let validUntil: String?
    let name: String?
    let description: String?
    let credentialSubject: CredentialSubject
    let proof: Proof

    struct CredentialSubject: Equatable, Sendable {
        let id: String
        let type: String
        let encodedList: String
        let statusPurpose: String
    }

    struct Proof: Equatable, Sendable {
        let type: String
        let created: String?
        let verificationMethod: String
        let cryptosuite: String
        let proofPurpose: String
        let proofValue: String
    }
}

enum DMVStatusListCredentialParser {
    private static let rootKeys: Set<String> = [
        "@context", "id", "type", "issuer", "validFrom", "validUntil",
        "name", "description", "credentialSubject", "proof"
    ]
    private static let subjectKeys: Set<String> = [
        "id", "type", "encodedList", "statusPurpose"
    ]
    private static let proofKeys: Set<String> = [
        "type", "created", "verificationMethod", "cryptosuite", "proofPurpose", "proofValue"
    ]

    static func parse(_ data: Data) throws -> DMVStatusListCredential {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let root = json as? [String: Any] else {
            throw CADMVInternalError.statusListDecodeFailed
        }
        try rejectUnknownKeys(root, allowed: rootKeys)

        guard let context = root["@context"] as? [String],
              context == ["https://www.w3.org/ns/credentials/v2"],
              let id = root["id"] as? String,
              let type = root["type"] as? [String],
              let issuer = root["issuer"] as? String,
              let subjectObject = root["credentialSubject"] as? [String: Any],
              let proofObject = root["proof"] as? [String: Any] else {
            throw CADMVInternalError.statusListDecodeFailed
        }

        try rejectUnknownKeys(subjectObject, allowed: subjectKeys)
        try rejectUnknownKeys(proofObject, allowed: proofKeys)

        guard Set(type) == ["VerifiableCredential", "BitstringStatusListCredential"],
              type.count == 2,
              type.allSatisfy(isSafeToken(_:)),
              isSafeIRI(id),
              isSafeIRI(issuer),
              let subjectID = subjectObject["id"] as? String,
              subjectID == "\(id)#list",
              isSafeIRI(subjectID),
              let subjectType = subjectObject["type"] as? String,
              subjectType == "BitstringStatusList",
              let encodedList = subjectObject["encodedList"] as? String,
              isSafeMultibase(encodedList),
              let statusPurpose = subjectObject["statusPurpose"] as? String,
              statusPurpose == "revocation",
              let proofType = proofObject["type"] as? String,
              proofType == "DataIntegrityProof",
              let verificationMethod = proofObject["verificationMethod"] as? String,
              isSafeIRI(verificationMethod),
              let cryptosuite = proofObject["cryptosuite"] as? String,
              cryptosuite == "ecdsa-rdfc-2019",
              let proofPurpose = proofObject["proofPurpose"] as? String,
              proofPurpose == "assertionMethod",
              let proofValue = proofObject["proofValue"] as? String,
              isSafeMultibase(proofValue),
              isSafeOptionalDate(root["validFrom"] as? String),
              isSafeOptionalDate(root["validUntil"] as? String),
              isSafeOptionalText(root["name"] as? String),
              isSafeOptionalText(root["description"] as? String),
              isSafeOptionalDate(proofObject["created"] as? String) else {
            throw CADMVInternalError.statusListDecodeFailed
        }

        return DMVStatusListCredential(
            id: id,
            type: type,
            issuer: issuer,
            validFrom: root["validFrom"] as? String,
            validUntil: root["validUntil"] as? String,
            name: root["name"] as? String,
            description: root["description"] as? String,
            credentialSubject: DMVStatusListCredential.CredentialSubject(
                id: subjectID,
                type: subjectType,
                encodedList: encodedList,
                statusPurpose: statusPurpose
            ),
            proof: DMVStatusListCredential.Proof(
                type: proofType,
                created: proofObject["created"] as? String,
                verificationMethod: verificationMethod,
                cryptosuite: cryptosuite,
                proofPurpose: proofPurpose,
                proofValue: proofValue
            )
        )
    }

    static func profileDiagnostic(_ data: Data) -> CADMVStatusListProfileDiagnostic {
        guard let json = try? JSONSerialization.jsonObject(with: data),
              let root = json as? [String: Any] else {
            return CADMVStatusListProfileDiagnostic(
                supported: false,
                unknownRootKeys: [],
                unknownCredentialSubjectKeys: [],
                unknownProofKeys: []
            )
        }

        let subjectObject = root["credentialSubject"] as? [String: Any] ?? [:]
        let proofObject = root["proof"] as? [String: Any] ?? [:]
        let unknownRootKeys = unknownKeys(in: root, allowed: rootKeys)
        let unknownCredentialSubjectKeys = unknownKeys(in: subjectObject, allowed: subjectKeys)
        let unknownProofKeys = unknownKeys(in: proofObject, allowed: proofKeys)

        return CADMVStatusListProfileDiagnostic(
            supported: (try? parse(data)) != nil,
            unknownRootKeys: unknownRootKeys,
            unknownCredentialSubjectKeys: unknownCredentialSubjectKeys,
            unknownProofKeys: unknownProofKeys
        )
    }

    private static func rejectUnknownKeys(
        _ object: [String: Any],
        allowed: Set<String>
    ) throws {
        for key in object.keys {
            guard allowed.contains(key) else {
                throw CADMVInternalError.statusListDecodeFailed
            }
        }
    }

    private static func unknownKeys(
        in object: [String: Any],
        allowed: Set<String>
    ) -> [String] {
        object.keys
            .filter { !allowed.contains($0) }
            .sorted()
    }

    private static func isSafeIRI(_ value: String) -> Bool {
        guard let first = value.utf8.first, isASCIIAlpha(first),
              let separator = value.utf8.firstIndex(of: CharacterSetByte.colon),
              separator != value.utf8.startIndex else {
            return false
        }

        for byte in value.utf8[..<separator] {
            guard isASCIIAlphaNumeric(byte) || byte == CharacterSetByte.plus ||
                    byte == CharacterSetByte.period || byte == CharacterSetByte.hyphen else {
                return false
            }
        }

        let suffixStart = value.utf8.index(after: separator)
        guard suffixStart < value.utf8.endIndex else {
            return false
        }
        return value.utf8[suffixStart...].allSatisfy(isSafeIRIByte(_:))
    }

    private static func isSafeToken(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy {
            isASCIIAlphaNumeric($0) || $0 == CharacterSetByte.period ||
                $0 == CharacterSetByte.underscore || $0 == CharacterSetByte.colon ||
                $0 == CharacterSetByte.hyphen
        }
    }

    private static func isSafeMultibase(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy {
            isASCIIAlphaNumeric($0) || $0 == CharacterSetByte.underscore ||
                $0 == CharacterSetByte.hyphen
        }
    }

    private static func isSafeOptionalDate(_ value: String?) -> Bool {
        guard let value else {
            return true
        }
        let bytes = Array(value.utf8)
        guard bytes.count == 20 else {
            return false
        }
        for index in bytes.indices {
            if isDateDigitPosition(index) {
                guard isASCIIDigit(bytes[index]) else {
                    return false
                }
            }
        }
        return bytes[4] == CharacterSetByte.hyphen &&
            bytes[7] == CharacterSetByte.hyphen &&
            bytes[10] == CharacterSetByte.upperT &&
            bytes[13] == CharacterSetByte.colon &&
            bytes[16] == CharacterSetByte.colon &&
            bytes[19] == CharacterSetByte.upperZ
    }

    private static func isDateDigitPosition(_ index: Int) -> Bool {
        switch index {
        case 0, 1, 2, 3, 5, 6, 8, 9, 11, 12, 14, 15, 17, 18:
            return true
        default:
            return false
        }
    }

    private static func isSafeOptionalText(_ value: String?) -> Bool {
        guard let value else {
            return true
        }
        return !value.isEmpty && value.utf8.allSatisfy {
            $0 >= CharacterSetByte.space &&
                $0 != CharacterSetByte.doubleQuote &&
                $0 != CharacterSetByte.backslash &&
                $0 <= CharacterSetByte.tilde
        }
    }

    private static func isSafeIRIByte(_ byte: UInt8) -> Bool {
        isASCIIAlphaNumeric(byte) ||
            byte == CharacterSetByte.period ||
            byte == CharacterSetByte.underscore ||
            byte == CharacterSetByte.tilde ||
            byte == CharacterSetByte.colon ||
            byte == CharacterSetByte.slash ||
            byte == CharacterSetByte.question ||
            byte == CharacterSetByte.hash ||
            byte == CharacterSetByte.openBracket ||
            byte == CharacterSetByte.closeBracket ||
            byte == CharacterSetByte.at ||
            byte == CharacterSetByte.exclamation ||
            byte == CharacterSetByte.dollar ||
            byte == CharacterSetByte.ampersand ||
            byte == CharacterSetByte.singleQuote ||
            byte == CharacterSetByte.openParen ||
            byte == CharacterSetByte.closeParen ||
            byte == CharacterSetByte.star ||
            byte == CharacterSetByte.plus ||
            byte == CharacterSetByte.comma ||
            byte == CharacterSetByte.semicolon ||
            byte == CharacterSetByte.equal ||
            byte == CharacterSetByte.percent ||
            byte == CharacterSetByte.hyphen
    }

    private static func isASCIIAlphaNumeric(_ byte: UInt8) -> Bool {
        isASCIIAlpha(byte) || isASCIIDigit(byte)
    }

    private static func isASCIIAlpha(_ byte: UInt8) -> Bool {
        (CharacterSetByte.upperA...CharacterSetByte.upperZ).contains(byte) ||
            (CharacterSetByte.lowerA...CharacterSetByte.lowerZ).contains(byte)
    }

    private static func isASCIIDigit(_ byte: UInt8) -> Bool {
        (CharacterSetByte.zero...CharacterSetByte.nine).contains(byte)
    }

    private enum CharacterSetByte {
        static let upperA = UInt8(ascii: "A")
        static let upperT = UInt8(ascii: "T")
        static let upperZ = UInt8(ascii: "Z")
        static let lowerA = UInt8(ascii: "a")
        static let lowerZ = UInt8(ascii: "z")
        static let zero = UInt8(ascii: "0")
        static let nine = UInt8(ascii: "9")
        static let ampersand = UInt8(ascii: "&")
        static let at = UInt8(ascii: "@")
        static let backslash = UInt8(ascii: "\\")
        static let closeBracket = UInt8(ascii: "]")
        static let closeParen = UInt8(ascii: ")")
        static let colon = UInt8(ascii: ":")
        static let comma = UInt8(ascii: ",")
        static let doubleQuote = UInt8(ascii: "\"")
        static let dollar = UInt8(ascii: "$")
        static let equal = UInt8(ascii: "=")
        static let exclamation = UInt8(ascii: "!")
        static let hash = UInt8(ascii: "#")
        static let hyphen = UInt8(ascii: "-")
        static let openBracket = UInt8(ascii: "[")
        static let openParen = UInt8(ascii: "(")
        static let percent = UInt8(ascii: "%")
        static let period = UInt8(ascii: ".")
        static let plus = UInt8(ascii: "+")
        static let question = UInt8(ascii: "?")
        static let semicolon = UInt8(ascii: ";")
        static let singleQuote = UInt8(ascii: "'")
        static let slash = UInt8(ascii: "/")
        static let space = UInt8(ascii: " ")
        static let star = UInt8(ascii: "*")
        static let tilde = UInt8(ascii: "~")
        static let underscore = UInt8(ascii: "_")
    }
}
