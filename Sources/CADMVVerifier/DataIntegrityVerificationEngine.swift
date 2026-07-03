import Foundation

protocol DataIntegrityVerificationEngine: Sendable {
    func verifyVCB(
        credential: DMVVerifiableCredential,
        opticalDataHash: Data,
        verificationKey: DIDDocumentKey
    ) throws -> Bool

    func verifyStatusListCredential(
        _ credential: DMVStatusListCredential,
        verificationKey: DIDDocumentKey
    ) throws -> Bool
}

struct SupportedProfileDataIntegrityEngine: DataIntegrityVerificationEngine {
    static let shared = SupportedProfileDataIntegrityEngine()

    func verifyVCB(
        credential: DMVVerifiableCredential,
        opticalDataHash: Data,
        verificationKey: DIDDocumentKey
    ) throws -> Bool {
        try EcdsaXi2023Verifier.verify(
            credential: credential,
            opticalDataHash: opticalDataHash,
            verificationKey: verificationKey
        )
    }

    func verifyStatusListCredential(
        _ credential: DMVStatusListCredential,
        verificationKey: DIDDocumentKey
    ) throws -> Bool {
        try EcdsaRdfc2019Verifier.verify(
            credential: credential,
            verificationKey: verificationKey
        )
    }
}
