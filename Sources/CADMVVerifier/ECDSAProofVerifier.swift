import Crypto
import Foundation

enum ECDSAProofVerifier {
    static func verifyP256Signature(
        proofValue: String,
        verifyData: Data,
        verificationKey: DIDDocumentKey,
        error: CADMVInternalError
    ) throws -> Bool {
        let signature = try rawSignature(from: proofValue, error: error)
        let publicKey = try P256.Signing.PublicKey(
            compressedRepresentation: verificationKey.compressedP256Key
        )
        let ecdsaSignature = try P256.Signing.ECDSASignature(rawRepresentation: signature)
        return publicKey.isValidSignature(ecdsaSignature, for: verifyData)
    }

    static func rawSignature(from proofValue: String, error: CADMVInternalError) throws -> Data {
        guard let multibasePrefix = proofValue.first else {
            throw error
        }
        let encoded = String(proofValue.dropFirst())
        let signature: Data?
        switch multibasePrefix {
        case "z":
            signature = Base58BTC.decode(encoded)
        case "u":
            signature = Base64URL.decode(encoded)
        default:
            signature = nil
        }
        guard let signature, signature.count == 64 else {
            throw error
        }
        return signature
    }
}
