import Foundation

struct DMVVerifiableCredential: Equatable, Sendable {
    let context: [String]
    let id: String?
    let type: [String]
    let issuer: String
    let validFrom: String?
    let validUntil: String?
    let credentialSubject: CredentialSubject
    let credentialStatus: CredentialStatus?
    let proof: Proof
    let additionalProperties: [String: SupportedJSONLDValue]

    init(
        context: [String],
        id: String? = nil,
        type: [String],
        issuer: String,
        validFrom: String?,
        validUntil: String?,
        credentialSubject: CredentialSubject,
        credentialStatus: CredentialStatus?,
        proof: Proof,
        additionalProperties: [String: SupportedJSONLDValue] = [:]
    ) {
        self.context = context
        self.id = id
        self.type = type
        self.issuer = issuer
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.credentialSubject = credentialSubject
        self.credentialStatus = credentialStatus
        self.proof = proof
        self.additionalProperties = additionalProperties
    }

    struct CredentialSubject: Equatable, Sendable {
        let id: String?
        let type: String
        let protectedComponentIndex: String

        init(
            id: String? = nil,
            type: String,
            protectedComponentIndex: String
        ) {
            self.id = id
            self.type = type
            self.protectedComponentIndex = protectedComponentIndex
        }
    }

    struct CredentialStatus: Equatable, Sendable {
        let id: String?
        let type: String
        let terseStatusListBaseURL: String
        let terseStatusListIndex: UInt64

        init(
            id: String? = nil,
            type: String,
            terseStatusListBaseURL: String,
            terseStatusListIndex: UInt64
        ) {
            self.id = id
            self.type = type
            self.terseStatusListBaseURL = terseStatusListBaseURL
            self.terseStatusListIndex = terseStatusListIndex
        }
    }

    struct Proof: Equatable, Sendable {
        let type: String
        let created: String?
        let expires: String?
        let cryptosuite: String
        let proofPurpose: String
        let proofValue: String
        let verificationMethod: String
        let additionalProperties: [String: SupportedJSONLDValue]

        init(
            type: String,
            created: String?,
            expires: String?,
            cryptosuite: String,
            proofPurpose: String,
            proofValue: String,
            verificationMethod: String,
            additionalProperties: [String: SupportedJSONLDValue] = [:]
        ) {
            self.type = type
            self.created = created
            self.expires = expires
            self.cryptosuite = cryptosuite
            self.proofPurpose = proofPurpose
            self.proofValue = proofValue
            self.verificationMethod = verificationMethod
            self.additionalProperties = additionalProperties
        }
    }
}
