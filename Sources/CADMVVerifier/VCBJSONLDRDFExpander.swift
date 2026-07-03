import Foundation

enum VCBJSONLDRDFExpander {
    private static let rdfType = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
    private static let xsdDateTime = "http://www.w3.org/2001/XMLSchema#dateTime"
    private static let xsdInteger = "http://www.w3.org/2001/XMLSchema#integer"
    private static let securityMultibase = "https://w3id.org/security#multibase"
    private static let vc = "https://www.w3.org/2018/credentials#"
    private static let vcb = "https://w3id.org/vc-barcodes#"

    static func canonicalNQuads(_ credential: DMVVerifiableCredential) throws -> String {
        try RDFDatasetCanonicalizer.canonicalNQuads(documentQuads(credential))
    }

    static func documentQuads(_ credential: DMVVerifiableCredential) -> [RDFQuad] {
        var quads = rootQuads(credential)
        quads.append(contentsOf: credentialSubjectQuads(credential.credentialSubject))
        if let status = credential.credentialStatus {
            quads.append(contentsOf: credentialStatusQuads(status))
        }
        return quads
    }

    private static func rootQuads(_ credential: DMVVerifiableCredential) -> [RDFQuad] {
        var quads: [RDFQuad] = credential.type.map { type in
            RDFQuad(
                subject: .blank("root"),
                predicate: rdfType,
                object: .iri(typeIRI(type))
            )
        }

        quads.append(contentsOf: [
            RDFQuad(
                subject: .blank("root"),
                predicate: vc + "credentialSubject",
                object: .blank("subject")
            ),
            RDFQuad(
                subject: .blank("root"),
                predicate: vc + "issuer",
                object: .iri(credential.issuer)
            )
        ])

        if credential.credentialStatus != nil {
            quads.append(RDFQuad(
                subject: .blank("root"),
                predicate: vc + "credentialStatus",
                object: .blank("status")
            ))
        }

        if let validFrom = credential.validFrom {
            quads.append(RDFQuad(
                subject: .blank("root"),
                predicate: vc + "validFrom",
                object: .literal(value: validFrom, datatype: xsdDateTime)
            ))
        }
        if let validUntil = credential.validUntil {
            quads.append(RDFQuad(
                subject: .blank("root"),
                predicate: vc + "validUntil",
                object: .literal(value: validUntil, datatype: xsdDateTime)
            ))
        }

        return quads
    }

    private static func credentialSubjectQuads(
        _ subject: DMVVerifiableCredential.CredentialSubject
    ) -> [RDFQuad] {
        [
            RDFQuad(
                subject: .blank("subject"),
                predicate: rdfType,
                object: .iri(typeIRI(subject.type))
            ),
            RDFQuad(
                subject: .blank("subject"),
                predicate: vcb + "protectedComponentIndex",
                object: .literal(
                    value: subject.protectedComponentIndex,
                    datatype: securityMultibase
                )
            )
        ]
    }

    private static func credentialStatusQuads(
        _ status: DMVVerifiableCredential.CredentialStatus
    ) -> [RDFQuad] {
        [
            RDFQuad(
                subject: .blank("status"),
                predicate: rdfType,
                object: .iri(typeIRI(status.type))
            ),
            RDFQuad(
                subject: .blank("status"),
                predicate: vcb + "terseStatusListBaseUrl",
                object: .iri(status.terseStatusListBaseURL)
            ),
            RDFQuad(
                subject: .blank("status"),
                predicate: vcb + "terseStatusListIndex",
                object: .literal(
                    value: String(status.terseStatusListIndex),
                    datatype: xsdInteger
                )
            )
        ]
    }

    private static func typeIRI(_ value: String) -> String {
        switch value {
        case "VerifiableCredential":
            return vc + value
        default:
            return vcb + value
        }
    }
}
