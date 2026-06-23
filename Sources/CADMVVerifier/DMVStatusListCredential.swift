import Foundation

struct DMVStatusListCredential: Equatable, Sendable {
    let id: String
    let type: [String]
    let issuer: String
    let validFrom: String?
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
    static func parse(_ data: Data) throws -> DMVStatusListCredential {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let root = json as? [String: Any] else {
            throw CADMVInternalError.statusListDecodeFailed
        }
        try rejectUnknownKeys(
            root,
            allowed: ["@context", "id", "type", "issuer", "validFrom", "credentialSubject", "proof"]
        )

        guard let context = root["@context"] as? [String],
              context == ["https://www.w3.org/ns/credentials/v2"],
              let id = root["id"] as? String,
              let type = root["type"] as? [String],
              let issuer = root["issuer"] as? String,
              let subjectObject = root["credentialSubject"] as? [String: Any],
              let proofObject = root["proof"] as? [String: Any] else {
            throw CADMVInternalError.statusListDecodeFailed
        }

        try rejectUnknownKeys(
            subjectObject,
            allowed: ["id", "type", "encodedList", "statusPurpose"]
        )
        try rejectUnknownKeys(
            proofObject,
            allowed: ["type", "created", "verificationMethod", "cryptosuite", "proofPurpose", "proofValue"]
        )

        guard type.contains("VerifiableCredential"),
              type.contains("BitstringStatusListCredential"),
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
              isSafeOptionalDate(proofObject["created"] as? String) else {
            throw CADMVInternalError.statusListDecodeFailed
        }

        return DMVStatusListCredential(
            id: id,
            type: type,
            issuer: issuer,
            validFrom: root["validFrom"] as? String,
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

    private static func rejectUnknownKeys(
        _ object: [String: Any],
        allowed: Set<String>
    ) throws {
        guard Set(object.keys).isSubset(of: allowed) else {
            throw CADMVInternalError.statusListDecodeFailed
        }
    }

    private static func isSafeIRI(_ value: String) -> Bool {
        !value.isEmpty && value.range(of: #"^[A-Za-z][A-Za-z0-9+.-]*:[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%-]+$"#, options: .regularExpression) != nil
    }

    private static func isSafeToken(_ value: String) -> Bool {
        !value.isEmpty && value.range(of: #"^[A-Za-z0-9._:-]+$"#, options: .regularExpression) != nil
    }

    private static func isSafeMultibase(_ value: String) -> Bool {
        !value.isEmpty && value.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
    }

    private static func isSafeOptionalDate(_ value: String?) -> Bool {
        guard let value else {
            return true
        }
        return value.range(
            of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"#,
            options: .regularExpression
        ) != nil
    }
}
