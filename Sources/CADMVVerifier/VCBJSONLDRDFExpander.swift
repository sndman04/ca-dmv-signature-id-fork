enum VCBJSONLDRDFExpander {
    static func canonicalNQuads(
        _ credential: DMVVerifiableCredential,
        engine: any JSONLDCanonicalizationEngine = ProductionJSONLDCanonicalizationEngine.shared
    ) throws -> String {
        try engine.canonicalNQuads(
            document: jsonLDDocument(from: credential),
            profile: .vcbDocument
        )
    }

    static func documentQuads(
        _ credential: DMVVerifiableCredential,
        engine: any JSONLDCanonicalizationEngine = ProductionJSONLDCanonicalizationEngine.shared
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

        if let id = credential.id {
            document["id"] = .string(id)
        }
        if let subjectID = credential.credentialSubject.id,
           case .object(var subject) = document["credentialSubject"] {
            subject["id"] = .string(subjectID)
            document["credentialSubject"] = .object(subject)
        }
        if let status = credential.credentialStatus {
            var statusObject: [String: SupportedJSONLDValue] = [
                "type": .string(status.type),
                "terseStatusListBaseUrl": .string(status.terseStatusListBaseURL),
                "terseStatusListIndex": .unsigned(status.terseStatusListIndex)
            ]
            if let statusID = status.id {
                statusObject["id"] = .string(statusID)
            }
            document["credentialStatus"] = .object(statusObject)
        }
        if let validFrom = credential.validFrom {
            document["validFrom"] = .string(validFrom)
        }
        if let validUntil = credential.validUntil {
            document["validUntil"] = .string(validUntil)
        }
        for (key, value) in credential.additionalProperties {
            document[key] = value
        }
        return document
    }
}
