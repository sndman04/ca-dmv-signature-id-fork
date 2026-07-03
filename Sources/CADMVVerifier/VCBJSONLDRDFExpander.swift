enum VCBJSONLDRDFExpander {
    static func canonicalNQuads(
        _ credential: DMVVerifiableCredential,
        engine: any JSONLDCanonicalizationEngine = SupportedProfileJSONLDCanonicalizationEngine.shared
    ) throws -> String {
        try engine.canonicalNQuads(
            document: jsonLDDocument(from: credential),
            profile: .vcbDocument
        )
    }

    static func documentQuads(
        _ credential: DMVVerifiableCredential,
        engine: any JSONLDCanonicalizationEngine = SupportedProfileJSONLDCanonicalizationEngine.shared
    ) throws -> [RDFQuad] {
        try engine.quads(
            from: jsonLDDocument(from: credential),
            profile: .vcbDocument
        )
    }

    static func jsonLDDocument(
        from credential: DMVVerifiableCredential
    ) -> [String: SupportedJSONLDValue] {
        var document: [String: SupportedJSONLDValue] = [
            "@context": .array(credential.context.map { .string($0) }),
            "type": .array(credential.type.map { .string($0) }),
            "issuer": .string(credential.issuer),
            "credentialSubject": .object([
                "type": .string(credential.credentialSubject.type),
                "protectedComponentIndex": .string(
                    credential.credentialSubject.protectedComponentIndex
                )
            ])
        ]

        if let status = credential.credentialStatus {
            document["credentialStatus"] = .object([
                "type": .string(status.type),
                "terseStatusListBaseUrl": .string(status.terseStatusListBaseURL),
                "terseStatusListIndex": .unsigned(status.terseStatusListIndex)
            ])
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
