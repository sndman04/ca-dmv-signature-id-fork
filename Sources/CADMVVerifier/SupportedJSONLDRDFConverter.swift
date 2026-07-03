enum SupportedJSONLDValue: Equatable {
    case string(String)
    case unsigned(UInt64)
    case array([SupportedJSONLDValue])
    case object([String: SupportedJSONLDValue])
}

enum SupportedJSONLDRDFConverter {
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
                    predicate: try PinnedJSONLDTermRegistry.vcbPredicate(key),
                    object: .iri(issuer)
                ))
            case (.credentialRoot, "credentialSubject", .some(.object(let nested))):
                let nestedSubject = RDFTerm.blank("credentialSubject")
                quads.append(RDFQuad(
                    subject: subject,
                    predicate: try PinnedJSONLDTermRegistry.vcbPredicate(key),
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
                    predicate: try PinnedJSONLDTermRegistry.vcbPredicate(key),
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
                    predicate: try PinnedJSONLDTermRegistry.vcbPredicate(key),
                    value: dateTime
                ))
            case (.credentialRoot, "validUntil", .some(.string(let dateTime))):
                quads.append(try dateTimeQuad(
                    subject: subject,
                    predicate: try PinnedJSONLDTermRegistry.vcbPredicate(key),
                    value: dateTime
                ))
            case (.credentialSubject, "protectedComponentIndex", .some(.string(let multibase))):
                quads.append(RDFQuad(
                    subject: subject,
                    predicate: try PinnedJSONLDTermRegistry.vcbPredicate(key),
                    object: .literal(value: multibase, datatype: PinnedJSONLDTermRegistry.securityMultibaseDatatype)
                ))
            case (.credentialStatus, "terseStatusListBaseUrl", .some(.string(let url))):
                quads.append(RDFQuad(
                    subject: subject,
                    predicate: try PinnedJSONLDTermRegistry.vcbPredicate(key),
                    object: .iri(url)
                ))
            case (.credentialStatus, "terseStatusListIndex", .some(.unsigned(let index))):
                quads.append(RDFQuad(
                    subject: subject,
                    predicate: try PinnedJSONLDTermRegistry.vcbPredicate(key),
                    object: .literal(value: String(index), datatype: PinnedJSONLDTermRegistry.xsdInteger)
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
                predicate: PinnedJSONLDTermRegistry.rdfType,
                object: .iri(try PinnedJSONLDTermRegistry.vcbTypeIRI($0))
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
            object: .literal(value: value, datatype: PinnedJSONLDTermRegistry.xsdDateTime)
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

}

private enum NodeKind {
    case credentialRoot
    case credentialSubject
    case credentialStatus
}
