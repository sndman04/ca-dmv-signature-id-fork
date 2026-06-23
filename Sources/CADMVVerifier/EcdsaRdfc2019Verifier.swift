import Crypto
import Foundation

enum EcdsaRdfc2019Verifier {
    static func verify(
        credential: DMVStatusListCredential,
        verificationKey: DIDDocumentKey
    ) throws -> Bool {
        guard credential.proof.verificationMethod == verificationKey.id,
              credential.issuer == verificationKey.controller else {
            throw CADMVInternalError.statusListDecodeFailed
        }

        let verifyData = try createVerifyData(credential)
        let signature = try signature(from: credential.proof.proofValue)
        let publicKey = try P256.Signing.PublicKey(
            compressedRepresentation: verificationKey.compressedP256Key
        )
        let ecdsaSignature = try P256.Signing.ECDSASignature(rawRepresentation: signature)

        return publicKey.isValidSignature(ecdsaSignature, for: verifyData)
    }

    static func createVerifyData(_ credential: DMVStatusListCredential) throws -> Data {
        let proofHash = Data(SHA256.hash(data: Data(proofCanonicalNQuads(credential).utf8)))
        let documentHash = Data(SHA256.hash(data: Data(documentCanonicalNQuads(credential).utf8)))

        var data = Data()
        data.append(proofHash)
        data.append(documentHash)
        return data
    }

    private static func proofCanonicalNQuads(_ credential: DMVStatusListCredential) -> String {
        var lines: [String] = []
        if let created = credential.proof.created {
            lines.append("_:c14n0 <http://purl.org/dc/terms/created> \"\(created)\"^^<http://www.w3.org/2001/XMLSchema#dateTime> .")
        }
        lines.append(contentsOf: [
            "_:c14n0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://w3id.org/security#\(credential.proof.type)> .",
            "_:c14n0 <https://w3id.org/security#cryptosuite> \"\(credential.proof.cryptosuite)\"^^<https://w3id.org/security#cryptosuiteString> .",
            "_:c14n0 <https://w3id.org/security#proofPurpose> <https://w3id.org/security#\(credential.proof.proofPurpose)> .",
            "_:c14n0 <https://w3id.org/security#verificationMethod> <\(credential.proof.verificationMethod)> ."
        ])
        return lines.joined(separator: "\n") + "\n"
    }

    private static func documentCanonicalNQuads(_ credential: DMVStatusListCredential) -> String {
        var lines = [
            "<\(credential.credentialSubject.id)> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://www.w3.org/ns/credentials/status#\(credential.credentialSubject.type)> .",
            "<\(credential.credentialSubject.id)> <https://www.w3.org/ns/credentials/status#encodedList> \"\(credential.credentialSubject.encodedList)\"^^<https://w3id.org/security#multibase> .",
            "<\(credential.credentialSubject.id)> <https://www.w3.org/ns/credentials/status#statusPurpose> \"\(credential.credentialSubject.statusPurpose)\" .",
            "<\(credential.id)> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://www.w3.org/2018/credentials#VerifiableCredential> .",
            "<\(credential.id)> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://www.w3.org/ns/credentials/status#BitstringStatusListCredential> .",
            "<\(credential.id)> <https://www.w3.org/2018/credentials#credentialSubject> <\(credential.credentialSubject.id)> .",
            "<\(credential.id)> <https://www.w3.org/2018/credentials#issuer> <\(credential.issuer)> ."
        ]

        if let validFrom = credential.validFrom {
            lines.append("<\(credential.id)> <https://www.w3.org/2018/credentials#validFrom> \"\(validFrom)\"^^<http://www.w3.org/2001/XMLSchema#dateTime> .")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func signature(from proofValue: String) throws -> Data {
        guard proofValue.first == "z",
              let signature = Base58BTC.decode(String(proofValue.dropFirst())),
              signature.count == 64 else {
            throw CADMVInternalError.statusListDecodeFailed
        }
        return signature
    }
}
