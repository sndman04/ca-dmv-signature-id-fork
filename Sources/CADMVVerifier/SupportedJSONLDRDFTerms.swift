enum SupportedJSONLDRDFTerms {
    private static let genericBlankNodePrefix = "jsonldGeneric"

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

    static func genericAbsoluteIRIQuads(
        key: String,
        value: SupportedJSONLDValue,
        subject: RDFTerm,
        error: CADMVInternalError,
        blankNodeCounter: inout Int
    ) throws -> [RDFQuad]? {
        guard try isSafeAbsoluteIRI(key, error: error) else {
            return nil
        }
        return try genericValueQuads(
            predicate: key,
            value: value,
            subject: subject,
            error: error,
            blankNodeCounter: &blankNodeCounter
        )
    }

    private static func genericValueQuads(
        predicate: String,
        value: SupportedJSONLDValue,
        subject: RDFTerm,
        error: CADMVInternalError,
        blankNodeCounter: inout Int
    ) throws -> [RDFQuad] {
        switch value {
        case .string(let text):
            return [
                literalQuad(subject: subject, predicate: predicate, value: text)
            ]
        case .unsigned(let number):
            return [
                literalQuad(
                    subject: subject,
                    predicate: predicate,
                    value: String(number),
                    datatype: PinnedJSONLDTermRegistry.xsdInteger
                )
            ]
        case .number:
            throw error
        case .bool(let value):
            return [
                literalQuad(
                    subject: subject,
                    predicate: predicate,
                    value: value ? "true" : "false",
                    datatype: PinnedJSONLDTermRegistry.xsdBoolean
                )
            ]
        case .null:
            return []
        case .array(let values):
            var quads: [RDFQuad] = []
            for value in values {
                quads.append(contentsOf: try genericValueQuads(
                    predicate: predicate,
                    value: value,
                    subject: subject,
                    error: error,
                    blankNodeCounter: &blankNodeCounter
                ))
            }
            return quads
        case .object(let object):
            let nestedSubject = RDFTerm.blank("\(genericBlankNodePrefix)\(blankNodeCounter)")
            blankNodeCounter += 1
            var quads = [RDFQuad(
                subject: subject,
                predicate: predicate,
                object: nestedSubject
            )]
            for key in object.keys.sorted() {
                guard let value = object[key] else {
                    continue
                }
                guard let nestedQuads = try genericAbsoluteIRIQuads(
                    key: key,
                    value: value,
                    subject: nestedSubject,
                    error: error,
                    blankNodeCounter: &blankNodeCounter
                ) else {
                    throw error
                }
                quads.append(contentsOf: nestedQuads)
            }
            return quads
        }
    }

    private static func isSafeAbsoluteIRI(
        _ value: String,
        error: CADMVInternalError
    ) throws -> Bool {
        guard value.hasPrefix("http://") || value.hasPrefix("https://") else {
            return false
        }
        for scalar in value.unicodeScalars {
            if scalar.value <= 0x20 || scalar.value == 0x7f ||
                "<>\"{}|^`\\".unicodeScalars.contains(scalar) {
                throw error
            }
        }
        return true
    }
}
