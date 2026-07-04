enum PinnedJSONLDTermRegistry {
    static let credentialsV2Context = "https://www.w3.org/ns/credentials/v2"
    static let vcBarcodesV1Context = "https://w3id.org/vc-barcodes/v1"

    static let rdfType = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
    static let rdfFirst = "http://www.w3.org/1999/02/22-rdf-syntax-ns#first"
    static let rdfRest = "http://www.w3.org/1999/02/22-rdf-syntax-ns#rest"
    static let rdfNil = "http://www.w3.org/1999/02/22-rdf-syntax-ns#nil"
    static let xsdDateTime = "http://www.w3.org/2001/XMLSchema#dateTime"
    static let xsdInteger = "http://www.w3.org/2001/XMLSchema#integer"
    static let xsdBoolean = "http://www.w3.org/2001/XMLSchema#boolean"
    static let xsdDouble = "http://www.w3.org/2001/XMLSchema#double"
    static let dctermsCreated = "http://purl.org/dc/terms/created"

    private static let vc = "https://www.w3.org/2018/credentials#"
    private static let vcb = "https://w3id.org/vc-barcodes#"
    private static let status = "https://www.w3.org/ns/credentials/status#"
    private static let security = "https://w3id.org/security#"
    private static let schema = "https://schema.org/"

    static func vcbTypeIRI(_ value: String) throws -> String {
        switch value {
        case "VerifiableCredential":
            return vc + value
        case "OpticalBarcodeCredential",
             "AamvaDriversLicenseScannableInformation",
             "TerseBitstringStatusListEntry":
            return vcb + value
        default:
            throw CADMVInternalError.unsupportedVCB
        }
    }

    static func requireVCBDocumentContexts(_ value: SupportedJSONLDValue?) throws {
        guard try contextStrings(from: value, error: .unsupportedVCB) == [
            credentialsV2Context,
            vcBarcodesV1Context
        ] else {
            throw CADMVInternalError.unsupportedVCB
        }
    }

    static func requireStatusListDocumentContexts(_ value: SupportedJSONLDValue?) throws {
        guard try contextStrings(from: value, error: .statusListDecodeFailed) == [
            credentialsV2Context
        ] else {
            throw CADMVInternalError.statusListDecodeFailed
        }
    }

    static func requireProofContexts(_ value: SupportedJSONLDValue?) throws {
        switch try contextStrings(from: value, error: .unsupportedVCB) {
        case [credentialsV2Context],
             [credentialsV2Context, vcBarcodesV1Context]:
            return
        default:
            throw CADMVInternalError.unsupportedVCB
        }
    }

    static func statusListTypeIRI(_ value: String) throws -> String {
        switch value {
        case "VerifiableCredential":
            return vc + value
        case "BitstringStatusListCredential",
             "BitstringStatusList":
            return status + value
        default:
            throw CADMVInternalError.statusListDecodeFailed
        }
    }

    static func proofTypeIRI(_ value: String) throws -> String {
        guard value == "DataIntegrityProof" else {
            throw CADMVInternalError.unsupportedVCB
        }
        return security + value
    }

    static func vcbPredicate(_ term: String) throws -> String {
        switch term {
        case "issuer":
            return vc + "issuer"
        case "credentialSubject":
            return vc + "credentialSubject"
        case "credentialStatus":
            return vc + "credentialStatus"
        case "validFrom":
            return vc + "validFrom"
        case "validUntil":
            return vc + "validUntil"
        case "protectedComponentIndex":
            return vcb + "protectedComponentIndex"
        case "terseStatusListBaseUrl":
            return vcb + "terseStatusListBaseUrl"
        case "terseStatusListIndex":
            return vcb + "terseStatusListIndex"
        default:
            throw CADMVInternalError.unsupportedVCB
        }
    }

    static func statusListPredicate(_ term: String) throws -> String {
        switch term {
        case "issuer":
            return vc + "issuer"
        case "credentialSubject":
            return vc + "credentialSubject"
        case "description":
            return schema + "description"
        case "name":
            return schema + "name"
        case "validFrom":
            return vc + "validFrom"
        case "validUntil":
            return vc + "validUntil"
        case "encodedList":
            return status + "encodedList"
        case "statusPurpose":
            return status + "statusPurpose"
        default:
            throw CADMVInternalError.statusListDecodeFailed
        }
    }

    static func proofPredicate(_ term: String) throws -> String {
        switch term {
        case "created":
            return dctermsCreated
        case "expires":
            return security + "expiration"
        case "cryptosuite":
            return security + "cryptosuite"
        case "proofPurpose":
            return security + "proofPurpose"
        case "verificationMethod":
            return security + "verificationMethod"
        default:
            throw CADMVInternalError.unsupportedVCB
        }
    }

    static func securityIRI(_ term: String) -> String {
        security + term
    }

    static var securityMultibaseDatatype: String {
        security + "multibase"
    }

    static var cryptosuiteStringDatatype: String {
        security + "cryptosuiteString"
    }

    private static func contextStrings(
        from value: SupportedJSONLDValue?,
        error: CADMVInternalError
    ) throws -> [String] {
        guard case .array(let contexts) = value else {
            throw error
        }
        return try contexts.map { value in
            guard case .string(let context) = value else {
                throw error
            }
            return context
        }
    }
}
