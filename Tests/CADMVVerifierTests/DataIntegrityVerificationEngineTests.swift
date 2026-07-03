@testable import CADMVVerifier
import Foundation
import XCTest

final class DataIntegrityVerificationEngineTests: XCTestCase {
    func testLegacyVCBEngineRejectsVerificationMethodMismatchBeforeSignatureWork() throws {
        let credential = DMVVerifiableCredential(
            context: [
                "https://www.w3.org/ns/credentials/v2",
                "https://w3id.org/vc-barcodes/v1"
            ],
            type: ["VerifiableCredential", "OpticalBarcodeCredential"],
            issuer: "did:web:uat-credentials.dmv.ca.gov",
            validFrom: nil,
            validUntil: nil,
            credentialSubject: DMVVerifiableCredential.CredentialSubject(
                type: "AamvaDriversLicenseScannableInformation",
                protectedComponentIndex: "uAQID"
            ),
            credentialStatus: nil,
            proof: DMVVerifiableCredential.Proof(
                type: "DataIntegrityProof",
                created: nil,
                expires: nil,
                cryptosuite: "ecdsa-xi-2023",
                proofPurpose: "assertionMethod",
                proofValue: "zLdp",
                verificationMethod: "did:web:uat-credentials.dmv.ca.gov#vm-vcb-1"
            )
        )

        XCTAssertThrowsError(try LegacyHandbuiltDataIntegrityEngine.shared.verifyVCB(
            credential: credential,
            opticalDataHash: Data(repeating: 0, count: 32),
            verificationKey: mismatchedKey()
        )) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }
    }

    func testLegacyStatusListEngineRejectsVerificationMethodMismatchBeforeSignatureWork() throws {
        let credential = DMVStatusListCredential(
            id: "https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists/revocation/0",
            type: ["VerifiableCredential", "BitstringStatusListCredential"],
            issuer: "did:web:uat-credentials.dmv.ca.gov",
            validFrom: nil,
            validUntil: nil,
            name: nil,
            description: nil,
            credentialSubject: DMVStatusListCredential.CredentialSubject(
                id: "https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists/revocation/0#list",
                type: "BitstringStatusList",
                encodedList: "uAA",
                statusPurpose: "revocation"
            ),
            proof: DMVStatusListCredential.Proof(
                type: "DataIntegrityProof",
                created: nil,
                verificationMethod: "did:web:uat-credentials.dmv.ca.gov#status-vm-1",
                cryptosuite: "ecdsa-rdfc-2019",
                proofPurpose: "assertionMethod",
                proofValue: "zLdp"
            )
        )

        XCTAssertThrowsError(try LegacyHandbuiltDataIntegrityEngine.shared.verifyStatusListCredential(
            credential,
            verificationKey: mismatchedKey()
        )) { error in
            XCTAssertEqual(error as? CADMVInternalError, .statusListDecodeFailed)
        }
    }

    private func mismatchedKey() -> DIDDocumentKey {
        DIDDocumentKey(
            id: "did:web:uat-credentials.dmv.ca.gov#different",
            controller: "did:web:uat-credentials.dmv.ca.gov",
            type: "Multikey",
            publicKeyMultibase: "zSynthetic",
            compressedP256Key: Data(repeating: 0, count: 33)
        )
    }
}
