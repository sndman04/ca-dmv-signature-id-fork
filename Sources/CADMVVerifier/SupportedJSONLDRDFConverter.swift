import Foundation

indirect enum SupportedJSONLDValue: Equatable, Sendable {
    case string(String)
    case unsigned(UInt64)
    case number(String)
    case bool(Bool)
    case null
    case array([SupportedJSONLDValue])
    case object([String: SupportedJSONLDValue])

    static func fromJSON(
        _ value: Any,
        error: CADMVInternalError
    ) throws -> SupportedJSONLDValue {
        switch value {
        case let text as String:
            return .string(text)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }
            guard number.doubleValue.isFinite else {
                throw error
            }
            if number.doubleValue.rounded() == number.doubleValue,
               number.doubleValue >= 0,
               let unsigned = UInt64(exactly: number) {
                return .unsigned(unsigned)
            }
            return .number(number.stringValue)
        case let bool as Bool:
            return .bool(bool)
        case let array as [Any]:
            return .array(try array.map { try fromJSON($0, error: error) })
        case let object as [String: Any]:
            return .object(try object.mapValues { try fromJSON($0, error: error) })
        case _ as NSNull:
            return .null
        default:
            throw error
        }
    }
}

enum SupportedJSONLDRDFConverter {
    static func quads(
        from document: [String: SupportedJSONLDValue]
    ) throws -> [RDFQuad] {
        try PinnedJSONLDTermRegistry.requireVCBDocumentContexts(document["@context"])
        let subject = try nodeSubject(
            from: document["id"],
            fallback: .blank("root")
        )
        return try nodeQuads(
            document,
            subject: subject,
            nodeKind: .credentialRoot
        )
    }

    private static func nodeQuads(
        _ object: [String: SupportedJSONLDValue],
        subject: RDFTerm,
        nodeKind: NodeKind
    ) throws -> [RDFQuad] {
        var quads: [RDFQuad] = []
        var genericBlankNodeCounter = 0
        try appendNodeQuads(
            object,
            subject: subject,
            nodeKind: nodeKind,
            genericBlankNodeCounter: &genericBlankNodeCounter,
            quads: &quads
        )
        return quads
    }

    private static func appendNodeQuads(
        _ object: [String: SupportedJSONLDValue],
        subject: RDFTerm,
        nodeKind: NodeKind,
        genericBlankNodeCounter: inout Int,
        quads: inout [RDFQuad]
    ) throws {
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
                let nestedSubject = try nodeSubject(
                    from: nested["id"],
                    fallback: .blank("credentialSubject")
                )
                quads.append(RDFQuad(
                    subject: subject,
                    predicate: try PinnedJSONLDTermRegistry.vcbPredicate(key),
                    object: nestedSubject
                ))
                try appendNodeQuads(
                    nested,
                    subject: nestedSubject,
                    nodeKind: .credentialSubject,
                    genericBlankNodeCounter: &genericBlankNodeCounter,
                    quads: &quads
                )
            case (.credentialRoot, "credentialStatus", .some(.object(let nested))):
                let nestedSubject = try nodeSubject(
                    from: nested["id"],
                    fallback: .blank("credentialStatus")
                )
                quads.append(RDFQuad(
                    subject: subject,
                    predicate: try PinnedJSONLDTermRegistry.vcbPredicate(key),
                    object: nestedSubject
                ))
                try appendNodeQuads(
                    nested,
                    subject: nestedSubject,
                    nodeKind: .credentialStatus,
                    genericBlankNodeCounter: &genericBlankNodeCounter,
                    quads: &quads
                )
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
                if let value,
                   let genericQuads = try SupportedJSONLDRDFTerms.genericAbsoluteIRIQuads(
                    key: key,
                    value: value,
                    subject: subject,
                    error: .unsupportedVCB,
                    blankNodeCounter: &genericBlankNodeCounter
                ) {
                    quads.append(contentsOf: genericQuads)
                    continue
                }
                throw CADMVInternalError.unsupportedVCB
            }
        }
    }

    private static func nodeSubject(
        from value: SupportedJSONLDValue?,
        fallback: RDFTerm
    ) throws -> RDFTerm {
        guard let value else {
            return fallback
        }
        guard case .string(let id) = value else {
            throw CADMVInternalError.unsupportedVCB
        }
        return try SupportedJSONLDRDFTerms.nodeIdentifierTerm(
            id,
            error: .unsupportedVCB
        )
    }

}

private enum NodeKind {
    case credentialRoot
    case credentialSubject
    case credentialStatus
}
