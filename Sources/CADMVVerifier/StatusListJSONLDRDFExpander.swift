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
        return document
    }
}

enum SupportedStatusListJSONLDRDFConverter {
    private static let rdfType = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
    private static let xsdDateTime = "http://www.w3.org/2001/XMLSchema#dateTime"
    private static let securityMultibase = "https://w3id.org/security#multibase"
    private static let schema = "https://schema.org/"
    private static let vc = "https://www.w3.org/2018/credentials#"
    private static let status = "https://www.w3.org/ns/credentials/status#"

    static func quads(
        from document: [String: SupportedJSONLDValue]
    ) throws -> [RDFQuad] {
        try requireSupportedContexts(document["@context"])
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
                quads.append(contentsOf: try typeQuads(value, subject: subject))
            case (.credentialRoot, "issuer", .some(.string(let issuer))):
                quads.append(RDFQuad(
                    subject: subject,
                    predicate: vc + "issuer",
                    object: .iri(issuer)
                ))
            case (.credentialRoot, "credentialSubject", .some(.object(let nested))):
                guard case .string(let subjectID) = nested["id"] else {
                    throw CADMVInternalError.statusListDecodeFailed
                }
                let nestedSubject = RDFTerm.iri(subjectID)
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
            case (.credentialRoot, "description", .some(.string(let description))):
                quads.append(RDFQuad(
                    subject: subject,
                    predicate: schema + "description",
                    object: .literal(value: description, datatype: nil)
                ))
            case (.credentialRoot, "name", .some(.string(let name))):
                quads.append(RDFQuad(
                    subject: subject,
                    predicate: schema + "name",
                    object: .literal(value: name, datatype: nil)
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
            case (.credentialSubject, "encodedList", .some(.string(let encodedList))):
                quads.append(RDFQuad(
                    subject: subject,
                    predicate: status + "encodedList",
                    object: .literal(value: encodedList, datatype: securityMultibase)
                ))
            case (.credentialSubject, "statusPurpose", .some(.string(let statusPurpose))):
                quads.append(RDFQuad(
                    subject: subject,
                    predicate: status + "statusPurpose",
                    object: .literal(value: statusPurpose, datatype: nil)
                ))
            default:
                throw CADMVInternalError.statusListDecodeFailed
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
                    throw CADMVInternalError.statusListDecodeFailed
                }
                return text
            }
        default:
            throw CADMVInternalError.statusListDecodeFailed
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
            throw CADMVInternalError.statusListDecodeFailed
        }
        return RDFQuad(
            subject: subject,
            predicate: predicate,
            object: .literal(value: value, datatype: xsdDateTime)
        )
    }

    private static func requireSupportedContexts(_ value: SupportedJSONLDValue?) throws {
        guard case .array(let contexts) = value else {
            throw CADMVInternalError.statusListDecodeFailed
        }
        let strings = try contexts.map { value in
            guard case .string(let context) = value else {
                throw CADMVInternalError.statusListDecodeFailed
            }
            return context
        }
        guard strings == ["https://www.w3.org/ns/credentials/v2"] else {
            throw CADMVInternalError.statusListDecodeFailed
        }
    }

    private static func typeIRI(_ value: String) throws -> String {
        switch value {
        case "VerifiableCredential":
            return vc + value
        case "BitstringStatusListCredential",
             "BitstringStatusList":
            return status + value
        default:
            throw CADMVInternalError.statusListDecodeFailed
        }
    }
}

private enum StatusListNodeKind {
    case credentialRoot
    case credentialSubject
}
