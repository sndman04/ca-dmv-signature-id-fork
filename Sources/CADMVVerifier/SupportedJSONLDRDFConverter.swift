enum SupportedJSONLDValue: Equatable {
    case string(String)
    case unsigned(UInt64)
    case array([SupportedJSONLDValue])
    case object([String: SupportedJSONLDValue])
}

enum SupportedJSONLDRDFConverter {
    private static let rdfType = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
    private static let xsdDateTime = "http://www.w3.org/2001/XMLSchema#dateTime"
    private static let xsdInteger = "http://www.w3.org/2001/XMLSchema#integer"
    private static let securityMultibase = "https://w3id.org/security#multibase"
    private static let vc = "https://www.w3.org/2018/credentials#"
    private static let vcb = "https://w3id.org/vc-barcodes#"

    static func canonicalNQuads(
        document: [String: SupportedJSONLDValue]
    ) throws -> String {
        try RDFDatasetCanonicalizer.canonicalNQuads(quads(from: document))
    }

    static func quads(
        from document: [String: SupportedJSONLDValue]
    ) throws -> [RDFQuad] {
        try requireSupportedContexts(document["@context"])
        return try nodeQuads(
            document,
            subject: .blank("root"),
            nodeKind: .credentialRoot
        )
    }

    private static func nodeQuads(
        _ object: [String: SupportedJSONLDValue],
        subject: RDFTerm,
        nodeKind: NodeKind
    ) throws -> [RDFQuad] {
        var quads: [RDFQuad] = []
        for key in object.keys.sorted() {
            guard key != "@context" else {
                continue
            }
            let value = object[key]
            switch (nodeKind, key, value) {
            case (_, "type", .some(let value)):
                quads.append(contentsOf: try typeQuads(value, subject: subject))
            case (.credentialRoot, "issuer", .some(.string(let issuer))):
                quads.append(RDFQuad(
                    subject: subject,
                    predicate: vc + "issuer",
                    object: .iri(issuer)
                ))
            case (.credentialRoot, "credentialSubject", .some(.object(let nested))):
                let nestedSubject = RDFTerm.blank("credentialSubject")
                quads.append(RDFQuad(
                    subject: subject,
                    predicate: vc + "credentialSubject",
                    object: nestedSubject
                ))
                quads.append(contentsOf: try nodeQuads(
                    nested,
                    subject: nestedSubject,
                    nodeKind: .credentialSubject
                ))
            case (.credentialRoot, "credentialStatus", .some(.object(let nested))):
                let nestedSubject = RDFTerm.blank("credentialStatus")
                quads.append(RDFQuad(
                    subject: subject,
                    predicate: vc + "credentialStatus",
                    object: nestedSubject
                ))
                quads.append(contentsOf: try nodeQuads(
                    nested,
                    subject: nestedSubject,
                    nodeKind: .credentialStatus
                ))
            case (.credentialRoot, "validFrom", .some(.string(let dateTime))):
                quads.append(try dateTimeQuad(
                    subject: subject,
                    predicate: vc + "validFrom",
                    value: dateTime
                ))
            case (.credentialRoot, "validUntil", .some(.string(let dateTime))):
                quads.append(try dateTimeQuad(
                    subject: subject,
                    predicate: vc + "validUntil",
                    value: dateTime
                ))
            case (.credentialSubject, "protectedComponentIndex", .some(.string(let multibase))):
                quads.append(RDFQuad(
                    subject: subject,
                    predicate: vcb + "protectedComponentIndex",
                    object: .literal(value: multibase, datatype: securityMultibase)
                ))
            case (.credentialStatus, "terseStatusListBaseUrl", .some(.string(let url))):
                quads.append(RDFQuad(
                    subject: subject,
                    predicate: vcb + "terseStatusListBaseUrl",
                    object: .iri(url)
                ))
            case (.credentialStatus, "terseStatusListIndex", .some(.unsigned(let index))):
                quads.append(RDFQuad(
                    subject: subject,
                    predicate: vcb + "terseStatusListIndex",
                    object: .literal(value: String(index), datatype: xsdInteger)
                ))
            default:
                throw CADMVInternalError.unsupportedVCB
            }
        }
        return quads
    }

    private static func typeQuads(
        _ value: SupportedJSONLDValue,
        subject: RDFTerm
    ) throws -> [RDFQuad] {
        let values: [String]
        switch value {
        case .string(let text):
            values = [text]
        case .array(let array):
            values = try array.map { item in
                guard case .string(let text) = item else {
                    throw CADMVInternalError.unsupportedVCB
                }
                return text
            }
        default:
            throw CADMVInternalError.unsupportedVCB
        }

        return try values.map {
            RDFQuad(
                subject: subject,
                predicate: rdfType,
                object: .iri(try typeIRI($0))
            )
        }
    }

    private static func dateTimeQuad(
        subject: RDFTerm,
        predicate: String,
        value: String
    ) throws -> RDFQuad {
        guard DMVVCBDecoder.isSafeDateTimeTextForRDF(value) else {
            throw CADMVInternalError.unsupportedVCB
        }
        return RDFQuad(
            subject: subject,
            predicate: predicate,
            object: .literal(value: value, datatype: xsdDateTime)
        )
    }

    private static func requireSupportedContexts(_ value: SupportedJSONLDValue?) throws {
        guard case .array(let contexts) = value else {
            throw CADMVInternalError.unsupportedVCB
        }
        let strings = try contexts.map { value in
            guard case .string(let context) = value else {
                throw CADMVInternalError.unsupportedVCB
            }
            return context
        }
        guard strings == [
            "https://www.w3.org/ns/credentials/v2",
            "https://w3id.org/vc-barcodes/v1"
        ] else {
            throw CADMVInternalError.unsupportedVCB
        }
    }

    private static func typeIRI(_ value: String) throws -> String {
        switch value {
        case "VerifiableCredential":
            return vc + value
        case "OpticalBarcodeCredential",
             "AamvaDriversLicenseScannableInformation",
             "TerseBitstringStatusListEntry":
            return vcb + value
        default:
            throw CADMVInternalError.unsupportedVCB
        }
    }
}

private enum NodeKind {
    case credentialRoot
    case credentialSubject
    case credentialStatus
}
