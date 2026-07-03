import Crypto
import Foundation

enum EcdsaXi2023Verifier {
    // DMV profile verifier. It builds the supported JSON-LD graph explicitly
    // and derives canonical blank-node labels instead of guessing c14n order.
    static func verify(
        credential: DMVVerifiableCredential,
        opticalDataHash: Data,
        verificationKey: DIDDocumentKey
    ) throws -> Bool {
        guard credential.proof.verificationMethod == verificationKey.id else {
            throw CADMVInternalError.unsupportedVCB
        }

        let verifyData = try createVerifyData(
            credential: credential,
            opticalDataHash: opticalDataHash
        )
        return try ECDSAProofVerifier.verifyP256Signature(
            proofValue: credential.proof.proofValue,
            verifyData: verifyData,
            verificationKey: verificationKey,
            error: .unsupportedVCB
        )
    }

    static func createVerifyData(
        credential: DMVVerifiableCredential,
        opticalDataHash: Data
    ) throws -> Data {
        let proofHash = Data(SHA256.hash(data: Data(try DataIntegrityProofCanonicalizer.canonicalNQuads(
            contexts: credential.context,
            type: credential.proof.type,
            created: credential.proof.created,
            expires: credential.proof.expires,
            cryptosuite: credential.proof.cryptosuite,
            proofPurpose: credential.proof.proofPurpose,
            verificationMethod: credential.proof.verificationMethod
        ).utf8)))
        let documentHash = Data(SHA256.hash(data: Data(try VCBJSONLDRDFExpander.canonicalNQuads(credential).utf8)))
        let externalHash = Data(SHA256.hash(data: opticalDataHash))

        var data = Data()
        data.append(proofHash)
        data.append(documentHash)
        data.append(externalHash)
        return data
    }
}

enum RDFTerm: Equatable {
    case blank(String)
    case iri(String)
    case literal(value: String, datatype: String?)

    var blankNodeIdentifier: String? {
        guard case .blank(let identifier) = self else {
            return nil
        }
        return identifier
    }
}

struct RDFQuad: Equatable {
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
        let identifiers = blankNodeIdentifiers(in: quads)
        let labels = try canonicalLabels(for: identifiers, quads: quads)
        return quads
            .map { render($0, labels: labels) }
            .sorted()
            .joined(separator: "\n") + "\n"
    }

    private static func canonicalLabels(
        for identifiers: [String],
        quads: [RDFQuad]
    ) throws -> [String: String] {
        let firstDegreeHashes = Dictionary(uniqueKeysWithValues: identifiers.map {
            ($0, firstDegreeHash(identifier: $0, quads: quads))
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
                    quads: quads,
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
        return Dictionary(uniqueKeysWithValues: canonicalIssuer.issuedIdentifierMap.map {
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
            let escaped = value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            if let datatype {
                return "\"\(escaped)\"^^<\(datatype)>"
            }
            return "\"\(escaped)\""
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

enum DataIntegrityProofCanonicalizer {
    static func canonicalNQuads(
        contexts: [String] = ["https://www.w3.org/ns/credentials/v2"],
        type: String,
        created: String?,
        expires: String?,
        cryptosuite: String,
        proofPurpose: String,
        verificationMethod: String
    ) throws -> String {
        try SupportedProofJSONLDRDFConverter.canonicalNQuads(
            document: jsonLDDocument(
                contexts: contexts,
                type: type,
                created: created,
                expires: expires,
                cryptosuite: cryptosuite,
                proofPurpose: proofPurpose,
                verificationMethod: verificationMethod
            )
        )
    }

    static func jsonLDDocument(
        contexts: [String] = ["https://www.w3.org/ns/credentials/v2"],
        type: String,
        created: String?,
        expires: String?,
        cryptosuite: String,
        proofPurpose: String,
        verificationMethod: String
    ) -> [String: SupportedJSONLDValue] {
        var document: [String: SupportedJSONLDValue] = [
            "@context": .array(contexts.map { .string($0) }),
            "type": .string(type),
            "cryptosuite": .string(cryptosuite),
            "proofPurpose": .string(proofPurpose),
            "verificationMethod": .string(verificationMethod)
        ]
        if let created {
            document["created"] = .string(created)
        }
        if let expires {
            document["expires"] = .string(expires)
        }
        return document
    }
}

enum SupportedProofJSONLDRDFConverter {
    private static let rdfType = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
    private static let dctermsCreated = "http://purl.org/dc/terms/created"
    private static let xsdDateTime = "http://www.w3.org/2001/XMLSchema#dateTime"
    private static let security = "https://w3id.org/security#"

    static func canonicalNQuads(
        document: [String: SupportedJSONLDValue]
    ) throws -> String {
        try RDFDatasetCanonicalizer.canonicalNQuads(quads(from: document))
    }

    static func quads(
        from document: [String: SupportedJSONLDValue]
    ) throws -> [RDFQuad] {
        try requireSupportedContexts(document["@context"])
        var quads: [RDFQuad] = []
        for key in document.keys.sorted() {
            guard key != "@context" else {
                continue
            }
            let value = document[key]
            switch (key, value) {
            case ("type", .some(.string(let type))):
                quads.append(RDFQuad(
                    subject: .blank("proof"),
                    predicate: rdfType,
                    object: .iri(try proofTypeIRI(type))
                ))
            case ("cryptosuite", .some(.string(let cryptosuite))):
                guard cryptosuite == "ecdsa-xi-2023" || cryptosuite == "ecdsa-rdfc-2019" else {
                    throw CADMVInternalError.unsupportedVCB
                }
                quads.append(RDFQuad(
                    subject: .blank("proof"),
                    predicate: security + "cryptosuite",
                    object: .literal(value: cryptosuite, datatype: security + "cryptosuiteString")
                ))
            case ("proofPurpose", .some(.string(let proofPurpose))):
                guard proofPurpose == "assertionMethod" else {
                    throw CADMVInternalError.unsupportedVCB
                }
                quads.append(RDFQuad(
                    subject: .blank("proof"),
                    predicate: security + "proofPurpose",
                    object: .iri(security + proofPurpose)
                ))
            case ("verificationMethod", .some(.string(let verificationMethod))):
                quads.append(RDFQuad(
                    subject: .blank("proof"),
                    predicate: security + "verificationMethod",
                    object: .iri(verificationMethod)
                ))
            case ("created", .some(.string(let dateTime))):
                quads.append(try dateTimeQuad(
                    predicate: dctermsCreated,
                    value: dateTime
                ))
            case ("expires", .some(.string(let dateTime))):
                quads.append(try dateTimeQuad(
                    predicate: security + "expiration",
                    value: dateTime
                ))
            default:
                throw CADMVInternalError.unsupportedVCB
            }
        }
        return quads
    }

    private static func dateTimeQuad(
        predicate: String,
        value: String
    ) throws -> RDFQuad {
        guard DMVVCBDecoder.isSafeDateTimeTextForRDF(value) else {
            throw CADMVInternalError.unsupportedVCB
        }
        return RDFQuad(
            subject: .blank("proof"),
            predicate: predicate,
            object: .literal(value: value, datatype: xsdDateTime)
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
        switch strings {
        case ["https://www.w3.org/ns/credentials/v2"],
             ["https://www.w3.org/ns/credentials/v2", "https://w3id.org/vc-barcodes/v1"]:
            return
        default:
            throw CADMVInternalError.unsupportedVCB
        }
    }

    private static func proofTypeIRI(_ value: String) throws -> String {
        guard value == "DataIntegrityProof" else {
            throw CADMVInternalError.unsupportedVCB
        }
        return security + value
    }
}
