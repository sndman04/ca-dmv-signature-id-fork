import Crypto
import Foundation

enum EcdsaRdfc2019Verifier {
    // DMV status-list profile verifier. It builds the supported graph
    // explicitly until replaced by standards-grade JSON-LD/RDF canonicalization.
    static func verify(
        credential: DMVStatusListCredential,
        verificationKey: DIDDocumentKey
    ) throws -> Bool {
        guard credential.proof.verificationMethod == verificationKey.id,
              credential.issuer == verificationKey.controller else {
            throw CADMVInternalError.statusListDecodeFailed
        }

        let verifyData = try createVerifyData(credential)
        return try ECDSAProofVerifier.verifyP256Signature(
            proofValue: credential.proof.proofValue,
            verifyData: verifyData,
            verificationKey: verificationKey,
            error: .statusListDecodeFailed
        )
    }

    static func createVerifyData(_ credential: DMVStatusListCredential) throws -> Data {
        let proofHash = Data(SHA256.hash(data: Data(try DataIntegrityProofCanonicalizer.canonicalNQuads(
            type: credential.proof.type,
            created: credential.proof.created,
            expires: nil,
            cryptosuite: credential.proof.cryptosuite,
            proofPurpose: credential.proof.proofPurpose,
            verificationMethod: credential.proof.verificationMethod
        ).utf8)))
        let documentHash = Data(SHA256.hash(data: Data(try documentCanonicalNQuads(credential).utf8)))

        var data = Data()
        data.append(proofHash)
        data.append(documentHash)
        return data
    }

    private static func documentCanonicalNQuads(_ credential: DMVStatusListCredential) throws -> String {
        var quads: [RDFQuad] = [
            RDFQuad(
                subject: .iri(credential.credentialSubject.id),
                predicate: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type",
                object: .iri("https://www.w3.org/ns/credentials/status#\(credential.credentialSubject.type)")
            ),
            RDFQuad(
                subject: .iri(credential.credentialSubject.id),
                predicate: "https://www.w3.org/ns/credentials/status#encodedList",
                object: .literal(
                    value: credential.credentialSubject.encodedList,
                    datatype: "https://w3id.org/security#multibase"
                )
            ),
            RDFQuad(
                subject: .iri(credential.credentialSubject.id),
                predicate: "https://www.w3.org/ns/credentials/status#statusPurpose",
                object: .literal(value: credential.credentialSubject.statusPurpose, datatype: nil)
            ),
            RDFQuad(
                subject: .iri(credential.id),
                predicate: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type",
                object: .iri("https://www.w3.org/2018/credentials#VerifiableCredential")
            ),
            RDFQuad(
                subject: .iri(credential.id),
                predicate: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type",
                object: .iri("https://www.w3.org/ns/credentials/status#BitstringStatusListCredential")
            ),
            RDFQuad(
                subject: .iri(credential.id),
                predicate: "https://www.w3.org/2018/credentials#credentialSubject",
                object: .iri(credential.credentialSubject.id)
            ),
            RDFQuad(
                subject: .iri(credential.id),
                predicate: "https://www.w3.org/2018/credentials#issuer",
                object: .iri(credential.issuer)
            )
        ]

        if let description = credential.description {
            quads.append(RDFQuad(
                subject: .iri(credential.id),
                predicate: "https://schema.org/description",
                object: .literal(value: description, datatype: nil)
            ))
        }

        if let name = credential.name {
            quads.append(RDFQuad(
                subject: .iri(credential.id),
                predicate: "https://schema.org/name",
                object: .literal(value: name, datatype: nil)
            ))
        }

        if let validFrom = credential.validFrom {
            quads.append(RDFQuad(
                subject: .iri(credential.id),
                predicate: "https://www.w3.org/2018/credentials#validFrom",
                object: .literal(value: validFrom, datatype: "http://www.w3.org/2001/XMLSchema#dateTime")
            ))
        }

        if let validUntil = credential.validUntil {
            quads.append(RDFQuad(
                subject: .iri(credential.id),
                predicate: "https://www.w3.org/2018/credentials#validUntil",
                object: .literal(value: validUntil, datatype: "http://www.w3.org/2001/XMLSchema#dateTime")
            ))
        }

        return try RDFDatasetCanonicalizer.canonicalNQuads(quads)
    }
}
