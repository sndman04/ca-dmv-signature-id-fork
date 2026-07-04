@_spi(Testing) @testable import CADMVVerifier
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest

final class CADMVVerifierTests: XCTestCase {
    func testMalformedBarcodeReportsReason() async {
        let result = await CADMVVerifier.verify(rawPDF417: "ANSI")

        XCTAssert(result.status == .failed)
        XCTAssert(result.failureReason == .malformedBarcode)
    }

    func testMissingOptionalVCBIsNotPresent() async {
        let barcode = AAMVATestBarcode.make(
            issuer: "636014",
            issueDate: "09282025",
            jurisdiction: "CA",
            encodedVCB: nil
        )

        let result = await CADMVVerifier.verify(rawPDF417: barcode)

        XCTAssert(result.status == .notPresent)
        XCTAssert(result.failureReason == .vcbMissing(required: false))
    }

    func testMissingRequiredVCBFails() async {
        let barcode = AAMVATestBarcode.make(
            issuer: "636014",
            issueDate: "09292025",
            jurisdiction: "CA",
            encodedVCB: nil
        )

        let result = await CADMVVerifier.verify(rawPDF417: barcode)

        XCTAssert(result.status == .failed)
        XCTAssert(result.failureReason == .vcbMissing(required: true))
    }

    func testNonCaliforniaDocumentReportsReason() async {
        let barcode = AAMVATestBarcode.make(
            issuer: "636000",
            issueDate: "09292025",
            jurisdiction: "NV",
            encodedVCB: "AQIDBA"
        )

        let result = await CADMVVerifier.verify(rawPDF417: barcode)

        XCTAssert(result.status == .notPresent)
        XCTAssert(result.failureReason == .notCaliforniaDMV)
    }

    func testMalformedVCBReportsBase64Reason() async {
        let barcode = AAMVATestBarcode.make(
            issuer: "636014",
            issueDate: "08052025",
            jurisdiction: "CA",
            encodedVCB: "not.valid.base64"
        )

        let result = await CADMVVerifier.verify(rawPDF417: barcode)

        XCTAssert(result.status == .failed)
        XCTAssert(result.failureReason == .vcbBase64Invalid)
    }

    func testInspectionPreservesDiscoveryFieldsForMalformedBase64VCB() throws {
        let barcode = AAMVATestBarcode.make(
            issuer: "636014",
            issueDate: "08052025",
            jurisdiction: "CA",
            encodedVCB: "not.valid.base64"
        )

        let inspection = try CADMVVerifier.inspectForSelfTest(rawPDF417: barcode)

        XCTAssertTrue(inspection.issuerAccepted)
        XCTAssertFalse(inspection.vcbRequired)
        XCTAssertTrue(inspection.vcbPresent)
        XCTAssertNil(inspection.decodedVCBByteCount)
        XCTAssertFalse(inspection.uatCredentialShapeValid)
        XCTAssertFalse(inspection.productionCredentialShapeValid)
        XCTAssertNil(inspection.opticalDataHashHex)
        XCTAssertNil(inspection.verifyDataHex)
        XCTAssertNil(inspection.vcbProofCanonicalNQuads)
        XCTAssertNil(inspection.vcbDocumentCanonicalNQuads)
    }

    func testUnsupportedCBORReportsReason() async {
        let barcode = AAMVATestBarcode.make(
            issuer: "636014",
            issueDate: "08052025",
            jurisdiction: "CA",
            encodedVCB: "AQIDBA"
        )

        let result = await CADMVVerifier.verify(rawPDF417: barcode)

        XCTAssert(result.status == .failed)
        XCTAssert(result.failureReason == .vcbCBORUnsupported)
    }

    func testInspectionPreservesDecodedByteCountForUnsupportedCBORVCB() throws {
        let barcode = AAMVATestBarcode.make(
            issuer: "636014",
            issueDate: "08052025",
            jurisdiction: "CA",
            encodedVCB: "AQIDBA"
        )

        let inspection = try CADMVVerifier.inspectForSelfTest(rawPDF417: barcode)

        XCTAssertTrue(inspection.issuerAccepted)
        XCTAssertFalse(inspection.vcbRequired)
        XCTAssertTrue(inspection.vcbPresent)
        XCTAssertEqual(inspection.decodedVCBByteCount, 4)
        XCTAssertFalse(inspection.uatCredentialShapeValid)
        XCTAssertFalse(inspection.productionCredentialShapeValid)
        XCTAssertNil(inspection.opticalDataHashHex)
        XCTAssertNil(inspection.verifyDataHex)
        XCTAssertNil(inspection.vcbProofCanonicalNQuads)
        XCTAssertNil(inspection.vcbDocumentCanonicalNQuads)
    }

    func testVerifierReportsDIDResolutionFailureWhenDMVHostCannotResolve() async throws {
        let barcode = AAMVATestBarcode.make(
            issuer: "636014",
            issueDate: "09292025",
            jurisdiction: "CA",
            encodedVCB: Base64URL.encode(CBORFixture.credential())
        )

        try await withTestNetworkHandler({ _ in
            throw URLError(.cannotFindHost)
        }) {
            let result = await CADMVVerifier.verify(
                rawPDF417: barcode,
                options: CADMVVerificationOptions(mode: .uat)
            )

            XCTAssertEqual(result.status, .failed)
            XCTAssertEqual(result.failureReason, .didResolutionFailed)
        }
    }

    func testNetworkTimeoutNormalizerFallsBackForInvalidValues() {
        XCTAssertEqual(CADMVNetworkSession.normalizedTimeout(Double.nan), 10)
        XCTAssertEqual(CADMVNetworkSession.normalizedTimeout(Double.infinity), 10)
        XCTAssertEqual(CADMVNetworkSession.normalizedTimeout(-1), 10)
        XCTAssertEqual(CADMVNetworkSession.normalizedTimeout(0), 10)
        XCTAssertEqual(CADMVNetworkSession.normalizedTimeout(0.1), 0.1)
    }

    func testAamvaParserReadsSubfilesSequentiallyLikeReferenceDecoder() throws {
        let barcode = AAMVATestBarcode.make(
            descriptorOffsetDelta: 7,
            issuer: "636014",
            issueDate: "09282025",
            jurisdiction: "CA",
            encodedVCB: nil
        )

        let document = try AAMVADocumentParser().parse(rawPDF417: barcode)

        XCTAssert(document.issuerIdentificationNumber == "636014")
        XCTAssert(document.primaryIdentitySubfile?.fields["DBD"] == "09282025")
    }

    func testAamvaParserAcceptsIDPrimarySubfile() throws {
        let barcode = AAMVATestBarcode.make(
            identitySubfileDesignator: "ID",
            issuer: "636014",
            issueDate: "09292025",
            jurisdiction: "CA",
            encodedVCB: nil
        )

        let document = try AAMVADocumentParser().parse(rawPDF417: barcode)

        XCTAssertEqual(document.primaryIdentitySubfile?.designator, "ID")
        XCTAssertEqual(document.primaryIdentitySubfile?.fields["DAQ"], "SYNTHETIC-ID")
        XCTAssertTrue(document.isCaliforniaDMVDocument)
        XCTAssertTrue(document.requiresCaliforniaVCB)
    }

    func testVerifierRequiresVCBForIDPrimarySubfileAfterRequirementDate() async {
        let barcode = AAMVATestBarcode.make(
            identitySubfileDesignator: "ID",
            issuer: "636014",
            issueDate: "09292025",
            jurisdiction: "CA",
            encodedVCB: nil
        )

        let result = await CADMVVerifier.verify(rawPDF417: barcode)

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failureReason, .vcbMissing(required: true))
    }

    func testProtectedDocumentUsesIDPrimarySubfileFields() throws {
        let barcode = AAMVATestBarcode.make(
            identitySubfileDesignator: "ID",
            issuer: "636014",
            issueDate: "09292025",
            jurisdiction: "CA",
            encodedVCB: nil
        )
        let document = try AAMVADocumentParser().parse(rawPDF417: barcode)

        let protectedFields = try AAMVACanonicalizer.protectedDocument(
            from: document,
            componentIndex: "u____"
        )

        XCTAssertEqual(protectedFields["DAQ"], "SYNTHETIC-ID")
        XCTAssertEqual(protectedFields["DBD"], "09292025")
        XCTAssertEqual(protectedFields["DAJ"], "CA")
    }

    func testAamvaParserToleratesMultibyteScannerPreamble() throws {
        let barcode = AAMVATestBarcode.make(
            prefix: "é@\n\u{1e}\rANSI ",
            issuer: "636014",
            issueDate: "09282025",
            jurisdiction: "CA",
            encodedVCB: nil
        )

        let document = try AAMVADocumentParser().parse(rawPDF417: barcode)

        XCTAssert(document.issuerIdentificationNumber == "636014")
        XCTAssert(document.primaryIdentitySubfile?.fields["DBD"] == "09282025")
    }

    func testAamvaParserToleratesStrippedANSIHeaderPreamble() throws {
        let barcode = AAMVATestBarcode.make(
            prefix: "ANSI ",
            issuer: "636014",
            issueDate: "09282025",
            jurisdiction: "CA",
            encodedVCB: nil
        )

        let document = try AAMVADocumentParser().parse(rawPDF417: barcode)

        XCTAssert(document.issuerIdentificationNumber == "636014")
        XCTAssert(document.primaryIdentitySubfile?.fields["DBD"] == "09282025")
        XCTAssert(document.primaryIdentitySubfile?.fields["DAJ"] == "CA")
    }

    func testAamvaParserInfersSeparatorsWhenPreambleIsStripped() throws {
        let barcode = AAMVATestBarcode.make(
            prefix: "ANSI ",
            elementSeparator: "\u{1d}",
            issuer: "636014",
            issueDate: "09282025",
            jurisdiction: "CA",
            encodedVCB: nil
        )

        let document = try AAMVADocumentParser().parse(rawPDF417: barcode)

        XCTAssert(document.issuerIdentificationNumber == "636014")
        XCTAssert(document.primaryIdentitySubfile?.fields["DBD"] == "09282025")
        XCTAssert(document.primaryIdentitySubfile?.fields["DAJ"] == "CA")
    }

    func testAamvaParserInfersUnitSeparatorWhenPreambleIsStripped() throws {
        let barcode = AAMVATestBarcode.make(
            prefix: "ANSI ",
            elementSeparator: "\u{1f}",
            issuer: "636014",
            issueDate: "09282025",
            jurisdiction: "CA",
            encodedVCB: nil
        )

        let document = try AAMVADocumentParser().parse(rawPDF417: barcode)

        XCTAssert(document.issuerIdentificationNumber == "636014")
        XCTAssert(document.primaryIdentitySubfile?.fields["DBD"] == "09282025")
        XCTAssert(document.primaryIdentitySubfile?.fields["DAJ"] == "CA")
    }

    func testAamvaParserToleratesTrimmedPartialHeaderPreamble() throws {
        let scannerPayload = AAMVATestBarcode.make(
            prefix: "\n\u{1e}\rANSI ",
            issuer: "636014",
            issueDate: "09282025",
            jurisdiction: "CA",
            encodedVCB: nil
        )
        let trimmedPayload = scannerPayload.trimmingCharacters(in: .whitespacesAndNewlines)

        let document = try AAMVADocumentParser().parse(rawPDF417: trimmedPayload)

        XCTAssert(document.issuerIdentificationNumber == "636014")
        XCTAssert(document.primaryIdentitySubfile?.fields["DBD"] == "09282025")
        XCTAssert(document.primaryIdentitySubfile?.fields["DAJ"] == "CA")
    }

    func testVerifierToleratesTrimmedFinalSegmentTerminator() async {
        let scannerPayload = AAMVATestBarcode.make(
            issuer: "636014",
            issueDate: "09282025",
            jurisdiction: "CA",
            encodedVCB: nil
        )
        let trimmedPayload = scannerPayload.trimmingCharacters(in: .whitespacesAndNewlines)

        let result = await CADMVVerifier.verify(rawPDF417: trimmedPayload)

        XCTAssert(result.status == .notPresent)
        XCTAssert(result.failureReason == .vcbMissing(required: false))
    }

    func testParserUsesDeclaredElementSeparator() throws {
        let barcode = AAMVATestBarcode.make(
            elementSeparator: "\u{1d}",
            issuer: "636014",
            issueDate: "09282025",
            jurisdiction: "CA",
            encodedVCB: nil
        )

        let document = try AAMVADocumentParser().parse(rawPDF417: barcode)

        XCTAssert(document.issuerIdentificationNumber == "636014")
        XCTAssert(document.primaryIdentitySubfile?.fields["DBD"] == "09282025")
        XCTAssert(document.primaryIdentitySubfile?.fields["DAJ"] == "CA")
    }

    func testParserNormalizesEscapedControlCharacters() async {
        let barcode = AAMVATestBarcode.make(
            issuer: "636014",
            issueDate: "09282025",
            jurisdiction: "CA",
            encodedVCB: nil
        )
        let escaped = barcode
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\u{1e}", with: "\\u001e")

        let result = await CADMVVerifier.verify(rawPDF417: escaped)

        XCTAssert(result.status == .notPresent)
        XCTAssert(result.failureReason == .vcbMissing(required: false))
    }

    func testParserNormalizesEscapedGroupSeparators() async {
        let barcode = AAMVATestBarcode.make(
            elementSeparator: "\u{1d}",
            issuer: "636014",
            issueDate: "09282025",
            jurisdiction: "CA",
            encodedVCB: nil
        )
        let escaped = barcode
            .replacingOccurrences(of: "\u{1d}", with: "\\u001d")
            .replacingOccurrences(of: "\u{1e}", with: "\\u001e")
            .replacingOccurrences(of: "\r", with: "\\u000d")

        let result = await CADMVVerifier.verify(rawPDF417: escaped)

        XCTAssert(result.status == .notPresent)
        XCTAssert(result.failureReason == .vcbMissing(required: false))
    }

    func testProtectedComponentIndexDecodesAnyThreeByteBitmap() throws {
        let credential = try DMVVCBDecoder.decode(
            CBORFixture.credential(protectedComponentIndexBytes: Data([0x75, 0x01, 0x02, 0x03]))
        )

        XCTAssert(credential.credentialSubject.protectedComponentIndex == "uAQID")
    }

    func testProtectedComponentIndexAcceptsReferenceNumericForm() throws {
        let credential = try DMVVCBDecoder.decode(
            CBORFixture.credential(numericProtectedComponentIndex: 0x010203)
        )

        XCTAssert(credential.credentialSubject.protectedComponentIndex == "uAQID")
    }

    func testProtectedComponentIndexRejectsWrongMultibasePrefix() throws {
        XCTAssertThrowsError(try DMVVCBDecoder.decode(
            CBORFixture.credential(protectedComponentIndexBytes: Data([0x7a, 0x01, 0x02, 0x03]))
        )) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }
    }

    func testDecoderAcceptsExpandedTextValuesFromCBORLD() throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.credential(textEncoded: true))

        XCTAssert(credential.issuer == "did:web:uat-credentials.dmv.ca.gov")
        XCTAssertNil(credential.validFrom)
        XCTAssertNil(credential.validUntil)
        XCTAssertNil(credential.proof.created)
        XCTAssertNil(credential.proof.expires)
        XCTAssert(credential.credentialSubject.protectedComponentIndex == "uAQID")
        XCTAssert(credential.proof.proofValue == "zLdp")
        XCTAssert(credential.proof.verificationMethod == "did:web:uat-credentials.dmv.ca.gov#vm-vcb-1")
    }

    func testDecoderAndValidatorAcceptBase64URLProofValueFromReferenceDataIntegrity() throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.credential(
            textEncoded: true,
            proofValue: "uAQIDBA"
        ))

        XCTAssertEqual(credential.proof.proofValue, "uAQIDBA")
        XCTAssertNoThrow(try DMVCredentialValidator.validate(credential, mode: .uat))
    }

    func testDecoderAcceptsReferenceNoStatusCompressedProofKeys() throws {
        let credential = try DMVVCBDecoder.decode(
            CBORFixture.noStatusCredentialWithReferenceProofKeys(
                proofCreated: "2026-01-01T00:00:00Z",
                proofExpires: "2026-02-01T00:00:00Z"
            )
        )

        XCTAssertNil(credential.credentialStatus)
        XCTAssertEqual(credential.proof.created, "2026-01-01T00:00:00Z")
        XCTAssertEqual(credential.proof.expires, "2026-02-01T00:00:00Z")
        XCTAssertEqual(credential.proof.cryptosuite, "ecdsa-xi-2023")
        XCTAssertEqual(credential.proof.proofPurpose, "assertionMethod")
        XCTAssertEqual(credential.proof.proofValue, "zLdp")
        XCTAssertEqual(credential.proof.verificationMethod, "did:web:uat-credentials.dmv.ca.gov#vm-vcb-1")
    }

    func testDecoderPreservesTextProofValuesForSignatureVerifierPolicy() throws {
        for proofValue in ["z0", "u***"] {
            let credential = try DMVVCBDecoder.decode(CBORFixture.credential(
                textEncoded: true,
                proofValue: proofValue
            ))

            XCTAssertEqual(credential.proof.proofValue, proofValue)
            XCTAssertNoThrow(try DMVCredentialValidator.validate(credential, mode: .uat))
        }
    }

    func testDecoderPreservesCompressedProofCreated() throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.credential(proofCreated: "2026-01-01T00:00:00Z"))

        XCTAssertEqual(credential.proof.created, "2026-01-01T00:00:00Z")
    }

    func testDecoderPreservesCompressedProofExpires() throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.credential(proofExpires: "2027-01-01T00:00:00Z"))

        XCTAssertEqual(credential.proof.expires, "2027-01-01T00:00:00Z")
    }

    func testDecoderPreservesCompressedCredentialValidityDates() throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.credential(
            validFrom: "2026-01-01T00:00:00Z",
            validUntil: "2030-01-01T00:00:00Z"
        ))

        XCTAssertEqual(credential.validFrom, "2026-01-01T00:00:00Z")
        XCTAssertEqual(credential.validUntil, "2030-01-01T00:00:00Z")
    }

    func testDecoderPreservesExpandedCredentialValidityDates() throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.uncompressedCredential(
            validFrom: "2026-01-01T00:00:00Z",
            validUntil: "2030-01-01T00:00:00Z"
        ))

        XCTAssertEqual(credential.validFrom, "2026-01-01T00:00:00Z")
        XCTAssertEqual(credential.validUntil, "2030-01-01T00:00:00Z")
    }

    func testDecoderPreservesExpandedProofCreated() throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.uncompressedCredential(proofCreated: "2026-01-01T00:00:00Z"))

        XCTAssertEqual(credential.proof.created, "2026-01-01T00:00:00Z")
    }

    func testDecoderPreservesExpandedProofExpires() throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.uncompressedCredential(proofExpires: "2027-01-01T00:00:00Z"))

        XCTAssertEqual(credential.proof.expires, "2027-01-01T00:00:00Z")
    }

    func testCredentialExpirationBoundary() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-06-30T12:00:00Z"))

        XCTAssertFalse(try CADMVVerifier.isExpiredForSelfTest("2026-06-30T12:00:01Z", now: now))
        XCTAssertTrue(try CADMVVerifier.isExpiredForSelfTest("2026-06-30T12:00:00Z", now: now))
        XCTAssertTrue(try CADMVVerifier.isExpiredForSelfTest("2026-06-30T11:59:59Z", now: now))
        XCTAssertFalse(try CADMVVerifier.isExpiredForSelfTest("2026-06-30T12:00:00.001Z", now: now))
        XCTAssertTrue(try CADMVVerifier.isCredentialExpiredForSelfTest(
            validUntil: "2026-06-30T12:00:01Z",
            proofExpires: "2026-06-30T11:59:59Z",
            now: now
        ))
        XCTAssertThrowsError(try CADMVVerifier.isExpiredForSelfTest("not-a-date", now: now))
    }

    func testDecoderRejectsUnsafeProofCreated() throws {
        XCTAssertThrowsError(try DMVVCBDecoder.decode(
            CBORFixture.credential(proofCreated: "2026-01-01T00:00:00Z\" .\n_:x")
        )) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }
    }

    func testDecoderRejectsUnknownCredentialKey() throws {
        XCTAssertThrowsError(try DMVVCBDecoder.decode(
            CBORFixture.credential(includeUnknownCredentialKey: true)
        )) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }
    }

    func testDecoderRejectsUnknownProofKey() throws {
        XCTAssertThrowsError(try DMVVCBDecoder.decode(
            CBORFixture.credential(includeUnknownProofKey: true)
        )) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }
    }

    func testDecoderRejectsCompressedCredentialTextAliasCollision() throws {
        XCTAssertThrowsError(try DMVVCBDecoder.decode(CBORFixture.credential(
            validUntil: "2030-01-01T00:00:00Z",
            includeCollidingTextCredentialKey: true
        ))) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }
    }

    func testDecoderRejectsCompressedProofTextAliasCollision() throws {
        XCTAssertThrowsError(try DMVVCBDecoder.decode(CBORFixture.credential(
            proofCreated: "2026-01-01T00:00:00Z",
            includeCollidingTextProofKey: true
        ))) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }
    }

    func testDecoderPreservesTextEncodedUnknownCredentialKeyForCanonicalization() throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.credential(
            textEncoded: true,
            includeUnknownCredentialKey: true
        ))

        XCTAssertEqual(
            credential.additionalProperties["unknownCredentialOption"],
            .string("unsupported")
        )
        XCTAssertThrowsError(try DMVCredentialValidator.validate(credential, mode: .uat)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }
        XCTAssertThrowsError(try VCBJSONLDRDFExpander.canonicalNQuads(credential)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }
    }

    func testDecoderPreservesTextEncodedUnknownProofKeyForCanonicalization() throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.credential(
            textEncoded: true,
            includeUnknownProofKey: true
        ))
        let proofDocument = DataIntegrityProofCanonicalizer.jsonLDDocument(
            contexts: credential.context,
            type: credential.proof.type,
            created: credential.proof.created,
            expires: credential.proof.expires,
            cryptosuite: credential.proof.cryptosuite,
            proofPurpose: credential.proof.proofPurpose,
            verificationMethod: credential.proof.verificationMethod,
            additionalProperties: credential.proof.additionalProperties
        )

        XCTAssertEqual(
            credential.proof.additionalProperties["unknownProofOption"],
            .string("unsupported")
        )
        XCTAssertEqual(proofDocument["unknownProofOption"], .string("unsupported"))
        XCTAssertThrowsError(try DMVCredentialValidator.validate(credential, mode: .uat)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }
        XCTAssertThrowsError(try SupportedProofJSONLDRDFConverter.quads(from: proofDocument)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }
    }

    func testDecoderAcceptsCompressedHTTPURLArrayValuesFromReferenceCBORLD() throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.credential(statusBaseURLArrayEncoded: true))

        XCTAssert(credential.credentialStatus?.terseStatusListBaseURL == "https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists")
    }

    func testStatusListLocationUsesTerseBitstringFormulaFromTechnicalGuide() throws {
        let status = DMVVerifiableCredential.CredentialStatus(
            type: "TerseBitstringStatusListEntry",
            terseStatusListBaseURL: "https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists",
            terseStatusListIndex: 3_866_524_935
        )

        let location = try XCTUnwrap(StatusListChecker.statusListLocation(for: status))

        XCTAssertEqual(
            location.url.absoluteString,
            "https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists/revocation/57"
        )
        XCTAssertEqual(location.listIndex, 57)
        XCTAssertEqual(location.statusListIndex, 41_319_687)
    }

    func testStatusBitReaderCoversByteBoundariesAndOutOfRange() {
        let bytes = Data([
            0b1000_0001,
            0b1000_0000,
            0,
            0,
            0,
            0,
            0,
            0b0000_0001,
            0b1000_0001
        ])

        XCTAssertEqual(CADMVVerifier.statusBitForSelfTest(uncompressedBytes: bytes, index: 0), true)
        XCTAssertEqual(CADMVVerifier.statusBitForSelfTest(uncompressedBytes: bytes, index: 7), true)
        XCTAssertEqual(CADMVVerifier.statusBitForSelfTest(uncompressedBytes: bytes, index: 8), true)
        XCTAssertEqual(CADMVVerifier.statusBitForSelfTest(uncompressedBytes: bytes, index: 63), true)
        XCTAssertEqual(CADMVVerifier.statusBitForSelfTest(uncompressedBytes: bytes, index: 64), true)
        XCTAssertEqual(CADMVVerifier.statusBitForSelfTest(uncompressedBytes: bytes, index: 71), true)
        XCTAssertEqual(CADMVVerifier.statusBitForSelfTest(uncompressedBytes: bytes, index: 72), nil)
    }

    func testDecoderAcceptsCredentialWithoutStatusBlock() throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.credential(includeStatus: false))

        XCTAssert(credential.credentialStatus == nil)
        XCTAssert(credential.proof.verificationMethod == "did:web:uat-credentials.dmv.ca.gov#vm-vcb-1")
    }

    func testValidatorAllowsMissingStatusForStatusChecker() throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.credential(includeStatus: false))

        XCTAssertNoThrow(try DMVCredentialValidator.validate(credential, mode: .uat))
    }

    func testDecoderRejectsExtraCredentialTypeIgnoredByNativeCanonicalizer() throws {
        XCTAssertThrowsError(try DMVVCBDecoder.decode(
            CBORFixture.credential(extraCredentialTypes: ["IgnoredByNativeCanonicalizer"])
        )) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }
    }

    func testValidatorRejectsDuplicateCredentialTypeIgnoredByNativeCanonicalizer() throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.credential(extraCredentialTypes: ["VerifiableCredential"]))

        XCTAssertThrowsError(try DMVCredentialValidator.validate(credential, mode: .uat)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }
    }

    func testValidatorRejectsStatusListPrefixOnlyMatch() throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.credential(
            textEncoded: true,
            statusBaseURLOverride: "https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists-extra"
        ))

        XCTAssertThrowsError(try DMVCredentialValidator.validate(credential, mode: .uat)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }
    }

    func testCBORRejectsDuplicateMapKeys() throws {
        let duplicateKeyCBOR = Data([
            0xd9, 0x05, 0x00,
            0xa2,
            0x61, 0x78, 0x01,
            0x61, 0x78, 0x02
        ])

        XCTAssertThrowsError(try DMVVCBDecoder.decode(duplicateKeyCBOR)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .malformedCBOR)
        }
    }

    func testCBORRejectsArrayCountLargerThanRemainingPayload() throws {
        let oversizedArray = Data([
            0x9b,
            0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
        ])

        XCTAssertThrowsError(try CBORReader.decode(oversizedArray)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .malformedCBOR)
        }
    }

    func testCBORRejectsByteStringLengthLargerThanRepresentablePayload() throws {
        let oversizedByteString = Data([
            0x5b,
            0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
        ])

        XCTAssertThrowsError(try CBORReader.decode(oversizedByteString)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .malformedCBOR)
        }
    }

    func testCBORRejectsTextStringLengthLargerThanRepresentablePayload() throws {
        let oversizedTextString = Data([
            0x7b,
            0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
        ])

        XCTAssertThrowsError(try CBORReader.decode(oversizedTextString)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .malformedCBOR)
        }
    }

    func testCBORRejectsMapCountLargerThanRemainingPayload() throws {
        let oversizedMap = Data([
            0xbb,
            0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
        ])

        XCTAssertThrowsError(try CBORReader.decode(oversizedMap)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .malformedCBOR)
        }
    }

    func testCBORRejectsUnsupportedIndefiniteLengthItems() throws {
        let unsupportedIndefiniteValues: [Data] = [
            Data([0x5f]), // byte string
            Data([0x7f]), // text string
            Data([0x9f]), // array
            Data([0xbf]), // map
            Data([0xff])  // break code
        ]

        for value in unsupportedIndefiniteValues {
            XCTAssertThrowsError(try CBORReader.decode(value)) { error in
                XCTAssertEqual(error as? CADMVInternalError, .unsupportedCBOR)
            }
        }
    }

    func testCBORRejectsUnsupportedSimpleAndFloatValues() throws {
        let unsupportedValues: [Data] = [
            Data([0xf8, 0x00]),
            Data([0xf9, 0x00, 0x00]),
            Data([0xfa, 0x00, 0x00, 0x00, 0x00]),
            Data([0xfb, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        ]

        for value in unsupportedValues {
            XCTAssertThrowsError(try CBORReader.decode(value)) { error in
                XCTAssertEqual(error as? CADMVInternalError, .unsupportedCBOR)
            }
        }
    }

    func testCBORRejectsNegativeIntegerBelowInt64Range() throws {
        let negativeBelowInt64Range = Data([
            0x3b,
            0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        ])

        XCTAssertThrowsError(try CBORReader.decode(negativeBelowInt64Range)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .malformedCBOR)
        }
    }

    func testCBORRejectsTrailingBytesAfterTopLevelValue() throws {
        let topLevelValueWithTrailingBytes = Data([0x00, 0x00])

        XCTAssertThrowsError(try CBORReader.decode(topLevelValueWithTrailingBytes)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .malformedCBOR)
        }
    }

    func testDecoderAcceptsUncompressedCBORLDProfile() throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.uncompressedCredential())

        XCTAssertEqual(credential.context, [
            "https://www.w3.org/ns/credentials/v2",
            "https://w3id.org/vc-barcodes/v1"
        ])
        XCTAssert(credential.type.contains("OpticalBarcodeCredential"))
        XCTAssert(credential.credentialSubject.protectedComponentIndex == "uAQID")
        XCTAssert(credential.credentialStatus?.terseStatusListIndex == 1)
    }

    func testDecoderAcceptsLegacyUncompressedCBORLDProfile() throws {
        for tag in [UInt64(1_280), UInt64(1_536)] {
            let credential = try DMVVCBDecoder.decode(CBORFixture.uncompressedCredential(tag: tag))

            XCTAssert(credential.issuer == "did:web:uat-credentials.dmv.ca.gov")
            XCTAssert(credential.credentialSubject.protectedComponentIndex == "uAQID")
            XCTAssert(credential.proof.verificationMethod == "did:web:uat-credentials.dmv.ca.gov#vm-vcb-1")
        }
    }

    func testDecoderAcceptsLegacyCompressedCBORLDProfile() throws {
        for data in [
            CBORFixture.legacySingletonCompressedCredential(),
            CBORFixture.legacyRangeCompressedCredential()
        ] {
            let credential = try DMVVCBDecoder.decode(data)

            XCTAssert(credential.issuer == "did:web:uat-credentials.dmv.ca.gov")
            XCTAssert(credential.credentialSubject.protectedComponentIndex == "uAQID")
            XCTAssert(credential.credentialStatus?.terseStatusListIndex == 1)
        }
    }

    func testDIDResolverMapsHostLookupFailureToResolutionFailure() async throws {
        try await withTestNetworkHandler({ _ in
            throw URLError(.cannotFindHost)
        }) {
            await assertDIDResolutionFailure()
        }
    }

    func testDIDResolverMapsTimeoutCancellationToResolutionFailure() async throws {
        try await withTestNetworkHandler({ _ in
            throw CancellationError()
        }) {
            await assertDIDResolutionFailure()
        }
    }

    func testDIDResolverMapsNonHTTPResponseToResolutionFailure() async throws {
        try await withTestNetworkHandler({ request in
            let url = try XCTUnwrap(request.url)
            return (Data(), URLResponse(
                url: url,
                mimeType: "application/json",
                expectedContentLength: 0,
                textEncodingName: "utf-8"
            ))
        }) {
            await assertDIDResolutionFailure()
        }
    }

    func testDIDResolverMapsMalformedJSONToResolutionFailure() async throws {
        try await withTestNetworkHandler({ request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            ))
            return (Data("{".utf8), response)
        }) {
            await assertDIDResolutionFailure()
        }
    }

    func testDIDResolverNormalizesInvalidTimeoutBeforeRequest() async throws {
        try await withTestNetworkHandler({ request in
            XCTAssertEqual(request.timeoutInterval, 10)
            throw URLError(.timedOut)
        }) {
            await assertDIDResolutionFailure(timeoutSeconds: Double.nan)
        }
    }

    func testStatusListCheckerNormalizesInvalidTimeoutBeforeRequest() async throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.credential())

        try await withTestNetworkHandler({ request in
            XCTAssertEqual(request.timeoutInterval, 10)
            XCTAssertEqual(request.url?.host, "api.uat-credentials.dmv.ca.gov")
            throw URLError(.timedOut)
        }) {
            let result = await StatusListChecker.check(
                credential: credential,
                mode: .uat,
                timeoutSeconds: Double.infinity
            )

            XCTAssertEqual(result, .unavailable)
        }
    }

    func testStatusListCheckerMapsStatusTransportFailureToUnavailable() async throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.credential())

        try await withTestNetworkHandler({ request in
            XCTAssertEqual(request.url?.host, "api.uat-credentials.dmv.ca.gov")
            throw URLError(.cannotConnectToHost)
        }) {
            let result = await StatusListChecker.check(
                credential: credential,
                mode: .uat,
                timeoutSeconds: 0.1
            )

            XCTAssertEqual(result, .unavailable)
        }
    }

    func testStatusListCheckerMapsStatusHTTPFailureToUnavailable() async throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.credential())

        for statusCode in [302, 404, 500] {
            try await withTestNetworkHandler({ request in
                let url = try XCTUnwrap(request.url)
                XCTAssertEqual(url.host, "api.uat-credentials.dmv.ca.gov")
                let headers = statusCode == 302
                    ? ["Location": "https://status.uat-credentials.dmv.ca.gov/list"]
                    : nil
                let response = try XCTUnwrap(HTTPURLResponse(
                    url: url,
                    statusCode: statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: headers
                ))
                return (Data(), response)
            }) {
                let result = await StatusListChecker.check(
                    credential: credential,
                    mode: .uat,
                    timeoutSeconds: 0.1
                )

                XCTAssertEqual(result, .unavailable)
            }
        }
    }

    func testStatusListCheckerMapsMalformedStatusCredentialToUnavailable() async throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.credential())

        try await withTestNetworkHandler({ request in
            let url = try XCTUnwrap(request.url)
            XCTAssertEqual(url.host, "api.uat-credentials.dmv.ca.gov")
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            ))
            return (Data("{".utf8), response)
        }) {
            let result = await StatusListChecker.check(
                credential: credential,
                mode: .uat,
                timeoutSeconds: 0.1
            )

            XCTAssertEqual(result, .unavailable)
        }
    }

    func testStatusListCheckerMapsMalformedDIDDocumentToUnavailable() async throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.credential())

        try await withTestNetworkHandler({ request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            ))

            if url.host == "api.uat-credentials.dmv.ca.gov" {
                return (Self.syntheticStatusListCredentialJSON, response)
            }
            XCTAssertEqual(url.host, "uat-credentials.dmv.ca.gov")
            return (Data("{".utf8), response)
        }) {
            let result = await StatusListChecker.check(
                credential: credential,
                mode: .uat,
                timeoutSeconds: 0.1
            )

            XCTAssertEqual(result, .unavailable)
        }
    }

    func testStatusListCheckerMapsUnsupportedDIDKeyToUnavailable() async throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.credential())

        try await withTestNetworkHandler({ request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            ))

            if url.host == "api.uat-credentials.dmv.ca.gov" {
                return (Self.syntheticStatusListCredentialJSON, response)
            }
            XCTAssertEqual(url.host, "uat-credentials.dmv.ca.gov")
            return (Self.syntheticUnsupportedKeyDIDDocumentJSON, response)
        }) {
            let result = await StatusListChecker.check(
                credential: credential,
                mode: .uat,
                timeoutSeconds: 0.1
            )

            XCTAssertEqual(result, .unavailable)
        }
    }

    private func assertDIDResolutionFailure(
        timeoutSeconds: Double = 0.1,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await DIDWebResolver.resolveVerificationMethod(
                id: "did:web:uat-credentials.dmv.ca.gov#vm-vcb-1",
                mode: .uat,
                timeoutSeconds: timeoutSeconds
            )
            XCTFail("DID resolution unexpectedly succeeded", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? CADMVInternalError, .didResolutionFailed, file: file, line: line)
        }
    }

    private func withTestNetworkHandler(
        _ handler: @escaping CADMVNetworkSession.DataHandler,
        operation: () async throws -> Void
    ) async throws {
        await CADMVNetworkSession.setTestHandler(handler)
        do {
            try await operation()
            await CADMVNetworkSession.setTestHandler(nil)
        } catch {
            await CADMVNetworkSession.setTestHandler(nil)
            throw error
        }
    }

    private static let syntheticStatusListCredentialJSON = Data("""
    {
      "@context": [
        "https://www.w3.org/ns/credentials/v2"
      ],
      "id": "https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists/revocation/0",
      "type": [
        "VerifiableCredential",
        "BitstringStatusListCredential"
      ],
      "credentialSubject": {
        "id": "https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists/revocation/0#list",
        "type": "BitstringStatusList",
        "encodedList": "uH4sIAAAAAAAAA2NhAAD717UlAgAAAA",
        "statusPurpose": "revocation"
      },
      "issuer": "did:web:uat-credentials.dmv.ca.gov",
      "validFrom": "2026-01-01T00:00:00Z",
      "proof": {
        "type": "DataIntegrityProof",
        "created": "2026-01-01T00:00:00Z",
        "verificationMethod": "did:web:uat-credentials.dmv.ca.gov#vm-vcb-1",
        "cryptosuite": "ecdsa-rdfc-2019",
        "proofPurpose": "assertionMethod",
        "proofValue": "z3KqtjbQJZNSkeufgNj2oVRg9k9fZVoP5SroahjSNghZbU9osz8sL2J4beC9gWoNTkjDn6W9FBJRirMnNt4HuXvcw"
      }
    }
    """.utf8)

    private static let syntheticUnsupportedKeyDIDDocumentJSON = Data("""
    {
      "id": "did:web:uat-credentials.dmv.ca.gov",
      "assertionMethod": [
        {
          "id": "did:web:uat-credentials.dmv.ca.gov#vm-vcb-1",
          "controller": "did:web:uat-credentials.dmv.ca.gov",
          "type": "JsonWebKey2020",
          "publicKeyMultibase": "zDnaeVp3tjD8ipWSt42tBZJLCsDA9SrtYXGvLg5dL3qXtXDKP"
        }
      ]
    }
    """.utf8)
}

private enum AAMVATestBarcode {
    static func make(
        prefix: String = "@\n\u{1e}\rANSI ",
        elementSeparator: Character = "\n",
        recordSeparator: Character = "\u{1e}",
        segmentTerminator: Character = "\r",
        descriptorOffsetDelta: Int = 0,
        identitySubfileDesignator: String = "DL",
        issuer: String,
        issueDate: String,
        jurisdiction: String,
        encodedVCB: String?
    ) -> String {
        let prefix = prefix == "@\n\u{1e}\rANSI "
            ? "@\(elementSeparator)\(recordSeparator)\(segmentTerminator)ANSI "
            : prefix
        precondition(["DL", "ID"].contains(identitySubfileDesignator))
        let identitySubfile = [
            "\(identitySubfileDesignator)DAQSYNTHETIC-\(identitySubfileDesignator)",
            "DBD\(issueDate)",
            "DAJ\(jurisdiction)"
        ].joined(separator: String(elementSeparator)) + String(segmentTerminator)

        let zcSubfile: String
        if let encodedVCB {
            zcSubfile = [
                "ZCZCA",
                "ZCE\(encodedVCB)"
            ].joined(separator: String(elementSeparator)) + String(segmentTerminator)
        } else {
            zcSubfile = [
                "ZCZCA"
            ].joined(separator: String(elementSeparator)) + String(segmentTerminator)
        }

        let headerWithoutEntries = "\(prefix)\(issuer)100102"
        let entriesLength = 20
        let identityOffset = headerWithoutEntries.utf8.count + entriesLength + descriptorOffsetDelta
        let zcOffset = identityOffset + identitySubfile.utf8.count
        let entries = "\(identitySubfileDesignator)\(pad(identityOffset))\(pad(identitySubfile.utf8.count))ZC\(pad(zcOffset))\(pad(zcSubfile.utf8.count))"

        return headerWithoutEntries + entries + identitySubfile + zcSubfile
    }

    private static func pad(_ value: Int) -> String {
        String(format: "%04d", value)
    }
}

private enum CBORFixture {
    static func credential(
        protectedComponentIndexBytes: Data = Data([0x75, 0x01, 0x02, 0x03]),
        includeStatus: Bool = true,
        textEncoded: Bool = false,
        statusBaseURLArrayEncoded: Bool = false,
        statusBaseURLOverride: String? = nil,
        proofValue: String? = nil,
        extraCredentialTypes: [String] = [],
        validFrom: String? = nil,
        validUntil: String? = nil,
        proofCreated: String? = nil,
        proofExpires: String? = nil,
        includeUnknownCredentialKey: Bool = false,
        includeUnknownProofKey: Bool = false,
        includeCollidingTextCredentialKey: Bool = false,
        includeCollidingTextProofKey: Bool = false
    ) -> Data {
        credential(
            protectedComponentIndexValue: textEncoded
                ? text("uAQID")
                : byteString(protectedComponentIndexBytes),
            includeStatus: includeStatus,
            textEncoded: textEncoded,
            statusBaseURLArrayEncoded: statusBaseURLArrayEncoded,
            statusBaseURLOverride: statusBaseURLOverride,
            proofValue: proofValue,
            extraCredentialTypes: extraCredentialTypes,
            validFrom: validFrom,
            validUntil: validUntil,
            proofCreated: proofCreated,
            proofExpires: proofExpires,
            includeUnknownCredentialKey: includeUnknownCredentialKey,
            includeUnknownProofKey: includeUnknownProofKey,
            includeCollidingTextCredentialKey: includeCollidingTextCredentialKey,
            includeCollidingTextProofKey: includeCollidingTextProofKey
        )
    }

    static func credential(numericProtectedComponentIndex: UInt64) -> Data {
        credential(
            protectedComponentIndexValue: unsigned(numericProtectedComponentIndex),
            includeStatus: true,
            textEncoded: false
        )
    }

    static func legacySingletonCompressedCredential() -> Data {
        tagged(1_281, compressedCredentialMap())
    }

    static func legacyRangeCompressedCredential() -> Data {
        let idBytes = varint(31_000_000)
        return tagged(1_536 + UInt64(idBytes[0]), array([
            byteString(Data(idBytes.dropFirst())),
            compressedCredentialMap()
        ]))
    }

    static func noStatusCredentialWithReferenceProofKeys(
        proofCreated: String,
        proofExpires: String
    ) -> Data {
        tagged(51_997, array([
            unsigned(31_000_000),
            compressedCredentialMap(
                includeStatus: false,
                proofPairs: [
                    (unsigned(156), unsigned(108)),
                    (unsigned(198), unsigned(1_767_225_600)),
                    (unsigned(200), unsigned(1)),
                    (unsigned(204), text(proofExpires)),
                    (unsigned(210), unsigned(216)),
                    (unsigned(212), byteString(Data([0x7a, 0x01, 0x02, 0x03]))),
                    (unsigned(214), bytes([22]))
                ]
            )
        ]))
    }

    static func uncompressedCredential(
        tag: UInt64 = 51_997,
        validFrom: String? = nil,
        validUntil: String? = nil,
        proofCreated: String? = nil,
        proofExpires: String? = nil
    ) -> Data {
        var proofPairs = [
            (text("type"), text("DataIntegrityProof")),
            (text("cryptosuite"), text("ecdsa-xi-2023")),
            (text("proofPurpose"), text("assertionMethod")),
            (text("proofValue"), text("zLdp")),
            (text("verificationMethod"), text("did:web:uat-credentials.dmv.ca.gov#vm-vcb-1"))
        ]
        if let proofCreated {
            proofPairs.append((text("created"), text(proofCreated)))
        }
        if let proofExpires {
            proofPairs.append((text("expires"), text(proofExpires)))
        }

        var credentialPairs = [
            (text("@context"), array([
                text("https://www.w3.org/ns/credentials/v2"),
                text("https://w3id.org/vc-barcodes/v1")
            ])),
            (text("type"), array([
                text("VerifiableCredential"),
                text("OpticalBarcodeCredential")
            ])),
            (text("issuer"), text("did:web:uat-credentials.dmv.ca.gov")),
            (text("credentialSubject"), map([
                (text("type"), text("AamvaDriversLicenseScannableInformation")),
                (text("protectedComponentIndex"), text("uAQID"))
            ])),
            (text("credentialStatus"), map([
                (text("type"), text("TerseBitstringStatusListEntry")),
                (text("terseStatusListBaseUrl"), text("https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists")),
                (text("terseStatusListIndex"), unsigned(1))
            ])),
            (text("proof"), map(proofPairs))
        ]
        if let validFrom {
            credentialPairs.append((text("validFrom"), text(validFrom)))
        }
        if let validUntil {
            credentialPairs.append((text("validUntil"), text(validUntil)))
        }

        let credential = map(credentialPairs)

        guard tag == 51_997 else {
            return tagged(tag, credential)
        }

        return tagged(tag, array([
            unsigned(0),
            credential
        ]))
    }

    private static func credential(
        protectedComponentIndexValue: Data,
        includeStatus: Bool,
        textEncoded: Bool,
        statusBaseURLArrayEncoded: Bool = false,
        statusBaseURLOverride: String? = nil,
        proofValue: String? = nil,
        extraCredentialTypes: [String] = [],
        validFrom: String? = nil,
        validUntil: String? = nil,
        proofCreated: String? = nil,
        proofExpires: String? = nil,
        includeUnknownCredentialKey: Bool = false,
        includeUnknownProofKey: Bool = false,
        includeCollidingTextCredentialKey: Bool = false,
        includeCollidingTextProofKey: Bool = false
    ) -> Data {
        let payload = compressedCredentialMap(
            protectedComponentIndexValue: protectedComponentIndexValue,
            includeStatus: includeStatus,
            textEncoded: textEncoded,
            statusBaseURLArrayEncoded: statusBaseURLArrayEncoded,
            statusBaseURLOverride: statusBaseURLOverride,
            proofValue: proofValue,
            extraCredentialTypes: extraCredentialTypes,
            validFrom: validFrom,
            validUntil: validUntil,
            proofCreated: proofCreated,
            proofExpires: proofExpires,
            includeUnknownCredentialKey: includeUnknownCredentialKey,
            includeUnknownProofKey: includeUnknownProofKey,
            includeCollidingTextCredentialKey: includeCollidingTextCredentialKey,
            includeCollidingTextProofKey: includeCollidingTextProofKey
        )

        return tagged(51_997, array([
            unsigned(31_000_000),
            payload
        ]))
    }

    private static func compressedCredentialMap(
        protectedComponentIndexValue: Data = byteString(Data([0x75, 0x01, 0x02, 0x03])),
        includeStatus: Bool = true,
        textEncoded: Bool = false,
        statusBaseURLArrayEncoded: Bool = false,
        statusBaseURLOverride: String? = nil,
        proofValue: String? = nil,
        extraCredentialTypes: [String] = [],
        validFrom: String? = nil,
        validUntil: String? = nil,
        proofCreated: String? = nil,
        proofExpires: String? = nil,
        includeUnknownCredentialKey: Bool = false,
        includeUnknownProofKey: Bool = false,
        includeCollidingTextCredentialKey: Bool = false,
        includeCollidingTextProofKey: Bool = false,
        proofPairs overrideProofPairs: [(Data, Data)]? = nil
    ) -> Data {
        var proofPairs = overrideProofPairs ?? [
            (unsigned(156), textEncoded ? text("DataIntegrityProof") : unsigned(108)),
            (unsigned(204), textEncoded ? text("ecdsa-xi-2023") : unsigned(1)),
            (unsigned(214), textEncoded ? text("assertionMethod") : unsigned(220)),
            (unsigned(216), proofValue.map(text(_:)) ?? (textEncoded ? text("zLdp") : byteString(Data([0x7a, 0x01, 0x02, 0x03])))),
            (unsigned(218), textEncoded ? text("did:web:uat-credentials.dmv.ca.gov#vm-vcb-1") : bytes([22]))
        ]
        if let proofCreated {
            proofPairs.append((textEncoded ? text("created") : unsigned(202), text(proofCreated)))
        }
        if let proofExpires {
            proofPairs.append((textEncoded ? text("expires") : unsigned(208), text(proofExpires)))
        }
        if includeUnknownProofKey {
            proofPairs.append((textEncoded ? text("unknownProofOption") : unsigned(999), text("unsupported")))
        }
        if includeCollidingTextProofKey {
            proofPairs.append((text("created"), text("2026-02-01T00:00:00Z")))
        }

        var credentialTypeValues = textEncoded
            ? [text("VerifiableCredential"), text("OpticalBarcodeCredential")]
            : [unsigned(118), unsigned(164)]
        credentialTypeValues.append(contentsOf: extraCredentialTypes.map(text(_:)))

        var pairs: [(Data, Data)] = [
            (unsigned(1), array(textEncoded
                ? [text("https://www.w3.org/ns/credentials/v2"), text("https://w3id.org/vc-barcodes/v1")]
                : [unsigned(1), unsigned(2)])),
            (unsigned(157), array(credentialTypeValues)),
            (unsigned(180), textEncoded ? text("did:web:uat-credentials.dmv.ca.gov") : bytes([20])),
            (unsigned(176), map([
                (unsigned(156), textEncoded ? text("AamvaDriversLicenseScannableInformation") : unsigned(160)),
                (unsigned(168), protectedComponentIndexValue)
            ])),
            (unsigned(182), map(proofPairs))
        ]
        if includeStatus {
            pairs.append((unsigned(174), map([
                (unsigned(156), textEncoded ? text("TerseBitstringStatusListEntry") : unsigned(166)),
                (unsigned(196), statusBaseURLOverride.map(text(_:)) ?? statusBaseURLValue(
                    textEncoded: textEncoded,
                    arrayEncoded: statusBaseURLArrayEncoded
                )),
                (unsigned(198), unsigned(1))
            ])))
        }
        if let validFrom {
            pairs.append((textEncoded ? text("validFrom") : unsigned(192), text(validFrom)))
        }
        if let validUntil {
            pairs.append((textEncoded ? text("validUntil") : unsigned(194), text(validUntil)))
        }
        if includeUnknownCredentialKey {
            pairs.append((textEncoded ? text("unknownCredentialOption") : unsigned(999), text("unsupported")))
        }
        if includeCollidingTextCredentialKey {
            pairs.append((text("validUntil"), text("2031-01-01T00:00:00Z")))
        }

        return map(pairs)
    }

    private static func statusBaseURLValue(textEncoded: Bool, arrayEncoded: Bool) -> Data {
        if arrayEncoded {
            return array([
                unsigned(2),
                text("api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists")
            ])
        }
        return textEncoded
            ? text("https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists")
            : bytes([21])
    }

    private static func unsigned(_ value: UInt64) -> Data {
        encode(majorType: 0, value: value)
    }

    private static func bytes(_ values: [UInt8]) -> Data {
        byteString(Data(values))
    }

    private static func byteString(_ data: Data) -> Data {
        encode(majorType: 2, value: UInt64(data.count)) + data
    }

    private static func text(_ value: String) -> Data {
        let data = Data(value.utf8)
        return encode(majorType: 3, value: UInt64(data.count)) + data
    }

    private static func null() -> Data {
        Data([0xf6])
    }

    private static func varint(_ value: UInt64) -> [UInt8] {
        var value = value
        var bytes: [UInt8] = []
        repeat {
            var byte = UInt8(value & 0x7f)
            value >>= 7
            if value != 0 {
                byte |= 0x80
            }
            bytes.append(byte)
        } while value != 0
        return bytes
    }

    private static func array(_ values: [Data]) -> Data {
        values.reduce(encode(majorType: 4, value: UInt64(values.count)), +)
    }

    private static func map(_ pairs: [(Data, Data)]) -> Data {
        pairs.reduce(encode(majorType: 5, value: UInt64(pairs.count))) { partial, pair in
            partial + pair.0 + pair.1
        }
    }

    private static func tagged(_ tag: UInt64, _ value: Data) -> Data {
        encode(majorType: 6, value: tag) + value
    }

    private static func encode(majorType: UInt8, value: UInt64) -> Data {
        let prefix = majorType << 5
        switch value {
        case 0..<24:
            return Data([prefix | UInt8(value)])
        case 24...UInt64(UInt8.max):
            return Data([prefix | 24, UInt8(value)])
        case 256...UInt64(UInt16.max):
            return Data([prefix | 25, UInt8(value >> 8), UInt8(value & 0xff)])
        case 65_536...UInt64(UInt32.max):
            return Data([
                prefix | 26,
                UInt8((value >> 24) & 0xff),
                UInt8((value >> 16) & 0xff),
                UInt8((value >> 8) & 0xff),
                UInt8(value & 0xff)
            ])
        default:
            return Data([
                prefix | 27,
                UInt8((value >> 56) & 0xff),
                UInt8((value >> 48) & 0xff),
                UInt8((value >> 40) & 0xff),
                UInt8((value >> 32) & 0xff),
                UInt8((value >> 24) & 0xff),
                UInt8((value >> 16) & 0xff),
                UInt8((value >> 8) & 0xff),
                UInt8(value & 0xff)
            ])
        }
    }
}
