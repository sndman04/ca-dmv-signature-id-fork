import Foundation

struct VerificationPipeline {
    let options: CADMVVerificationOptions

    func verify(rawPDF417: String) async throws -> CADMVVerificationResult {
        let document = try AAMVADocumentParser().parse(rawPDF417: rawPDF417)

        guard document.isCaliforniaDMVDocument else {
            return VerificationMessages.result(
                for: .notPresent,
                failureReason: .notCaliforniaDMV
            )
        }

        let vcbRequired = options.requireVCB || document.requiresCaliforniaVCB
        guard let encodedVCB = document.verifiableCredentialBarcode else {
            return VerificationMessages.result(
                for: vcbRequired ? .failed : .notPresent,
                failureReason: .vcbMissing(required: vcbRequired)
            )
        }

        guard let vcbData = Base64URL.decode(encodedVCB) else {
            return VerificationMessages.result(
                for: .failed,
                failureReason: .vcbBase64Invalid
            )
        }

        let credential: DMVVerifiableCredential
        do {
            credential = try DMVVCBDecoder.decode(vcbData)
        } catch {
            return VerificationMessages.result(
                for: .failed,
                failureReason: .vcbCBORUnsupported
            )
        }

        do {
            try DMVCredentialValidator.validate(
                credential,
                mode: options.mode
            )
        } catch CADMVInternalError.environmentMismatch(let expected) {
            return VerificationMessages.result(
                for: .failed,
                failureReason: .environmentMismatch(expected: expected)
            )
        } catch {
            return VerificationMessages.result(
                for: .failed,
                failureReason: .unsupportedCredentialProfile
            )
        }

        let opticalDataHash: Data
        do {
            opticalDataHash = try AAMVACanonicalizer.hash(AAMVACanonicalizer.protectedDocument(
                from: document,
                componentIndex: credential.credentialSubject.protectedComponentIndex
            ))
        } catch {
            return VerificationMessages.result(
                for: .failed,
                failureReason: .protectedAAMVADataUnavailable
            )
        }

        let key: DIDDocumentKey
        do {
            key = try await DIDWebResolver.resolveVerificationMethod(
                id: credential.proof.verificationMethod,
                mode: options.mode,
                timeoutSeconds: options.networkTimeoutSeconds
            )
        } catch {
            return VerificationMessages.result(
                for: .failed,
                failureReason: .didResolutionFailed
            )
        }

        do {
            guard try EcdsaXi2023Verifier.verify(
                credential: credential,
                opticalDataHash: opticalDataHash,
                verificationKey: key
            ) else {
                return VerificationMessages.result(
                    for: .failed,
                    failureReason: .signatureMismatch
                )
            }
        } catch {
            return VerificationMessages.result(
                for: .failed,
                failureReason: .signatureMismatch
            )
        }

        if options.checkStatus {
            switch await StatusListChecker.check(
                credential: credential,
                mode: options.mode,
                timeoutSeconds: options.networkTimeoutSeconds
            ) {
            case .notRevoked:
                break
            case .revoked:
                return VerificationMessages.result(
                    for: .revoked,
                    failureReason: .revoked
                )
            case .unavailable:
                return VerificationMessages.result(
                    for: .unavailable,
                    failureReason: .statusUnavailable
                )
            }
        }

        do {
            if try CredentialExpiration.isExpired(credential) {
                return VerificationMessages.result(
                    for: .expired,
                    failureReason: .expired
                )
            }
        } catch {
            return VerificationMessages.result(
                for: .failed,
                failureReason: .unsupportedCredentialProfile
            )
        }

        return VerificationMessages.result(for: .verified)
    }
}
