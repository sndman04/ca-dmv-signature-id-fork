enum StatusListJSONLDRDFExpander {
    static func canonicalNQuads(
        _ credential: DMVStatusListCredential,
        engine: any JSONLDCanonicalizationEngine = SupportedProfileJSONLDCanonicalizationEngine.shared
    ) throws -> String {
        try engine.canonicalNQuads(
            document: jsonLDDocument(from: credential),
            profile: .statusListDocument
        )
    }

    static func documentQuads(
        _ credential: DMVStatusListCredential,
        engine: any JSONLDCanonicalizationEngine = SupportedProfileJSONLDCanonicalizationEngine.shared
    ) throws -> [RDFQuad] {
        try engine.quads(
            from: jsonLDDocument(from: credential),
            profile: .statusListDocument
        )
    }

    static func jsonLDDocument(
        from credential: DMVStatusListCredential
    ) -> [String: SupportedJSONLDValue] {
        var document: [String: SupportedJSONLDValue] = [
            "@context": .array([
                .string("https://www.w3.org/ns/credentials/v2")
            ]),
            "id": .string(credential.id),
            "type": .array(credential.type.map { .string($0) }),
            "issuer": .string(credential.issuer),
            "credentialSubject": .object([
                "id": .string(credential.credentialSubject.id),
                "type": .string(credential.credentialSubject.type),
                "encodedList": .string(credential.credentialSubject.encodedList),
                "statusPurpose": .string(credential.credentialSubject.statusPurpose)
            ])
        ]
        for (key, value) in credential.credentialSubject.additionalProperties {
            if case .object(var subject) = document["credentialSubject"] {
                subject[key] = value
                document["credentialSubject"] = .object(subject)
            }
        }

        if let description = credential.description {
            document["description"] = .string(description)
        }
        if let name = credential.name {
            document["name"] = .string(name)
        }
        if let validFrom = credential.validFrom {
            document["validFrom"] = .string(validFrom)
        }
        if let validUntil = credential.validUntil {
            document["validUntil"] = .string(validUntil)
        }
        for (key, value) in credential.additionalProperties {
            document[key] = value
        }
        return document
    }
}

enum SupportedStatusListJSONLDRDFConverter {
    static func quads(
        from document: [String: SupportedJSONLDValue]
    ) throws -> [RDFQuad] {
        try PinnedJSONLDTermRegistry.requireStatusListDocumentContexts(document["@context"])
        guard case .string(let id) = document["id"] else {
            throw CADMVInternalError.statusListDecodeFailed
        }
        return try nodeQuads(
            document,
            subject: .iri(id),
            nodeKind: .credentialRoot
        )
    }

    private static func nodeQuads(
        _ object: [String: SupportedJSONLDValue],
        subject: RDFTerm,
        nodeKind: StatusListNodeKind
    ) throws -> [RDFQuad] {
        var quads: [RDFQuad] = []
        for key in object.keys.sorted() {
            guard key != "@context", key != "id" else {
                continue
            }
            let value = object[key]
            switch (nodeKind, key, value) {
            case (_, "type", .some(let value)):
                quads.append(contentsOf: try SupportedJSONLDRDFTerms.typeQuads(
                    value,
                    subject: subject,
                    error: .statusListDecodeFailed,
                    typeIRI: PinnedJSONLDTermRegistry.statusListTypeIRI
                ))
            case (.credentialRoot, "issuer", .some(.string(let issuer))):
                quads.append(SupportedJSONLDRDFTerms.iriQuad(
                    subject: subject,
                    predicate: try PinnedJSONLDTermRegistry.statusListPredicate(key),
                    iri: issuer
                ))
            case (.credentialRoot, "credentialSubject", .some(.object(let nested))):
                guard case .string(let subjectID) = nested["id"] else {
                    throw CADMVInternalError.statusListDecodeFailed
                }
                let nestedSubject = RDFTerm.iri(subjectID)
                quads.append(RDFQuad(
                    subject: subject,
                    predicate: try PinnedJSONLDTermRegistry.statusListPredicate(key),
                    object: nestedSubject
                ))
                quads.append(contentsOf: try nodeQuads(
                    nested,
                    subject: nestedSubject,
                    nodeKind: .credentialSubject
                ))
            case (.credentialRoot, "description", .some(.string(let description))):
                quads.append(SupportedJSONLDRDFTerms.literalQuad(
                    subject: subject,
                    predicate: try PinnedJSONLDTermRegistry.statusListPredicate(key),
                    value: description
                ))
            case (.credentialRoot, "name", .some(.string(let name))):
                quads.append(SupportedJSONLDRDFTerms.literalQuad(
                    subject: subject,
                    predicate: try PinnedJSONLDTermRegistry.statusListPredicate(key),
                    value: name
                ))
            case (.credentialRoot, "validFrom", .some(.string(let dateTime))):
                quads.append(try SupportedJSONLDRDFTerms.dateTimeQuad(
                    subject: subject,
                    predicate: try PinnedJSONLDTermRegistry.statusListPredicate(key),
                    value: dateTime,
                    error: .statusListDecodeFailed
                ))
            case (.credentialRoot, "validUntil", .some(.string(let dateTime))):
                quads.append(try SupportedJSONLDRDFTerms.dateTimeQuad(
                    subject: subject,
                    predicate: try PinnedJSONLDTermRegistry.statusListPredicate(key),
                    value: dateTime,
                    error: .statusListDecodeFailed
                ))
            case (.credentialSubject, "encodedList", .some(.string(let encodedList))):
                quads.append(SupportedJSONLDRDFTerms.literalQuad(
                    subject: subject,
                    predicate: try PinnedJSONLDTermRegistry.statusListPredicate(key),
                    value: encodedList,
                    datatype: PinnedJSONLDTermRegistry.securityMultibaseDatatype
                ))
            case (.credentialSubject, "statusPurpose", .some(.string(let statusPurpose))):
                quads.append(SupportedJSONLDRDFTerms.literalQuad(
                    subject: subject,
                    predicate: try PinnedJSONLDTermRegistry.statusListPredicate(key),
                    value: statusPurpose
                ))
            default:
                throw CADMVInternalError.statusListDecodeFailed
            }
        }
        return quads
    }

}

private enum StatusListNodeKind {
    case credentialRoot
    case credentialSubject
}
