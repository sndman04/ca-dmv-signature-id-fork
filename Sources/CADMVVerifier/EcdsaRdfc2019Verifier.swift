import Crypto
import Foundation

enum EcdsaRdfc2019Verifier {
    // DMV status-list profile verifier. Document canonicalization flows through
    // the native Swift JSON-LD/RDF engine and fails closed for unsupported
    // signed data outside the DMV status-list profile.
    static func verify(
        credential: DMVStatusListCredential,
        verificationKey: DIDDocumentKey,
        engine: any JSONLDCanonicalizationEngine =
            ProductionJSONLDCanonicalizationEngine.shared
    ) throws -> Bool {
        guard credential.proof.verificationMethod == verificationKey.id,
              credential.issuer == verificationKey.controller else {
            throw CADMVInternalError.statusListDecodeFailed
        }

        let verifyData = try createVerifyData(
            credential,
            engine: engine
        )
        return try ECDSAProofVerifier.verifyP256Signature(
            proofValue: credential.proof.proofValue,
            verifyData: verifyData,
            verificationKey: verificationKey,
            error: .statusListDecodeFailed
        )
    }

    static func createVerifyData(
        _ credential: DMVStatusListCredential,
        engine: any JSONLDCanonicalizationEngine =
            ProductionJSONLDCanonicalizationEngine.shared
    ) throws -> Data {
        let proofHash = Data(SHA256.hash(data: Data(try DataIntegrityProofCanonicalizer.canonicalNQuads(
            contexts: ["https://www.w3.org/ns/credentials/v2"],
            type: credential.proof.type,
            created: credential.proof.created,
            expires: nil,
            cryptosuite: credential.proof.cryptosuite,
            proofPurpose: credential.proof.proofPurpose,
            verificationMethod: credential.proof.verificationMethod,
            additionalProperties: credential.proof.additionalProperties,
            engine: engine
        ).utf8)))
        let documentHash = Data(SHA256.hash(data: Data(try documentCanonicalNQuads(
            credential,
            engine: engine
        ).utf8)))

        var data = Data()
        data.append(proofHash)
        data.append(documentHash)
        return data
    }

    private static func documentCanonicalNQuads(
        _ credential: DMVStatusListCredential,
        engine: any JSONLDCanonicalizationEngine
    ) throws -> String {
        try StatusListJSONLDRDFExpander.canonicalNQuads(
            credential,
            engine: engine
        )
    }
}
