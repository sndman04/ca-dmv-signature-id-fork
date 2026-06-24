enum DMVCredentialValidator {
    static func validate(
        _ credential: DMVVerifiableCredential,
        mode: CADMVVerificationMode,
        requireStatus: Bool
    ) throws {
        guard credential.context == [
            "https://www.w3.org/ns/credentials/v2",
            "https://w3id.org/vc-barcodes/v1"
        ] else {
            throw CADMVInternalError.unsupportedVCB
        }

        guard credential.type.contains("VerifiableCredential"),
              credential.type.contains("OpticalBarcodeCredential") else {
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

        if requireStatus || credential.credentialStatus != nil {
            guard let status = credential.credentialStatus,
                  status.type == "TerseBitstringStatusListEntry",
                  status.terseStatusListBaseURL.hasPrefix(policy.statusListPrefix) else {
                throw CADMVInternalError.unsupportedVCB
            }
        }
    }

    private struct ModePolicy {
        let issuerDID: String
        let statusListPrefix: String

        init(mode: CADMVVerificationMode) {
            switch mode {
            case .production:
                issuerDID = "did:web:credentials.dmv.ca.gov"
                statusListPrefix = "https://api.credentials.dmv.ca.gov/status/dlid"
            case .uat:
                issuerDID = "did:web:uat-credentials.dmv.ca.gov"
                statusListPrefix = "https://api.uat-credentials.dmv.ca.gov/status/dlid"
            }
        }
    }
}
