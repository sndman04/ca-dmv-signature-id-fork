import Crypto
import Foundation

enum EcdsaXi2023Verifier {
    // DMV profile verifier. It builds the supported JSON-LD graph explicitly
    // and derives canonical blank-node labels instead of guessing c14n order.
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
        let proofHash = Data(SHA256.hash(data: Data(try DataIntegrityProofCanonicalizer.canonicalNQuads(
            type: credential.proof.type,
            created: credential.proof.created,
            expires: credential.proof.expires,
            cryptosuite: credential.proof.cryptosuite,
            proofPurpose: credential.proof.proofPurpose,
            verificationMethod: credential.proof.verificationMethod
        ).utf8)))
        let documentHash = Data(SHA256.hash(data: Data(try documentCanonicalNQuads(credential).utf8)))
        let externalHash = Data(SHA256.hash(data: opticalDataHash))

        var data = Data()
        data.append(proofHash)
        data.append(documentHash)
        data.append(externalHash)
        return data
    }

    private static func documentCanonicalNQuads(_ credential: DMVVerifiableCredential) throws -> String {
        let status = credential.credentialStatus
        var quads: [RDFQuad] = [
            RDFQuad(
                subject: .blank("root"),
                predicate: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type",
                object: .iri("https://w3id.org/vc-barcodes#OpticalBarcodeCredential")
            ),
            RDFQuad(
                subject: .blank("root"),
                predicate: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type",
                object: .iri("https://www.w3.org/2018/credentials#VerifiableCredential")
            ),
            RDFQuad(
                subject: .blank("root"),
                predicate: "https://www.w3.org/2018/credentials#credentialSubject",
                object: .blank("subject")
            ),
            RDFQuad(
                subject: .blank("root"),
                predicate: "https://www.w3.org/2018/credentials#issuer",
                object: .iri(credential.issuer)
            ),
            RDFQuad(
                subject: .blank("subject"),
                predicate: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type",
                object: .iri("https://w3id.org/vc-barcodes#\(credential.credentialSubject.type)")
            ),
            RDFQuad(
                subject: .blank("subject"),
                predicate: "https://w3id.org/vc-barcodes#protectedComponentIndex",
                object: .literal(
                    value: credential.credentialSubject.protectedComponentIndex,
                    datatype: "https://w3id.org/security#multibase"
                )
            )
        ]

        if status != nil {
            quads.append(RDFQuad(
                subject: .blank("root"),
                predicate: "https://www.w3.org/2018/credentials#credentialStatus",
                object: .blank("status")
            ))
        }

        if let validFrom = credential.validFrom {
            quads.append(RDFQuad(
                subject: .blank("root"),
                predicate: "https://www.w3.org/2018/credentials#validFrom",
                object: .literal(
                    value: validFrom,
                    datatype: "http://www.w3.org/2001/XMLSchema#dateTime"
                )
            ))
        }
        if let validUntil = credential.validUntil {
            quads.append(RDFQuad(
                subject: .blank("root"),
                predicate: "https://www.w3.org/2018/credentials#validUntil",
                object: .literal(
                    value: validUntil,
                    datatype: "http://www.w3.org/2001/XMLSchema#dateTime"
                )
            ))
        }

        if let status {
            quads.append(contentsOf: [
                RDFQuad(
                    subject: .blank("status"),
                    predicate: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type",
                    object: .iri("https://w3id.org/vc-barcodes#\(status.type)")
                ),
                RDFQuad(
                    subject: .blank("status"),
                    predicate: "https://w3id.org/vc-barcodes#terseStatusListBaseUrl",
                    object: .iri(status.terseStatusListBaseURL)
                ),
                RDFQuad(
                    subject: .blank("status"),
                    predicate: "https://w3id.org/vc-barcodes#terseStatusListIndex",
                    object: .literal(
                        value: String(status.terseStatusListIndex),
                        datatype: "http://www.w3.org/2001/XMLSchema#integer"
                    )
                )
            ])
        }

        return try RDFDatasetCanonicalizer.canonicalNQuads(quads)
    }
}

enum RDFTerm: Equatable {
    case blank(String)
    case iri(String)
    case literal(value: String, datatype: String?)

    var blankNodeIdentifier: String? {
        guard case .blank(let identifier) = self else {
            return nil
        }
        return identifier
    }
}

struct RDFQuad: Equatable {
    let subject: RDFTerm
    let predicate: String
    let object: RDFTerm
}

enum RDFDatasetCanonicalizer {
    static func canonicalNQuads(_ quads: [RDFQuad]) throws -> String {
        let identifiers = blankNodeIdentifiers(in: quads)
        let labels = try canonicalLabels(for: identifiers, quads: quads)
        return quads
            .map { render($0, labels: labels) }
            .sorted()
            .joined(separator: "\n") + "\n"
    }

    private static func canonicalLabels(
        for identifiers: [String],
        quads: [RDFQuad]
    ) throws -> [String: String] {
        let hashes = identifiers.map { identifier in
            (
                identifier: identifier,
                hash: firstDegreeHash(identifier: identifier, quads: quads)
            )
        }
        let grouped = Dictionary(grouping: hashes, by: \.hash)
        guard grouped.allSatisfy({ $0.value.count == 1 }) else {
            throw CADMVInternalError.unsupportedVCB
        }
        return Dictionary(uniqueKeysWithValues: hashes
            .sorted {
                if $0.hash == $1.hash {
                    return $0.identifier < $1.identifier
                }
                return $0.hash < $1.hash
            }
            .enumerated()
            .map { index, item in
                (item.identifier, "_:c14n\(index)")
            })
    }

    private static func firstDegreeHash(
        identifier: String,
        quads: [RDFQuad]
    ) -> String {
        let lines = quads
            .filter {
                $0.subject.blankNodeIdentifier == identifier ||
                    $0.object.blankNodeIdentifier == identifier
            }
            .map { quad in
                render(quad) { blankIdentifier in
                    blankIdentifier == identifier ? "_:a" : "_:z"
                }
            }
            .sorted()
        return Data(SHA256.hash(data: Data((lines.joined(separator: "\n") + "\n").utf8)))
            .cadmvHexString
    }

    private static func blankNodeIdentifiers(in quads: [RDFQuad]) -> [String] {
        Array(Set(quads.flatMap { quad -> [String] in
            [
                quad.subject.blankNodeIdentifier,
                quad.object.blankNodeIdentifier
            ].compactMap { $0 }
        })).sorted()
    }

    private static func render(
        _ quad: RDFQuad,
        labels: [String: String]
    ) -> String {
        render(quad) { identifier in
            guard let label = labels[identifier] else {
                preconditionFailure("Missing canonical label for blank node \(identifier)")
            }
            return label
        }
    }

    private static func render(
        _ quad: RDFQuad,
        blankLabel: (String) -> String
    ) -> String {
        "\(render(quad.subject, blankLabel: blankLabel)) <\(quad.predicate)> \(render(quad.object, blankLabel: blankLabel)) ."
    }

    private static func render(
        _ term: RDFTerm,
        blankLabel: (String) -> String
    ) -> String {
        switch term {
        case .blank(let identifier):
            return blankLabel(identifier)
        case .iri(let value):
            return "<\(value)>"
        case let .literal(value, datatype):
            let escaped = value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            if let datatype {
                return "\"\(escaped)\"^^<\(datatype)>"
            }
            return "\"\(escaped)\""
        }
    }
}

enum DataIntegrityProofCanonicalizer {
    static func canonicalNQuads(
        type: String,
        created: String?,
        expires: String?,
        cryptosuite: String,
        proofPurpose: String,
        verificationMethod: String
    ) throws -> String {
        var quads: [RDFQuad] = [
            RDFQuad(
                subject: .blank("proof"),
                predicate: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type",
                object: .iri("https://w3id.org/security#\(type)")
            ),
            RDFQuad(
                subject: .blank("proof"),
                predicate: "https://w3id.org/security#cryptosuite",
                object: .literal(value: cryptosuite, datatype: "https://w3id.org/security#cryptosuiteString")
            ),
            RDFQuad(
                subject: .blank("proof"),
                predicate: "https://w3id.org/security#proofPurpose",
                object: .iri("https://w3id.org/security#\(proofPurpose)")
            ),
            RDFQuad(
                subject: .blank("proof"),
                predicate: "https://w3id.org/security#verificationMethod",
                object: .iri(verificationMethod)
            )
        ]

        if let created {
            quads.append(RDFQuad(
                subject: .blank("proof"),
                predicate: "http://purl.org/dc/terms/created",
                object: .literal(value: created, datatype: "http://www.w3.org/2001/XMLSchema#dateTime")
            ))
        }

        if let expires {
            quads.append(RDFQuad(
                subject: .blank("proof"),
                predicate: "https://w3id.org/security#expiration",
                object: .literal(value: expires, datatype: "http://www.w3.org/2001/XMLSchema#dateTime")
            ))
        }

        return try RDFDatasetCanonicalizer.canonicalNQuads(quads)
    }
}
