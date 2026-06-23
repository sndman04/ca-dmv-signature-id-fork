import Foundation

struct VerificationPipeline {
    let options: CADMVVerificationOptions

    func verify(rawPDF417: String) async throws -> CADMVVerificationResult {
        let document = try AAMVADocumentParser().parse(rawPDF417: rawPDF417)

        guard document.isCaliforniaDMVDocument else {
            return VerificationMessages.result(for: .notPresent)
        }

        let vcbRequired = options.requireVCB || document.requiresCaliforniaVCB
        guard let encodedVCB = document.verifiableCredentialBarcode else {
            return VerificationMessages.result(for: vcbRequired ? .failed : .notPresent)
        }

        guard let vcbData = Base64URL.decode(encodedVCB) else {
            return VerificationMessages.result(for: .failed)
        }

        guard let credential = try? DMVVCBDecoder.decode(vcbData),
              (try? DMVCredentialValidator.validate(
                credential,
                mode: options.mode,
                requireStatus: options.checkStatus
              )) != nil,
              let opticalDataHash = try? AAMVACanonicalizer.hash(AAMVACanonicalizer.protectedDocument(
                from: document,
                componentIndex: credential.credentialSubject.protectedComponentIndex
              )) else {
            return VerificationMessages.result(for: .failed)
        }

        do {
            let key = try await DIDWebResolver.resolveVerificationMethod(
                id: credential.proof.verificationMethod,
                mode: options.mode,
                timeoutSeconds: options.networkTimeoutSeconds
            )
            guard try EcdsaXi2023Verifier.verify(
                credential: credential,
                opticalDataHash: opticalDataHash,
                verificationKey: key
            ) else {
                return VerificationMessages.result(for: .failed)
            }
        } catch {
            return VerificationMessages.result(for: .failed)
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
                return VerificationMessages.result(for: .revoked)
            case .unavailable:
                return VerificationMessages.result(for: .unavailable)
            }
        }

        return VerificationMessages.result(for: .verified)
    }
}
