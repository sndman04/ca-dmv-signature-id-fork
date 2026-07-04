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

    static func requireGenericAbsoluteIRIProperties(
        _ properties: [String: SupportedJSONLDValue],
        error: CADMVInternalError
    ) throws {
        var blankNodeCounter = 0
        for key in properties.keys.sorted() {
            guard let value = properties[key],
                  try genericAbsoluteIRIQuads(
                    key: key,
                    value: value,
                    subject: .blank("validation"),
                    error: error,
                    blankNodeCounter: &blankNodeCounter
                  ) != nil else {
                throw error
            }
        }
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
        case .number(let number):
            let literal = try jsonNumberLiteral(number, error: error)
            return [
                literalQuad(
                    subject: subject,
                    predicate: predicate,
                    value: literal.value,
                    datatype: literal.datatype
                )
            ]
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

    private static func jsonNumberLiteral(
        _ value: String,
        error: CADMVInternalError
    ) throws -> (value: String, datatype: String) {
        let parsed = try parseJSONNumber(value, error: error)
        if parsed.fractionalDigits == 0 {
            let sign = parsed.isNegative ? "-" : ""
            return ("\(sign)\(parsed.digits)", PinnedJSONLDTermRegistry.xsdInteger)
        }
        let exponent = parsed.digits.count - 1 - parsed.fractionalDigits
        var mantissaDigits = parsed.digits
        while mantissaDigits.count > 1 && mantissaDigits.last == "0" {
            mantissaDigits.removeLast()
        }
        let mantissa: String
        if mantissaDigits.count == 1 {
            mantissa = "\(mantissaDigits).0"
        } else {
            let index = mantissaDigits.index(after: mantissaDigits.startIndex)
            mantissa = "\(mantissaDigits[..<index]).\(mantissaDigits[index...])"
        }
        let sign = parsed.isNegative ? "-" : ""
        return (
            "\(sign)\(mantissa)E\(exponent)",
            PinnedJSONLDTermRegistry.xsdDouble
        )
    }

    private static func parseJSONNumber(
        _ value: String,
        error: CADMVInternalError
    ) throws -> (isNegative: Bool, digits: String, fractionalDigits: Int) {
        guard !value.isEmpty else {
            throw error
        }

        let parts = value.split(
            omittingEmptySubsequences: false,
            whereSeparator: { $0 == "e" || $0 == "E" }
        )
        guard parts.count <= 2 else {
            throw error
        }

        let exponent = try parts.count == 2 ? parseSignedInteger(String(parts[1]), error: error) : 0
        var coefficient = String(parts[0])
        let isNegative = coefficient.first == "-"
        if isNegative || coefficient.first == "+" {
            coefficient.removeFirst()
        }
        guard !coefficient.isEmpty else {
            throw error
        }

        let coefficientParts = coefficient.split(separator: ".", omittingEmptySubsequences: false)
        guard coefficientParts.count <= 2 else {
            throw error
        }
        let integerPart = String(coefficientParts[0])
        let fractionPart = coefficientParts.count == 2 ? String(coefficientParts[1]) : ""
        guard !integerPart.isEmpty || !fractionPart.isEmpty,
              integerPart.allSatisfy({ $0.isNumber }),
              fractionPart.allSatisfy({ $0.isNumber }) else {
            throw error
        }

        var digits = integerPart + fractionPart
        while digits.first == "0" && digits.count > 1 {
            digits.removeFirst()
        }
        if digits.allSatisfy({ $0 == "0" }) {
            return (false, "0", 0)
        }

        var fractionalDigits = fractionPart.count - exponent
        while fractionalDigits > 0 && digits.last == "0" {
            digits.removeLast()
            fractionalDigits -= 1
        }
        if fractionalDigits < 0 {
            digits += String(repeating: "0", count: 0 - fractionalDigits)
            fractionalDigits = 0
        }
        return (isNegative, digits, fractionalDigits)
    }

    private static func parseSignedInteger(
        _ value: String,
        error: CADMVInternalError
    ) throws -> Int {
        guard !value.isEmpty, let parsed = Int(value) else {
            throw error
        }
        return parsed
    }
}
