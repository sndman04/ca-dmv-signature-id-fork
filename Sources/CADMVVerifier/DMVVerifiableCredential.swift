import Foundation

struct DMVVerifiableCredential: Equatable, Sendable {
    let context: [String]
    let type: [String]
    let issuer: String
    let credentialSubject: CredentialSubject
    let credentialStatus: CredentialStatus?
    let proof: Proof

    struct CredentialSubject: Equatable, Sendable {
        let type: String
        let protectedComponentIndex: String
    }

    struct CredentialStatus: Equatable, Sendable {
        let type: String
        let terseStatusListBaseURL: String
        let terseStatusListIndex: UInt64
    }

    struct Proof: Equatable, Sendable {
        let type: String
        let created: String?
        let cryptosuite: String
        let proofPurpose: String
        let proofValue: String
        let verificationMethod: String
    }
}
