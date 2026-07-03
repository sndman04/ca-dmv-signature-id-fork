enum SupportedJSONLDCanonicalizationProfile: Equatable {
    case vcbDocument
    case statusListDocument
    case dataIntegrityProof
}

protocol JSONLDCanonicalizationEngine: Sendable {
    func canonicalNQuads(
        document: [String: SupportedJSONLDValue],
        profile: SupportedJSONLDCanonicalizationProfile
    ) throws -> String

    func quads(
        from document: [String: SupportedJSONLDValue],
        profile: SupportedJSONLDCanonicalizationProfile
    ) throws -> [RDFQuad]
}

struct SupportedProfileJSONLDCanonicalizationEngine: JSONLDCanonicalizationEngine {
    static let shared = SupportedProfileJSONLDCanonicalizationEngine()

    func canonicalNQuads(
        document: [String: SupportedJSONLDValue],
        profile: SupportedJSONLDCanonicalizationProfile
    ) throws -> String {
        try RDFDatasetCanonicalizer.canonicalNQuads(
            quads(from: document, profile: profile)
        )
    }

    func quads(
        from document: [String: SupportedJSONLDValue],
        profile: SupportedJSONLDCanonicalizationProfile
    ) throws -> [RDFQuad] {
        switch profile {
        case .vcbDocument:
            return try SupportedJSONLDRDFConverter.quads(from: document)
        case .statusListDocument:
            return try SupportedStatusListJSONLDRDFConverter.quads(from: document)
        case .dataIntegrityProof:
            return try SupportedProofJSONLDRDFConverter.quads(from: document)
        }
    }
}
