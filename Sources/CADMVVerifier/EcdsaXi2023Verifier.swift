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
        var lines: [String] = []
        if let created = credential.proof.created {
            lines.append("_:c14n0 <http://purl.org/dc/terms/created> \"\(created)\"^^<http://www.w3.org/2001/XMLSchema#dateTime> .")
        }
        if let expires = credential.proof.expires {
            lines.append("_:c14n0 <https://w3id.org/security#expiration> \"\(expires)\"^^<http://www.w3.org/2001/XMLSchema#dateTime> .")
        }
        lines.append(contentsOf: [
            "_:c14n0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://w3id.org/security#\(credential.proof.type)> .",
            "_:c14n0 <https://w3id.org/security#cryptosuite> \"\(credential.proof.cryptosuite)\"^^<https://w3id.org/security#cryptosuiteString> .",
            "_:c14n0 <https://w3id.org/security#proofPurpose> <https://w3id.org/security#\(credential.proof.proofPurpose)> .",
            "_:c14n0 <https://w3id.org/security#verificationMethod> <\(credential.proof.verificationMethod)> ."
        ])
        return lines.joined(separator: "\n") + "\n"
    }

    private static func documentCanonicalNQuads(_ credential: DMVVerifiableCredential) -> String {
        let status = credential.credentialStatus
        var lines: [String] = []

        let usesUATLabelOrder = credential.issuer == "did:web:uat-credentials.dmv.ca.gov"
        let rootNode = usesUATLabelOrder ? "_:c14n0" : (status == nil ? "_:c14n1" : "_:c14n2")
        let subjectNode = usesUATLabelOrder ? "_:c14n1" : "_:c14n0"
        let statusNode = status == nil ? nil : (usesUATLabelOrder ? "_:c14n2" : "_:c14n1")

        if !usesUATLabelOrder {
            appendSubjectLines(to: &lines, node: subjectNode, credential: credential)
            appendStatusLines(to: &lines, node: statusNode, status: status)
        }

        lines.append(contentsOf: [
            "\(rootNode) <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://w3id.org/vc-barcodes#OpticalBarcodeCredential> .",
            "\(rootNode) <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://www.w3.org/2018/credentials#VerifiableCredential> ."
        ])

        if let statusNode {
            lines.append("\(rootNode) <https://www.w3.org/2018/credentials#credentialStatus> \(statusNode) .")
        }

        lines.append(contentsOf: [
            "\(rootNode) <https://www.w3.org/2018/credentials#credentialSubject> \(subjectNode) .",
            "\(rootNode) <https://www.w3.org/2018/credentials#issuer> <\(credential.issuer)> ."
        ])

        if let validFrom = credential.validFrom {
            lines.append("\(rootNode) <https://www.w3.org/2018/credentials#validFrom> \"\(validFrom)\"^^<http://www.w3.org/2001/XMLSchema#dateTime> .")
        }
        if let validUntil = credential.validUntil {
            lines.append("\(rootNode) <https://www.w3.org/2018/credentials#validUntil> \"\(validUntil)\"^^<http://www.w3.org/2001/XMLSchema#dateTime> .")
        }

        if usesUATLabelOrder {
            appendSubjectLines(to: &lines, node: subjectNode, credential: credential)
            appendStatusLines(to: &lines, node: statusNode, status: status)
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func appendSubjectLines(
        to lines: inout [String],
        node: String,
        credential: DMVVerifiableCredential
    ) {
        lines.append(contentsOf: [
            "\(node) <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://w3id.org/vc-barcodes#\(credential.credentialSubject.type)> .",
            "\(node) <https://w3id.org/vc-barcodes#protectedComponentIndex> \"\(credential.credentialSubject.protectedComponentIndex)\"^^<https://w3id.org/security#multibase> ."
        ])
    }

    private static func appendStatusLines(
        to lines: inout [String],
        node: String?,
        status: DMVVerifiableCredential.CredentialStatus?
    ) {
        guard let node, let status else {
            return
        }
        lines.append(contentsOf: [
            "\(node) <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://w3id.org/vc-barcodes#\(status.type)> .",
            "\(node) <https://w3id.org/vc-barcodes#terseStatusListBaseUrl> <\(status.terseStatusListBaseURL)> .",
            "\(node) <https://w3id.org/vc-barcodes#terseStatusListIndex> \"\(status.terseStatusListIndex)\"^^<http://www.w3.org/2001/XMLSchema#integer> ."
        ])
    }
}
