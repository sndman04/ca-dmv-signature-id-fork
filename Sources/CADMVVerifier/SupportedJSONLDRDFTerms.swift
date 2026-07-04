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

    static func languageLiteralQuad(
        subject: RDFTerm,
        predicate: String,
        value: String,
        language: String
    ) -> RDFQuad {
        RDFQuad(
            subject: subject,
            predicate: predicate,
            object: .languageLiteral(value: value, language: language)
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
            if let list = object["@list"] {
                return try genericListObjectQuads(
                    predicate: predicate,
                    object: object,
                    list: list,
                    subject: subject,
                    error: error,
                    blankNodeCounter: &blankNodeCounter
                )
            }
            if let set = object["@set"] {
                return try genericSetObjectQuads(
                    predicate: predicate,
                    object: object,
                    set: set,
                    subject: subject,
                    error: error,
                    blankNodeCounter: &blankNodeCounter
                )
            }
            if let id = object["@id"] {
                return try genericNodeObjectQuads(
                    predicate: predicate,
                    object: object,
                    id: id,
                    subject: subject,
                    error: error,
                    blankNodeCounter: &blankNodeCounter
                )
            }
            if let value = object["@value"] {
                return try genericValueObjectQuads(
                    predicate: predicate,
                    object: object,
                    value: value,
                    subject: subject,
                    error: error
                )
            }
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
                if key == "@index" {
                    try validateGenericIndex(value, error: error)
                    continue
                }
                if key == "@type" {
                    quads.append(contentsOf: try genericTypeQuads(
                        value,
                        subject: nestedSubject,
                        error: error
                    ))
                    continue
                }
                if key == "@reverse" {
                    quads.append(contentsOf: try genericReverseQuads(
                        value,
                        object: nestedSubject,
                        error: error,
                        blankNodeCounter: &blankNodeCounter
                    ))
                    continue
                }
                if key == "@graph" {
                    quads.append(contentsOf: try genericGraphQuads(
                        value,
                        graph: nestedSubject,
                        error: error,
                        blankNodeCounter: &blankNodeCounter
                    ))
                    continue
                }
                if key == "@included" {
                    quads.append(contentsOf: try genericIncludedQuads(
                        value,
                        error: error,
                        blankNodeCounter: &blankNodeCounter
                    ))
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

    private static func genericListObjectQuads(
        predicate: String,
        object: [String: SupportedJSONLDValue],
        list: SupportedJSONLDValue,
        subject: RDFTerm,
        error: CADMVInternalError,
        blankNodeCounter: inout Int
    ) throws -> [RDFQuad] {
        guard try object.keys.allSatisfy({ key in
            if key == "@list" {
                return true
            }
            if key == "@index" {
                try validateGenericIndex(object[key], error: error)
                return true
            }
            return false
        }) else {
            throw error
        }
        let values: [SupportedJSONLDValue]
        switch list {
        case .array(let array):
            values = array
        default:
            values = [list]
        }
        let listTerm = try genericListTerm(
            values,
            error: error,
            blankNodeCounter: &blankNodeCounter
        )
        return [
            RDFQuad(
                subject: subject,
                predicate: predicate,
                object: listTerm.term
            )
        ] + listTerm.quads
    }

    private static func genericListTerm(
        _ values: [SupportedJSONLDValue],
        error: CADMVInternalError,
        blankNodeCounter: inout Int
    ) throws -> (term: RDFTerm, quads: [RDFQuad]) {
        var itemTerms: [(term: RDFTerm, quads: [RDFQuad])] = []
        for value in values {
            if let item = try genericObjectTerm(
                value,
                error: error,
                blankNodeCounter: &blankNodeCounter
            ) {
                itemTerms.append(item)
            }
        }
        guard !itemTerms.isEmpty else {
            return (.iri(PinnedJSONLDTermRegistry.rdfNil), [])
        }

        let listNodes = itemTerms.map { _ -> RDFTerm in
            let node = RDFTerm.blank("\(genericBlankNodePrefix)\(blankNodeCounter)")
            blankNodeCounter += 1
            return node
        }
        var quads: [RDFQuad] = []
        for index in itemTerms.indices {
            quads.append(contentsOf: itemTerms[index].quads)
            quads.append(RDFQuad(
                subject: listNodes[index],
                predicate: PinnedJSONLDTermRegistry.rdfFirst,
                object: itemTerms[index].term
            ))
            quads.append(RDFQuad(
                subject: listNodes[index],
                predicate: PinnedJSONLDTermRegistry.rdfRest,
                object: index == itemTerms.index(before: itemTerms.endIndex)
                    ? .iri(PinnedJSONLDTermRegistry.rdfNil)
                    : listNodes[itemTerms.index(after: index)]
            ))
        }
        return (listNodes[0], quads)
    }

    private static func genericSetObjectQuads(
        predicate: String,
        object: [String: SupportedJSONLDValue],
        set: SupportedJSONLDValue,
        subject: RDFTerm,
        error: CADMVInternalError,
        blankNodeCounter: inout Int
    ) throws -> [RDFQuad] {
        guard try object.keys.allSatisfy({ key in
            if key == "@set" {
                return true
            }
            if key == "@index" {
                try validateGenericIndex(object[key], error: error)
                return true
            }
            return false
        }) else {
            throw error
        }
        switch set {
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
        default:
            return try genericValueQuads(
                predicate: predicate,
                value: set,
                subject: subject,
                error: error,
                blankNodeCounter: &blankNodeCounter
            )
        }
    }

    private static func genericNodeObjectQuads(
        predicate: String,
        object: [String: SupportedJSONLDValue],
        id: SupportedJSONLDValue,
        subject: RDFTerm,
        error: CADMVInternalError,
        blankNodeCounter: inout Int
    ) throws -> [RDFQuad] {
        guard object["@value"] == nil,
              case .string(let idValue) = id,
              try isSafeIRI(idValue, error: error) else {
            throw error
        }

        let nestedSubject = RDFTerm.iri(idValue)
        var quads = [RDFQuad(
            subject: subject,
            predicate: predicate,
            object: nestedSubject
        )]
        for key in object.keys.sorted() where key != "@id" {
            if key == "@index" {
                try validateGenericIndex(object[key], error: error)
                continue
            }
            if key == "@type" {
                guard let value = object[key] else {
                    continue
                }
                quads.append(contentsOf: try genericTypeQuads(
                    value,
                    subject: nestedSubject,
                    error: error
                ))
                continue
            }
            if key == "@reverse" {
                guard let value = object[key] else {
                    continue
                }
                quads.append(contentsOf: try genericReverseQuads(
                    value,
                    object: nestedSubject,
                    error: error,
                    blankNodeCounter: &blankNodeCounter
                ))
                continue
            }
            if key == "@graph" {
                guard let value = object[key] else {
                    continue
                }
                quads.append(contentsOf: try genericGraphQuads(
                    value,
                    graph: nestedSubject,
                    error: error,
                    blankNodeCounter: &blankNodeCounter
                ))
                continue
            }
            if key == "@included" {
                guard let value = object[key] else {
                    continue
                }
                quads.append(contentsOf: try genericIncludedQuads(
                    value,
                    error: error,
                    blankNodeCounter: &blankNodeCounter
                ))
                continue
            }
            guard let value = object[key],
                  let nestedQuads = try genericAbsoluteIRIQuads(
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

    private static func genericObjectTerm(
        _ value: SupportedJSONLDValue,
        error: CADMVInternalError,
        blankNodeCounter: inout Int
    ) throws -> (term: RDFTerm, quads: [RDFQuad])? {
        switch value {
        case .string(let text):
            return (.literal(value: text, datatype: nil), [])
        case .unsigned(let number):
            return (
                .literal(value: String(number), datatype: PinnedJSONLDTermRegistry.xsdInteger),
                []
            )
        case .number(let number):
            let literal = try jsonNumberLiteral(number, error: error)
            return (.literal(value: literal.value, datatype: literal.datatype), [])
        case .bool(let value):
            return (
                .literal(
                    value: value ? "true" : "false",
                    datatype: PinnedJSONLDTermRegistry.xsdBoolean
                ),
                []
            )
        case .null:
            return nil
        case .array:
            throw error
        case .object(let object):
            if let list = object["@list"] {
                guard try object.keys.allSatisfy({ key in
                    if key == "@list" {
                        return true
                    }
                    if key == "@index" {
                        try validateGenericIndex(object[key], error: error)
                        return true
                    }
                    return false
                }) else {
                    throw error
                }
                let values: [SupportedJSONLDValue]
                switch list {
                case .array(let array):
                    values = array
                default:
                    values = [list]
                }
                return try genericListTerm(
                    values,
                    error: error,
                    blankNodeCounter: &blankNodeCounter
                )
            }
            if let id = object["@id"] {
                return try genericNodeObjectTerm(
                    object,
                    id: id,
                    error: error,
                    blankNodeCounter: &blankNodeCounter
                )
            }
            if let value = object["@value"] {
                guard let term = try genericValueObjectTerm(
                    object,
                    value: value,
                    error: error
                ) else {
                    return nil
                }
                return (term, [])
            }
            let nestedSubject = RDFTerm.blank("\(genericBlankNodePrefix)\(blankNodeCounter)")
            blankNodeCounter += 1
            var quads: [RDFQuad] = []
            for key in object.keys.sorted() {
                if key == "@index" {
                    try validateGenericIndex(object[key], error: error)
                    continue
                }
                if key == "@type" {
                    guard let value = object[key] else {
                        continue
                    }
                    quads.append(contentsOf: try genericTypeQuads(
                        value,
                        subject: nestedSubject,
                        error: error
                    ))
                    continue
                }
                if key == "@reverse" {
                    guard let value = object[key] else {
                        continue
                    }
                    quads.append(contentsOf: try genericReverseQuads(
                        value,
                        object: nestedSubject,
                        error: error,
                        blankNodeCounter: &blankNodeCounter
                    ))
                    continue
                }
                if key == "@graph" {
                    guard let value = object[key] else {
                        continue
                    }
                    quads.append(contentsOf: try genericGraphQuads(
                        value,
                        graph: nestedSubject,
                        error: error,
                        blankNodeCounter: &blankNodeCounter
                    ))
                    continue
                }
                if key == "@included" {
                    guard let value = object[key] else {
                        continue
                    }
                    quads.append(contentsOf: try genericIncludedQuads(
                        value,
                        error: error,
                        blankNodeCounter: &blankNodeCounter
                    ))
                    continue
                }
                guard let value = object[key],
                      let nestedQuads = try genericAbsoluteIRIQuads(
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
            return (nestedSubject, quads)
        }
    }

    private static func genericNodeObjectTerm(
        _ object: [String: SupportedJSONLDValue],
        id: SupportedJSONLDValue,
        error: CADMVInternalError,
        blankNodeCounter: inout Int
    ) throws -> (term: RDFTerm, quads: [RDFQuad]) {
        guard object["@value"] == nil,
              case .string(let idValue) = id,
              try isSafeIRI(idValue, error: error) else {
            throw error
        }

        let nestedSubject = RDFTerm.iri(idValue)
        var quads: [RDFQuad] = []
        for key in object.keys.sorted() where key != "@id" {
            if key == "@index" {
                try validateGenericIndex(object[key], error: error)
                continue
            }
            if key == "@type" {
                guard let value = object[key] else {
                    continue
                }
                quads.append(contentsOf: try genericTypeQuads(
                    value,
                    subject: nestedSubject,
                    error: error
                ))
                continue
            }
            if key == "@reverse" {
                guard let value = object[key] else {
                    continue
                }
                quads.append(contentsOf: try genericReverseQuads(
                    value,
                    object: nestedSubject,
                    error: error,
                    blankNodeCounter: &blankNodeCounter
                ))
                continue
            }
            if key == "@graph" {
                guard let value = object[key] else {
                    continue
                }
                quads.append(contentsOf: try genericGraphQuads(
                    value,
                    graph: nestedSubject,
                    error: error,
                    blankNodeCounter: &blankNodeCounter
                ))
                continue
            }
            if key == "@included" {
                guard let value = object[key] else {
                    continue
                }
                quads.append(contentsOf: try genericIncludedQuads(
                    value,
                    error: error,
                    blankNodeCounter: &blankNodeCounter
                ))
                continue
            }
            guard let value = object[key],
                  let nestedQuads = try genericAbsoluteIRIQuads(
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
        return (nestedSubject, quads)
    }

    private static func genericValueObjectQuads(
        predicate: String,
        object: [String: SupportedJSONLDValue],
        value: SupportedJSONLDValue,
        subject: RDFTerm,
        error: CADMVInternalError
    ) throws -> [RDFQuad] {
        guard let term = try genericValueObjectTerm(object, value: value, error: error) else {
            return []
        }
        return [
            RDFQuad(subject: subject, predicate: predicate, object: term)
        ]
    }

    private static func genericValueObjectTerm(
        _ object: [String: SupportedJSONLDValue],
        value: SupportedJSONLDValue,
        error: CADMVInternalError
    ) throws -> RDFTerm? {
        guard object["@id"] == nil,
              try object.keys.allSatisfy({ key in
                if key == "@value" || key == "@type" || key == "@language" {
                    return true
                }
                if key == "@index" {
                    try validateGenericIndex(object[key], error: error)
                    return true
                }
                return false
              }) else {
            throw error
        }
        if case .null = value {
            return nil
        }
        guard !(object["@type"] != nil && object["@language"] != nil) else {
            throw error
        }

        if let language = object["@language"] {
            guard case .string(let languageValue) = language,
                  case .string(let text) = value,
                  isSafeLanguageTag(languageValue) else {
                throw error
            }
            return .languageLiteral(value: text, language: languageValue.lowercased())
        }

        let literal = try genericLiteral(value, error: error)
        if let type = object["@type"] {
            guard case .string(let datatype) = type,
                  try isSafeIRI(datatype, error: error) else {
                throw error
            }
            return .literal(value: literal.value, datatype: datatype)
        }
        return .literal(value: literal.value, datatype: literal.datatype)
    }

    private static func genericLiteral(
        _ value: SupportedJSONLDValue,
        error: CADMVInternalError
    ) throws -> (value: String, datatype: String?) {
        switch value {
        case .string(let text):
            return (text, nil)
        case .unsigned(let number):
            return (String(number), PinnedJSONLDTermRegistry.xsdInteger)
        case .number(let number):
            let literal = try jsonNumberLiteral(number, error: error)
            return (literal.value, literal.datatype)
        case .bool(let value):
            return (value ? "true" : "false", PinnedJSONLDTermRegistry.xsdBoolean)
        default:
            throw error
        }
    }

    private static func genericReverseQuads(
        _ value: SupportedJSONLDValue,
        object: RDFTerm,
        error: CADMVInternalError,
        blankNodeCounter: inout Int
    ) throws -> [RDFQuad] {
        guard case .object(let reverseObject) = value else {
            throw error
        }

        var quads: [RDFQuad] = []
        for predicate in reverseObject.keys.sorted() {
            guard try isSafeAbsoluteIRI(predicate, error: error),
                  let reverseValue = reverseObject[predicate] else {
                throw error
            }
            let values: [SupportedJSONLDValue]
            switch reverseValue {
            case .array(let array):
                values = array
            default:
                values = [reverseValue]
            }
            for value in values {
                let reverseSubject = try genericNodeSubjectTerm(
                    value,
                    error: error,
                    blankNodeCounter: &blankNodeCounter
                )
                quads.append(contentsOf: reverseSubject.quads)
                quads.append(RDFQuad(
                    subject: reverseSubject.term,
                    predicate: predicate,
                    object: object
                ))
            }
        }
        return quads
    }

    private static func genericNodeSubjectTerm(
        _ value: SupportedJSONLDValue,
        error: CADMVInternalError,
        blankNodeCounter: inout Int
    ) throws -> (term: RDFTerm, quads: [RDFQuad]) {
        guard case .object(let object) = value,
              object["@list"] == nil,
              object["@set"] == nil,
              object["@value"] == nil else {
            throw error
        }
        if let id = object["@id"] {
            return try genericNodeObjectTerm(
                object,
                id: id,
                error: error,
                blankNodeCounter: &blankNodeCounter
            )
        }

        let nestedSubject = RDFTerm.blank("\(genericBlankNodePrefix)\(blankNodeCounter)")
        blankNodeCounter += 1
        var quads: [RDFQuad] = []
        for key in object.keys.sorted() {
            guard let value = object[key] else {
                continue
            }
            if key == "@index" {
                try validateGenericIndex(value, error: error)
                continue
            }
            if key == "@type" {
                quads.append(contentsOf: try genericTypeQuads(
                    value,
                    subject: nestedSubject,
                    error: error
                ))
                continue
            }
            if key == "@reverse" {
                quads.append(contentsOf: try genericReverseQuads(
                    value,
                    object: nestedSubject,
                    error: error,
                    blankNodeCounter: &blankNodeCounter
                ))
                continue
            }
            if key == "@graph" {
                quads.append(contentsOf: try genericGraphQuads(
                    value,
                    graph: nestedSubject,
                    error: error,
                    blankNodeCounter: &blankNodeCounter
                ))
                continue
            }
            if key == "@included" {
                quads.append(contentsOf: try genericIncludedQuads(
                    value,
                    error: error,
                    blankNodeCounter: &blankNodeCounter
                ))
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
        return (nestedSubject, quads)
    }

    private static func genericGraphQuads(
        _ value: SupportedJSONLDValue,
        graph: RDFTerm,
        error: CADMVInternalError,
        blankNodeCounter: inout Int
    ) throws -> [RDFQuad] {
        let graphNodes: [SupportedJSONLDValue]
        switch value {
        case .array(let array):
            graphNodes = array
        default:
            graphNodes = [value]
        }

        var quads: [RDFQuad] = []
        for graphNode in graphNodes {
            guard case .object(let object) = graphNode,
                  object["@list"] == nil,
                  object["@set"] == nil,
                  object["@value"] == nil else {
                throw error
            }
            let subject: RDFTerm
            if let id = object["@id"] {
                guard case .string(let idValue) = id,
                      try isSafeIRI(idValue, error: error) else {
                    throw error
                }
                subject = .iri(idValue)
            } else {
                subject = .blank("\(genericBlankNodePrefix)\(blankNodeCounter)")
                blankNodeCounter += 1
            }

            for key in object.keys.sorted() where key != "@id" {
                guard let value = object[key] else {
                    continue
                }
                if key == "@index" {
                    try validateGenericIndex(value, error: error)
                    continue
                }
                if key == "@type" {
                    quads.append(contentsOf: try withGraph(
                        genericTypeQuads(value, subject: subject, error: error),
                        graph: graph
                    ))
                    continue
                }
                if key == "@reverse" {
                    quads.append(contentsOf: try withGraph(
                        genericReverseQuads(
                            value,
                            object: subject,
                            error: error,
                            blankNodeCounter: &blankNodeCounter
                        ),
                        graph: graph
                    ))
                    continue
                }
                if key == "@included" {
                    quads.append(contentsOf: try withGraph(
                        genericIncludedQuads(
                            value,
                            error: error,
                            blankNodeCounter: &blankNodeCounter
                        ),
                        graph: graph
                    ))
                    continue
                }
                guard let nestedQuads = try genericAbsoluteIRIQuads(
                    key: key,
                    value: value,
                    subject: subject,
                    error: error,
                    blankNodeCounter: &blankNodeCounter
                ) else {
                    throw error
                }
                quads.append(contentsOf: withGraph(nestedQuads, graph: graph))
            }
        }
        return quads
    }

    private static func validateGenericIndex(
        _ value: SupportedJSONLDValue?,
        error: CADMVInternalError
    ) throws {
        guard case .string = value else {
            throw error
        }
    }

    private static func genericIncludedQuads(
        _ value: SupportedJSONLDValue,
        error: CADMVInternalError,
        blankNodeCounter: inout Int
    ) throws -> [RDFQuad] {
        let includedNodes: [SupportedJSONLDValue]
        switch value {
        case .array(let array):
            includedNodes = array
        default:
            includedNodes = [value]
        }

        var quads: [RDFQuad] = []
        for includedNode in includedNodes {
            let included = try genericNodeSubjectTerm(
                includedNode,
                error: error,
                blankNodeCounter: &blankNodeCounter
            )
            quads.append(contentsOf: included.quads)
        }
        return quads
    }

    private static func withGraph(
        _ quads: [RDFQuad],
        graph: RDFTerm
    ) -> [RDFQuad] {
        quads.map {
            RDFQuad(
                subject: $0.subject,
                predicate: $0.predicate,
                object: $0.object,
                graph: $0.graph ?? graph
            )
        }
    }

    private static func genericTypeQuads(
        _ value: SupportedJSONLDValue,
        subject: RDFTerm,
        error: CADMVInternalError
    ) throws -> [RDFQuad] {
        let typeValues: [SupportedJSONLDValue]
        switch value {
        case .array(let values):
            typeValues = values
        default:
            typeValues = [value]
        }

        return try typeValues.map { value in
            guard case .string(let iri) = value,
                  try isSafeIRI(iri, error: error) else {
                throw error
            }
            return RDFQuad(
                subject: subject,
                predicate: PinnedJSONLDTermRegistry.rdfType,
                object: .iri(iri)
            )
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

    private static func isSafeIRI(
        _ value: String,
        error: CADMVInternalError
    ) throws -> Bool {
        guard let first = value.utf8.first,
              isASCIIAlpha(first),
              let separator = value.utf8.firstIndex(of: UInt8(ascii: ":")),
              separator != value.utf8.startIndex,
              value.utf8.index(after: separator) < value.utf8.endIndex else {
            return false
        }
        for byte in value.utf8[..<separator] {
            guard isASCIIAlphaNumeric(byte) ||
                    byte == UInt8(ascii: "+") ||
                    byte == UInt8(ascii: ".") ||
                    byte == UInt8(ascii: "-") else {
                return false
            }
        }
        for scalar in value.unicodeScalars {
            if scalar.value <= 0x20 || scalar.value == 0x7f ||
                "<>\"{}|^`\\".unicodeScalars.contains(scalar) {
                throw error
            }
        }
        return true
    }

    private static func isASCIIAlphaNumeric(_ byte: UInt8) -> Bool {
        isASCIIAlpha(byte) || (byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9"))
    }

    private static func isASCIIAlpha(_ byte: UInt8) -> Bool {
        (byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z")) ||
            (byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "z"))
    }

    private static func isSafeLanguageTag(_ value: String) -> Bool {
        guard !value.isEmpty else {
            return false
        }
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.allSatisfy({ !$0.isEmpty }) else {
            return false
        }
        return value.utf8.allSatisfy {
            ($0 >= UInt8(ascii: "A") && $0 <= UInt8(ascii: "Z")) ||
                ($0 >= UInt8(ascii: "a") && $0 <= UInt8(ascii: "z")) ||
                ($0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9")) ||
                $0 == UInt8(ascii: "-")
        }
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
