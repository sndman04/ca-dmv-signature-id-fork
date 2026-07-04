enum SupportedJSONLDRDFTerms {
    static func iriQuad(
        subject: RDFTerm,
        predicate: String,
        iri: String
    ) -> RDFQuad {
        RDFQuad(
            subject: subject,
            predicate: predicate,
            object: .iri(iri)
        )
    }

    static func literalQuad(
        subject: RDFTerm,
        predicate: String,
        value: String,
        datatype: String? = nil
    ) -> RDFQuad {
        RDFQuad(
            subject: subject,
            predicate: predicate,
            object: .literal(value: value, datatype: datatype)
        )
    }

    static func dateTimeQuad(
        subject: RDFTerm,
        predicate: String,
        value: String,
        error: CADMVInternalError
    ) throws -> RDFQuad {
        guard DMVVCBDecoder.isSafeDateTimeTextForRDF(value) else {
            throw error
        }
        return literalQuad(
            subject: subject,
            predicate: predicate,
            value: value,
            datatype: PinnedJSONLDTermRegistry.xsdDateTime
        )
    }

    static func typeQuads(
        _ value: SupportedJSONLDValue,
        subject: RDFTerm,
        error: CADMVInternalError,
        typeIRI: (String) throws -> String
    ) throws -> [RDFQuad] {
        try stringValues(value, error: error).map {
            iriQuad(
                subject: subject,
                predicate: PinnedJSONLDTermRegistry.rdfType,
                iri: try typeIRI($0)
            )
        }
    }

    private static func stringValues(
        _ value: SupportedJSONLDValue,
        error: CADMVInternalError
    ) throws -> [String] {
        switch value {
        case .string(let text):
            return [text]
        case .array(let array):
            return try array.map { item in
                guard case .string(let text) = item else {
                    throw error
                }
                return text
            }
        default:
            throw error
        }
    }
}
