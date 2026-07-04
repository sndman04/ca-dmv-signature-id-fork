import Crypto
import Foundation

enum EcdsaXi2023Verifier {
    // DMV profile verifier. It builds the supported JSON-LD graph explicitly
    // and derives canonical blank-node labels instead of guessing c14n order.
    static func verify(
        credential: DMVVerifiableCredential,
        opticalDataHash: Data,
        verificationKey: DIDDocumentKey,
        engine: any JSONLDCanonicalizationEngine =
            ProductionJSONLDCanonicalizationEngine.shared
    ) throws -> Bool {
        guard credential.proof.verificationMethod == verificationKey.id else {
            throw CADMVInternalError.unsupportedVCB
        }

        let verifyData = try createVerifyData(
            credential: credential,
            opticalDataHash: opticalDataHash,
            engine: engine
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
        opticalDataHash: Data,
        engine: any JSONLDCanonicalizationEngine =
            ProductionJSONLDCanonicalizationEngine.shared
    ) throws -> Data {
        let proofHash = Data(SHA256.hash(data: Data(try DataIntegrityProofCanonicalizer.canonicalNQuads(
            contexts: credential.context,
            type: credential.proof.type,
            created: credential.proof.created,
            expires: credential.proof.expires,
            cryptosuite: credential.proof.cryptosuite,
            proofPurpose: credential.proof.proofPurpose,
            verificationMethod: credential.proof.verificationMethod,
            additionalProperties: credential.proof.additionalProperties,
            engine: engine
        ).utf8)))
        let documentHash = Data(SHA256.hash(data: Data(try VCBJSONLDRDFExpander.canonicalNQuads(
            credential,
            engine: engine
        ).utf8)))
        let externalHash = Data(SHA256.hash(data: opticalDataHash))

        var data = Data()
        data.append(proofHash)
        data.append(documentHash)
        data.append(externalHash)
        return data
    }
}

enum DataIntegrityProofCanonicalizer {
    static func canonicalNQuads(
        contexts: [String] = ["https://www.w3.org/ns/credentials/v2"],
        type: String,
        created: String?,
        expires: String?,
        cryptosuite: String,
        proofPurpose: String,
        verificationMethod: String,
        additionalProperties: [String: SupportedJSONLDValue] = [:],
        engine: any JSONLDCanonicalizationEngine = ProductionJSONLDCanonicalizationEngine.shared
    ) throws -> String {
        try engine.canonicalNQuads(
            document: jsonLDDocument(
                contexts: contexts,
                type: type,
                created: created,
                expires: expires,
                cryptosuite: cryptosuite,
                proofPurpose: proofPurpose,
                verificationMethod: verificationMethod,
                additionalProperties: additionalProperties
            ),
            profile: .dataIntegrityProof
        )
    }

    static func jsonLDDocument(
        contexts: [String] = ["https://www.w3.org/ns/credentials/v2"],
        type: String,
        created: String?,
        expires: String?,
        cryptosuite: String,
        proofPurpose: String,
        verificationMethod: String,
        additionalProperties: [String: SupportedJSONLDValue] = [:]
    ) -> [String: SupportedJSONLDValue] {
        var document: [String: SupportedJSONLDValue] = [
            "@context": .array(contexts.map { .string($0) }),
            "type": .string(type),
            "cryptosuite": .string(cryptosuite),
            "proofPurpose": .string(proofPurpose),
            "verificationMethod": .string(verificationMethod)
        ]
        if let created {
            document["created"] = .string(created)
        }
        if let expires {
            document["expires"] = .string(expires)
        }
        for (key, value) in additionalProperties {
            document[key] = value
        }
        return document
    }
}

enum SupportedProofJSONLDRDFConverter {
    static func quads(
        from document: [String: SupportedJSONLDValue]
    ) throws -> [RDFQuad] {
        try PinnedJSONLDTermRegistry.requireProofContexts(document["@context"])
        var quads: [RDFQuad] = []
        var genericBlankNodeCounter = 0
        for key in document.keys.sorted() {
            guard key != "@context" else {
                continue
            }
            let value = document[key]
            switch (key, value) {
            case ("type", .some(.string(let type))):
                quads.append(SupportedJSONLDRDFTerms.iriQuad(
                    subject: .blank("proof"),
                    predicate: PinnedJSONLDTermRegistry.rdfType,
                    iri: try PinnedJSONLDTermRegistry.proofTypeIRI(type)
                ))
            case ("cryptosuite", .some(.string(let cryptosuite))):
                guard cryptosuite == "ecdsa-xi-2023" || cryptosuite == "ecdsa-rdfc-2019" else {
                    throw CADMVInternalError.unsupportedVCB
                }
                quads.append(SupportedJSONLDRDFTerms.literalQuad(
                    subject: .blank("proof"),
                    predicate: try PinnedJSONLDTermRegistry.proofPredicate(key),
                    value: cryptosuite,
                    datatype: PinnedJSONLDTermRegistry.cryptosuiteStringDatatype
                ))
            case ("proofPurpose", .some(.string(let proofPurpose))):
                guard proofPurpose == "assertionMethod" else {
                    throw CADMVInternalError.unsupportedVCB
                }
                quads.append(SupportedJSONLDRDFTerms.iriQuad(
                    subject: .blank("proof"),
                    predicate: try PinnedJSONLDTermRegistry.proofPredicate(key),
                    iri: PinnedJSONLDTermRegistry.securityIRI(proofPurpose)
                ))
            case ("verificationMethod", .some(.string(let verificationMethod))):
                quads.append(SupportedJSONLDRDFTerms.iriQuad(
                    subject: .blank("proof"),
                    predicate: try PinnedJSONLDTermRegistry.proofPredicate(key),
                    iri: verificationMethod
                ))
            case ("created", .some(.string(let dateTime))):
                quads.append(try SupportedJSONLDRDFTerms.dateTimeQuad(
                    subject: .blank("proof"),
                    predicate: try PinnedJSONLDTermRegistry.proofPredicate(key),
                    value: dateTime,
                    error: .unsupportedVCB
                ))
            case ("expires", .some(.string(let dateTime))):
                quads.append(try SupportedJSONLDRDFTerms.dateTimeQuad(
                    subject: .blank("proof"),
                    predicate: try PinnedJSONLDTermRegistry.proofPredicate(key),
                    value: dateTime,
                    error: .unsupportedVCB
                ))
            default:
                if let value,
                   let genericQuads = try SupportedJSONLDRDFTerms.genericAbsoluteIRIQuads(
                    key: key,
                    value: value,
                    subject: .blank("proof"),
                    error: .unsupportedVCB,
                    blankNodeCounter: &genericBlankNodeCounter
                ) {
                    quads.append(contentsOf: genericQuads)
                    continue
                }
                throw CADMVInternalError.unsupportedVCB
            }
        }
        return quads
    }

}
