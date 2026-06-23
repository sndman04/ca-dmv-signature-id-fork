import Crypto
import Foundation

enum EcdsaXi2023Verifier {
    static func verify(
        credential: DMVVerifiableCredential,
        opticalDataHash: Data,
        verificationKey: DIDDocumentKey
    ) throws -> Bool {
        guard credential.proof.verificationMethod == verificationKey.id else {
            throw CADMVInternalError.unsupportedVCB
        }

        let verifyData = try createVerifyData(
            credential: credential,
            opticalDataHash: opticalDataHash
        )
        return try ECDSAProofVerifier.verifyP256Signature(
            proofValue: credential.proof.proofValue,
            verifyData: verifyData,
            verificationKey: verificationKey,
            error: .unsupportedVCB
        )
    }

    static func createVerifyData(
        credential: DMVVerifiableCredential,
        opticalDataHash: Data
    ) throws -> Data {
        let proofHash = Data(SHA256.hash(data: Data(proofCanonicalNQuads(credential).utf8)))
        let documentHash = Data(SHA256.hash(data: Data(documentCanonicalNQuads(credential).utf8)))
        let externalHash = Data(SHA256.hash(data: opticalDataHash))

        var data = Data()
        data.append(proofHash)
        data.append(documentHash)
        data.append(externalHash)
        return data
    }

    private static func proofCanonicalNQuads(_ credential: DMVVerifiableCredential) -> String {
        [
            "_:c14n0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://w3id.org/security#\(credential.proof.type)> .",
            "_:c14n0 <https://w3id.org/security#cryptosuite> \"\(credential.proof.cryptosuite)\"^^<https://w3id.org/security#cryptosuiteString> .",
            "_:c14n0 <https://w3id.org/security#proofPurpose> <https://w3id.org/security#\(credential.proof.proofPurpose)> .",
            "_:c14n0 <https://w3id.org/security#verificationMethod> <\(credential.proof.verificationMethod)> ."
        ].joined(separator: "\n") + "\n"
    }

    private static func documentCanonicalNQuads(_ credential: DMVVerifiableCredential) -> String {
        let status = credential.credentialStatus
        var lines = [
            "_:c14n0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://w3id.org/vc-barcodes#OpticalBarcodeCredential> .",
            "_:c14n0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://www.w3.org/2018/credentials#VerifiableCredential> ."
        ]

        if status != nil {
            lines.append("_:c14n0 <https://www.w3.org/2018/credentials#credentialStatus> _:c14n2 .")
        }

        lines.append(contentsOf: [
            "_:c14n0 <https://www.w3.org/2018/credentials#credentialSubject> _:c14n1 .",
            "_:c14n0 <https://www.w3.org/2018/credentials#issuer> <\(credential.issuer)> .",
            "_:c14n1 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://w3id.org/vc-barcodes#\(credential.credentialSubject.type)> .",
            "_:c14n1 <https://w3id.org/vc-barcodes#protectedComponentIndex> \"\(credential.credentialSubject.protectedComponentIndex)\"^^<https://w3id.org/security#multibase> ."
        ])

        if let status {
            lines.append(contentsOf: [
                "_:c14n2 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://w3id.org/vc-barcodes#\(status.type)> .",
                "_:c14n2 <https://w3id.org/vc-barcodes#terseStatusListBaseUrl> <\(status.terseStatusListBaseURL)> .",
                "_:c14n2 <https://w3id.org/vc-barcodes#terseStatusListIndex> \"\(status.terseStatusListIndex)\"^^<http://www.w3.org/2001/XMLSchema#integer> ."
            ])
        }

        return lines.joined(separator: "\n") + "\n"
    }
}
