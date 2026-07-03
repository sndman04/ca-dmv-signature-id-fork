@testable import CADMVVerifier
import Crypto
import Foundation
import XCTest

final class DataIntegrityVerificationEngineTests: XCTestCase {
    private let p256Order = Data([
        0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xbc, 0xe6, 0xfa, 0xad, 0xa7, 0x17, 0x9e, 0x84,
        0xf3, 0xb9, 0xca, 0xc2, 0xfc, 0x63, 0x25, 0x51
    ])

    func testProofValueDecodesBase58BTCAndBase64URLRawSignatures() throws {
        let rawSignature = Data(0..<64)

        XCTAssertEqual(
            try ECDSAProofVerifier.rawSignature(
                from: "z" + Base58BTC.encode(rawSignature),
                error: .unsupportedVCB
            ),
            rawSignature
        )
        XCTAssertEqual(
            try ECDSAProofVerifier.rawSignature(
                from: "u" + Base64URL.encode(rawSignature),
                error: .unsupportedVCB
            ),
            rawSignature
        )
    }

    func testProofValueRejectsUnsupportedPrefixesMalformedDataAndWrongLengths() {
        let validLength = Data(repeating: 0x01, count: 64)
        let wrongLengths = [
            Data(),
            Data(repeating: 0x01, count: 63),
            Data(repeating: 0x01, count: 65)
        ]
        let malformedValues = [
            "",
            "x" + Base58BTC.encode(validLength),
            "z0",
            "u***"
        ] + wrongLengths.flatMap {
            [
                "z" + Base58BTC.encode($0),
                "u" + Base64URL.encode($0)
            ]
        }

        for proofValue in malformedValues {
            XCTAssertThrowsError(try ECDSAProofVerifier.rawSignature(
                from: proofValue,
                error: .unsupportedVCB
            )) { error in
                XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
            }
        }
    }

    func testP256SignatureVerifierAcceptsHighSCounterpartLikeReferenceWebCrypto() throws {
        let privateKey = P256.Signing.PrivateKey()
        let verifyData = Data([1, 2, 3])
        let signature = try privateKey.signature(for: verifyData).rawRepresentation
        let highSCounterpart = try signatureWithCounterpartS(signature)
        let verificationKey = DIDDocumentKey(
            id: "did:example:issuer#key-1",
            controller: "did:example:issuer",
            type: "Multikey",
            publicKeyMultibase: "zSynthetic",
            compressedP256Key: privateKey.publicKey.compressedRepresentation
        )

        XCTAssertTrue(try ECDSAProofVerifier.verifyP256Signature(
            proofValue: "z" + Base58BTC.encode(signature),
            verifyData: verifyData,
            verificationKey: verificationKey,
            error: .unsupportedVCB
        ))
        XCTAssertTrue(try ECDSAProofVerifier.verifyP256Signature(
            proofValue: "z" + Base58BTC.encode(highSCounterpart),
            verifyData: verifyData,
            verificationKey: verificationKey,
            error: .unsupportedVCB
        ))
    }

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

    private func signatureWithCounterpartS(_ signature: Data) throws -> Data {
        let r = signature.prefix(32)
        let s = signature.suffix(32)
        let counterpart = try subtract32ByteBigEndian(s, from: p256Order)
        return Data(r + counterpart)
    }

    private func subtract32ByteBigEndian(
        _ subtrahend: Data.SubSequence,
        from minuend: Data
    ) throws -> Data {
        XCTAssertEqual(minuend.count, 32)
        XCTAssertEqual(subtrahend.count, 32)
        var result = Data(repeating: 0, count: 32)
        var borrow = 0
        for index in stride(from: 31, through: 0, by: -1) {
            let diff = Int(minuend[index]) - Int(subtrahend[subtrahend.startIndex + index]) - borrow
            if diff < 0 {
                result[index] = UInt8(diff + 256)
                borrow = 1
            } else {
                result[index] = UInt8(diff)
                borrow = 0
            }
        }
        XCTAssertEqual(borrow, 0)
        return result
    }
}
