indirect enum SupportedJSONLDValue: Equatable, Sendable {
    case string(String)
    case unsigned(UInt64)
    case number(String)
    case bool(Bool)
    case null
    case array([SupportedJSONLDValue])
    case object([String: SupportedJSONLDValue])
}

enum SupportedJSONLDRDFConverter {
    static func quads(
        from document: [String: SupportedJSONLDValue]
    ) throws -> [RDFQuad] {
        try PinnedJSONLDTermRegistry.requireVCBDocumentContexts(document["@context"])
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
                quads.append(contentsOf: try SupportedJSONLDRDFTerms.typeQuads(
                    value,
                    subject: subject,
                    error: .unsupportedVCB,
                    typeIRI: PinnedJSONLDTermRegistry.vcbTypeIRI
                ))
            case (.credentialRoot, "issuer", .some(.string(let issuer))):
                quads.append(SupportedJSONLDRDFTerms.iriQuad(
                    subject: subject,
                    predicate: try PinnedJSONLDTermRegistry.vcbPredicate(key),
                    iri: issuer
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
                quads.append(try SupportedJSONLDRDFTerms.dateTimeQuad(
                    subject: subject,
                    predicate: try PinnedJSONLDTermRegistry.vcbPredicate(key),
                    value: dateTime,
                    error: .unsupportedVCB
                ))
            case (.credentialRoot, "validUntil", .some(.string(let dateTime))):
                quads.append(try SupportedJSONLDRDFTerms.dateTimeQuad(
                    subject: subject,
                    predicate: try PinnedJSONLDTermRegistry.vcbPredicate(key),
                    value: dateTime,
                    error: .unsupportedVCB
                ))
            case (.credentialSubject, "protectedComponentIndex", .some(.string(let multibase))):
                quads.append(SupportedJSONLDRDFTerms.literalQuad(
                    subject: subject,
                    predicate: try PinnedJSONLDTermRegistry.vcbPredicate(key),
                    value: multibase,
                    datatype: PinnedJSONLDTermRegistry.securityMultibaseDatatype
                ))
            case (.credentialStatus, "terseStatusListBaseUrl", .some(.string(let url))):
                quads.append(SupportedJSONLDRDFTerms.iriQuad(
                    subject: subject,
                    predicate: try PinnedJSONLDTermRegistry.vcbPredicate(key),
                    iri: url
                ))
            case (.credentialStatus, "terseStatusListIndex", .some(.unsigned(let index))):
                quads.append(SupportedJSONLDRDFTerms.literalQuad(
                    subject: subject,
                    predicate: try PinnedJSONLDTermRegistry.vcbPredicate(key),
                    value: String(index),
                    datatype: PinnedJSONLDTermRegistry.xsdInteger
                ))
            default:
                throw CADMVInternalError.unsupportedVCB
            }
        }
        return quads
    }

}

private enum NodeKind {
    case credentialRoot
    case credentialSubject
    case credentialStatus
}
