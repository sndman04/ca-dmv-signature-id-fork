import Crypto
import Foundation

enum RDFTerm: Hashable {
    case blank(String)
    case iri(String)
    case literal(value: String, datatype: String?)
    case languageLiteral(value: String, language: String)

    var blankNodeIdentifier: String? {
        guard case .blank(let identifier) = self else {
            return nil
        }
        return identifier
    }
}

struct RDFQuad: Hashable {
    let subject: RDFTerm
    let predicate: String
    let object: RDFTerm
    let graph: RDFTerm?

    init(
        subject: RDFTerm,
        predicate: String,
        object: RDFTerm,
        graph: RDFTerm? = nil
    ) {
        self.subject = subject
        self.predicate = predicate
        self.object = object
        self.graph = graph
    }
}

enum RDFDatasetCanonicalizer {
    private static let maximumNDegreeHashCalls = 128

    static func canonicalNQuads(_ quads: [RDFQuad]) throws -> String {
        let dataset = Array(Set(quads))
        try validate(dataset)
        guard !dataset.isEmpty else {
            return ""
        }
        let labels = try canonicalLabels(for: dataset)
        return dataset
            .map { render($0, labels: labels) }
            .sorted()
            .joined(separator: "\n") + "\n"
    }

    static func canonicalIdentifierMap(_ quads: [RDFQuad]) throws -> [String: String] {
        let dataset = Array(Set(quads))
        try validate(dataset)
        let identifiers = blankNodeIdentifiers(in: dataset)
        let firstDegreeHashes = Dictionary(uniqueKeysWithValues: identifiers.map {
            ($0, firstDegreeHash(identifier: $0, quads: dataset))
        })
        var hashGroups = Dictionary(grouping: identifiers, by: { firstDegreeHashes[$0] ?? "" })
        var canonicalIssuer = BlankNodeIdentifierIssuer(prefix: "c14n")

        for hash in hashGroups.keys.sorted() {
            guard let group = hashGroups[hash], group.count == 1, let identifier = group.first else {
                continue
            }
            _ = canonicalIssuer.issueIdentifier(for: identifier)
            hashGroups.removeValue(forKey: hash)
        }

        var nDegreeHashCalls = 0
        for hash in hashGroups.keys.sorted() {
            guard let group = hashGroups[hash] else {
                continue
            }
            let unresolvedGroup = group
                .filter { !canonicalIssuer.hasIssuedIdentifier(for: $0) }
                .sorted()
            guard !unresolvedGroup.isEmpty else {
                continue
            }

            let hashPathList: [NDegreeHashResult] = try unresolvedGroup.map { identifier in
                var temporaryIssuer = BlankNodeIdentifierIssuer(prefix: "b")
                _ = temporaryIssuer.issueIdentifier(for: identifier)
                return try hashNDegreeQuads(
                    identifier: identifier,
                    quads: dataset,
                    firstDegreeHashes: firstDegreeHashes,
                    canonicalIssuer: canonicalIssuer,
                    issuer: temporaryIssuer,
                    callCount: &nDegreeHashCalls
                )
            }.sorted {
                if $0.hash == $1.hash {
                    return $0.issuer.issuedIdentifierMap.lexicographicallyPrecedes(
                        $1.issuer.issuedIdentifierMap
                    )
                }
                return $0.hash < $1.hash
            }

            for result in hashPathList {
                for existingIdentifier in result.issuer.issuedIdentifiers {
                    if !canonicalIssuer.hasIssuedIdentifier(for: existingIdentifier) {
                        _ = canonicalIssuer.issueIdentifier(for: existingIdentifier)
                    }
                }
            }
        }

        guard canonicalIssuer.issuedIdentifiers.count == identifiers.count else {
            throw CADMVInternalError.unsupportedVCB
        }
        return canonicalIssuer.issuedIdentifierMap
    }

    private static func canonicalLabels(for quads: [RDFQuad]) throws -> [String: String] {
        try Dictionary(uniqueKeysWithValues: canonicalIdentifierMap(quads).map {
            ($0.key, "_:\($0.value)")
        })
    }

    private static func firstDegreeHash(
        identifier: String,
        quads: [RDFQuad]
    ) -> String {
        let lines = quads
            .filter {
                $0.subject.blankNodeIdentifier == identifier ||
                    $0.object.blankNodeIdentifier == identifier ||
                    $0.graph?.blankNodeIdentifier == identifier
            }
            .map { quad in
                render(quad) { blankIdentifier in
                    blankIdentifier == identifier ? "_:a" : "_:z"
                }
            }
            .sorted()
        return Data(SHA256.hash(data: Data((lines.joined(separator: "\n") + "\n").utf8)))
            .cadmvHexString
    }

    private static func hashRelatedBlankNode(
        related: String,
        quad: RDFQuad,
        firstDegreeHashes: [String: String],
        canonicalIssuer: BlankNodeIdentifierIssuer,
        issuer: BlankNodeIdentifierIssuer,
        position: String
    ) throws -> String {
        var input = position
        input += "<\(quad.predicate)>"
        if let canonicalIdentifier = canonicalIssuer.issuedIdentifier(for: related) {
            input += "_:\(canonicalIdentifier)"
        } else if let issuedIdentifier = issuer.issuedIdentifier(for: related) {
            input += "_:\(issuedIdentifier)"
        } else {
            guard let firstDegreeHash = firstDegreeHashes[related] else {
                throw CADMVInternalError.unsupportedVCB
            }
            input += firstDegreeHash
        }
        return Data(SHA256.hash(data: Data(input.utf8))).cadmvHexString
    }

    private static func hashNDegreeQuads(
        identifier: String,
        quads: [RDFQuad],
        firstDegreeHashes: [String: String],
        canonicalIssuer: BlankNodeIdentifierIssuer,
        issuer: BlankNodeIdentifierIssuer,
        callCount: inout Int
    ) throws -> NDegreeHashResult {
        callCount += 1
        guard callCount <= maximumNDegreeHashCalls else {
            throw CADMVInternalError.unsupportedVCB
        }

        var hashToRelatedIdentifiers: [String: Set<String>] = [:]
        for quad in quadsMentioning(identifier: identifier, quads: quads) {
            if let subjectIdentifier = quad.subject.blankNodeIdentifier,
               subjectIdentifier != identifier {
                let relatedHash = try hashRelatedBlankNode(
                    related: subjectIdentifier,
                    quad: quad,
                    firstDegreeHashes: firstDegreeHashes,
                    canonicalIssuer: canonicalIssuer,
                    issuer: issuer,
                    position: "s"
                )
                hashToRelatedIdentifiers[relatedHash, default: []].insert(subjectIdentifier)
            }

            if let objectIdentifier = quad.object.blankNodeIdentifier,
               objectIdentifier != identifier {
                let relatedHash = try hashRelatedBlankNode(
                    related: objectIdentifier,
                    quad: quad,
                    firstDegreeHashes: firstDegreeHashes,
                    canonicalIssuer: canonicalIssuer,
                    issuer: issuer,
                    position: "o"
                )
                hashToRelatedIdentifiers[relatedHash, default: []].insert(objectIdentifier)
            }

            if let graphIdentifier = quad.graph?.blankNodeIdentifier,
               graphIdentifier != identifier {
                let relatedHash = try hashRelatedBlankNode(
                    related: graphIdentifier,
                    quad: quad,
                    firstDegreeHashes: firstDegreeHashes,
                    canonicalIssuer: canonicalIssuer,
                    issuer: issuer,
                    position: "g"
                )
                hashToRelatedIdentifiers[relatedHash, default: []].insert(graphIdentifier)
            }
        }

        var dataToHash = ""
        var issuer = issuer
        for relatedHash in hashToRelatedIdentifiers.keys.sorted() {
            dataToHash += relatedHash
            let relatedIdentifiers = Array(hashToRelatedIdentifiers[relatedHash] ?? []).sorted()
            var chosenPath: String?
            var chosenIssuer: BlankNodeIdentifierIssuer?

            permutationLoop: for permutation in permutations(of: relatedIdentifiers) {
                var issuerCopy = issuer
                var path = ""
                var recursionList: [String] = []

                for related in permutation {
                    if let canonicalIdentifier = canonicalIssuer.issuedIdentifier(for: related) {
                        path += "_:\(canonicalIdentifier)"
                    } else {
                        if !issuerCopy.hasIssuedIdentifier(for: related) {
                            recursionList.append(related)
                        }
                        path += "_:\(issuerCopy.issueIdentifier(for: related))"
                    }

                    if let chosenPath,
                       path.count >= chosenPath.count,
                       path >= chosenPath {
                        continue permutationLoop
                    }
                }

                for related in recursionList {
                    let result = try hashNDegreeQuads(
                        identifier: related,
                        quads: quads,
                        firstDegreeHashes: firstDegreeHashes,
                        canonicalIssuer: canonicalIssuer,
                        issuer: issuerCopy,
                        callCount: &callCount
                    )
                    path += "_:\(issuerCopy.issueIdentifier(for: related))"
                    path += "<\(result.hash)>"
                    issuerCopy = result.issuer

                    if let chosenPath,
                       path.count >= chosenPath.count,
                       path >= chosenPath {
                        continue permutationLoop
                    }
                }

                if chosenPath == nil || path < (chosenPath ?? "") {
                    chosenPath = path
                    chosenIssuer = issuerCopy
                }
            }

            guard let chosenPath, let selectedIssuer = chosenIssuer else {
                throw CADMVInternalError.unsupportedVCB
            }
            dataToHash += chosenPath
            issuer = selectedIssuer
        }

        return NDegreeHashResult(
            hash: Data(SHA256.hash(data: Data(dataToHash.utf8))).cadmvHexString,
            issuer: issuer
        )
    }

    private static func quadsMentioning(identifier: String, quads: [RDFQuad]) -> [RDFQuad] {
        quads.filter {
            $0.subject.blankNodeIdentifier == identifier ||
                $0.object.blankNodeIdentifier == identifier ||
                $0.graph?.blankNodeIdentifier == identifier
        }
    }

    private static func permutations(of identifiers: [String]) -> [[String]] {
        guard let first = identifiers.first else {
            return [[]]
        }
        let rest = Array(identifiers.dropFirst())
        return permutations(of: rest).flatMap { permutation in
            (0...permutation.count).map { index in
                var next = permutation
                next.insert(first, at: index)
                return next
            }
        }
    }

    private static func blankNodeIdentifiers(in quads: [RDFQuad]) -> [String] {
        Array(Set(quads.flatMap { quad -> [String] in
            [
                quad.subject.blankNodeIdentifier,
                quad.object.blankNodeIdentifier,
                quad.graph?.blankNodeIdentifier
            ].compactMap { $0 }
        })).sorted()
    }

    private static func render(
        _ quad: RDFQuad,
        labels: [String: String]
    ) -> String {
        render(quad) { identifier in
            guard let label = labels[identifier] else {
                preconditionFailure("Missing canonical label for blank node \(identifier)")
            }
            return label
        }
    }

    private static func render(
        _ quad: RDFQuad,
        blankLabel: (String) -> String
    ) -> String {
        let graph = quad.graph.map { " \(render($0, blankLabel: blankLabel))" } ?? ""
        return "\(render(quad.subject, blankLabel: blankLabel)) <\(quad.predicate)> \(render(quad.object, blankLabel: blankLabel))\(graph) ."
    }

    private static func render(
        _ term: RDFTerm,
        blankLabel: (String) -> String
    ) -> String {
        switch term {
        case .blank(let identifier):
            return blankLabel(identifier)
        case .iri(let value):
            return "<\(value)>"
        case let .literal(value, datatype):
            if let datatype {
                return "\"\(escapeLiteral(value))\"^^<\(datatype)>"
            }
            return "\"\(escapeLiteral(value))\""
        case let .languageLiteral(value, language):
            return "\"\(escapeLiteral(value))\"@\(language)"
        }
    }

    private static func escapeLiteral(_ value: String) -> String {
        var escaped = ""
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x08:
                escaped += "\\b"
            case 0x09:
                escaped += "\\t"
            case 0x0A:
                escaped += "\\n"
            case 0x0C:
                escaped += "\\f"
            case 0x0D:
                escaped += "\\r"
            case 0x22:
                escaped += "\\\""
            case 0x5C:
                escaped += "\\\\"
            case 0x00...0x1F, 0x7F:
                escaped += String(format: "\\u%04X", scalar.value)
            default:
                escaped.unicodeScalars.append(scalar)
            }
        }
        return escaped
    }

    private static func validate(_ quads: [RDFQuad]) throws {
        for quad in quads {
            try validateTerm(quad.subject, position: .subject)
            try validateIRI(quad.predicate)
            try validateTerm(quad.object, position: .object)
            if let graph = quad.graph {
                try validateTerm(graph, position: .graph)
            }
        }
    }

    private enum TermPosition {
        case subject
        case object
        case graph
    }

    private static func validateTerm(
        _ term: RDFTerm,
        position: TermPosition
    ) throws {
        switch term {
        case .blank(let identifier):
            guard !identifier.isEmpty,
                  !identifier.unicodeScalars.contains(where: { $0.value <= 0x20 || $0.value == 0x7f }) else {
                throw CADMVInternalError.unsupportedVCB
            }
        case .iri(let value):
            try validateIRI(value)
        case .literal(_, let datatype):
            guard position == .object else {
                throw CADMVInternalError.unsupportedVCB
            }
            if let datatype {
                try validateIRI(datatype)
            }
        case .languageLiteral(_, let language):
            guard position == .object,
                  isValidLanguageTag(language) else {
                throw CADMVInternalError.unsupportedVCB
            }
        }
    }

    private static func validateIRI(_ value: String) throws {
        guard !value.isEmpty,
              value.utf8.contains(UInt8(ascii: ":")) else {
            throw CADMVInternalError.unsupportedVCB
        }
        for scalar in value.unicodeScalars {
            if scalar.value <= 0x20 || scalar.value == 0x7f ||
                "<>\"{}|^`\\".unicodeScalars.contains(scalar) {
                throw CADMVInternalError.unsupportedVCB
            }
        }
    }

    private static func isValidLanguageTag(_ value: String) -> Bool {
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
}

private struct NDegreeHashResult {
    let hash: String
    let issuer: BlankNodeIdentifierIssuer
}

private struct BlankNodeIdentifierIssuer {
    let prefix: String
    private(set) var issuedIdentifierMap: [String: String] = [:]
    private var counter = 0

    init(prefix: String) {
        self.prefix = prefix
    }

    var issuedIdentifiers: [String] {
        issuedIdentifierMap
            .sorted { $0.value < $1.value }
            .map(\.key)
    }

    func hasIssuedIdentifier(for existingIdentifier: String) -> Bool {
        issuedIdentifierMap[existingIdentifier] != nil
    }

    func issuedIdentifier(for existingIdentifier: String) -> String? {
        issuedIdentifierMap[existingIdentifier]
    }

    mutating func issueIdentifier(for existingIdentifier: String) -> String {
        if let issuedIdentifier = issuedIdentifierMap[existingIdentifier] {
            return issuedIdentifier
        }
        let issuedIdentifier = "\(prefix)\(counter)"
        counter += 1
        issuedIdentifierMap[existingIdentifier] = issuedIdentifier
        return issuedIdentifier
    }
}

private extension Dictionary where Key == String, Value == String {
    func lexicographicallyPrecedes(_ other: [String: String]) -> Bool {
        let lhs = sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
        let rhs = other.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
        return lhs.lexicographicallyPrecedes(rhs)
    }
}
