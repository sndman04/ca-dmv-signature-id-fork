enum DMVCredentialValidator {
    static func validate(
        _ credential: DMVVerifiableCredential,
        mode: CADMVVerificationMode
    ) throws {
        guard credential.context == [
            "https://www.w3.org/ns/credentials/v2",
            "https://w3id.org/vc-barcodes/v1"
        ] else {
            throw CADMVInternalError.unsupportedVCB
        }

        guard isExactTypeSet(
            credential.type,
            ["VerifiableCredential", "OpticalBarcodeCredential"]
        ) else {
            throw CADMVInternalError.unsupportedVCB
        }

        guard credential.credentialSubject.type == "AamvaDriversLicenseScannableInformation",
              !credential.credentialSubject.protectedComponentIndex.isEmpty else {
            throw CADMVInternalError.unsupportedVCB
        }

        let policy = ModePolicy(mode: mode)
        guard credential.issuer == policy.issuerDID,
              credential.proof.verificationMethod.hasPrefix(policy.issuerDID + "#") else {
            throw CADMVInternalError.environmentMismatch(expected: mode)
        }

        guard credential.proof.type == "DataIntegrityProof",
              credential.proof.cryptosuite == "ecdsa-xi-2023",
              credential.proof.proofPurpose == "assertionMethod",
              credential.proof.proofValue.first == "z" else {
            throw CADMVInternalError.unsupportedVCB
        }

        if credential.credentialStatus != nil {
            guard let status = credential.credentialStatus,
                  status.type == "TerseBitstringStatusListEntry",
                  policy.statusListBaseURLs.contains(status.terseStatusListBaseURL) else {
                throw CADMVInternalError.unsupportedVCB
            }
        }
    }

    private static func isExactTypeSet(_ values: [String], _ expected: Set<String>) -> Bool {
        Set(values) == expected && values.count == expected.count
    }

    private struct ModePolicy {
        let issuerDID: String
        let statusListBaseURLs: Set<String>

        init(mode: CADMVVerificationMode) {
            switch mode {
            case .production:
                issuerDID = "did:web:credentials.dmv.ca.gov"
                statusListBaseURLs = [
                    "https://api.credentials.dmv.ca.gov/status/dlid/1/status-lists",
                    "https://api.credentials.dmv.ca.gov/status/dlid/2/status-lists",
                    "https://api.credentials.dmv.ca.gov/status/dlid/3/status-lists"
                ]
            case .uat:
                issuerDID = "did:web:uat-credentials.dmv.ca.gov"
                statusListBaseURLs = [
                    "https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists",
                    "https://api.uat-credentials.dmv.ca.gov/status/dlid/2/status-lists",
                    "https://api.uat-credentials.dmv.ca.gov/status/dlid/3/status-lists"
                ]
            }
        }
    }
}
