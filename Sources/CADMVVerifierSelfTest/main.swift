@_spi(Testing) import CADMVVerifier
import CADMVScanner
import Foundation

@main
enum CADMVVerifierSelfTest {
    static func main() async {
        await testMissingOptionalVCB()
        await testRequiredMissingVCB()
        await testRequireVCBOption()
        await testNonCaliforniaBarcode()
        await testIssueDateBoundaryMatrix()
        await testImpossibleIssueDateRequiresVCB()
        await testMalformedBase64VCBFails()
        await testMalformedCBORLDFails()
        await testMalformedBarcodeCorpus()
        await testMalformedBarcodeDescriptorCorpus()
        testBase64URLRejectsMalformedLengths()
        testBase58RejectsMalformedInput()
        try! testGzipOutputLimit()
        testBase58LeadingZeroRoundTrip()
        try! testStatusBitIndexing()
        try! testMalformedStatusListCorpus()
        try! testSyntheticStatusListCredentialVerification()
        try! await testOfficialDMVFixtureParsing()
        try! await testDIDWebResolution()
        await testScannerWrapper()
        print("CADMVVerifierSelfTest passed")
    }

    private static func testMissingOptionalVCB() async {
        let barcode = AAMVATestBarcode.make(
            issuer: "636014",
            issueDate: "09282025",
            jurisdiction: "CA",
            encodedVCB: nil
        )
        let result = await CADMVVerifier.verify(rawPDF417: barcode)
        expect(result.status == .notPresent, "missing optional VCB should be notPresent")
    }

    private static func testRequiredMissingVCB() async {
        let barcode = AAMVATestBarcode.make(
            issuer: "636014",
            issueDate: "09292025",
            jurisdiction: "CA",
            encodedVCB: nil
        )
        let result = await CADMVVerifier.verify(rawPDF417: barcode)
        expect(result.status == .failed, "required missing VCB should fail")
    }

    private static func testRequireVCBOption() async {
        let barcode = AAMVATestBarcode.make(
            issuer: "636014",
            issueDate: "09282025",
            jurisdiction: "CA",
            encodedVCB: nil
        )
        let result = await CADMVVerifier.verify(
            rawPDF417: barcode,
            options: CADMVVerificationOptions(requireVCB: true)
        )
        expect(result.status == .failed, "requireVCB option should fail missing VCB")
    }

    private static func testNonCaliforniaBarcode() async {
        let barcode = AAMVATestBarcode.make(
            issuer: "636000",
            issueDate: "09292025",
            jurisdiction: "NV",
            encodedVCB: "AQIDBA"
        )
        let result = await CADMVVerifier.verify(rawPDF417: barcode)
        expect(result.status == .notPresent, "non-California barcode should be notPresent")
    }

    private static func testIssueDateBoundaryMatrix() async {
        let optionalBoundaryCases = [
            "09282025",
            "02292024",
            "12312024"
        ]
        for issueDate in optionalBoundaryCases {
            let barcode = AAMVATestBarcode.make(
                issuer: "636014",
                issueDate: issueDate,
                jurisdiction: "CA",
                encodedVCB: nil
            )
            let result = await CADMVVerifier.verify(rawPDF417: barcode)
            expect(result.status == .notPresent, "\(issueDate) should not require a missing VCB")
        }

        for issueDate in ["09292025", "09302025", "12319999"] {
            let barcode = AAMVATestBarcode.make(
                issuer: "636014",
                issueDate: issueDate,
                jurisdiction: "CA",
                encodedVCB: nil
            )
            let result = await CADMVVerifier.verify(rawPDF417: barcode)
            expect(result.status == .failed, "\(issueDate) should require a missing VCB")
        }

        for issueDate in ["00002025", "00012025", "02302025", "02292025", "04312025"] {
            let barcode = AAMVATestBarcode.make(
                issuer: "636014",
                issueDate: issueDate,
                jurisdiction: "CA",
                encodedVCB: nil
            )
            let result = await CADMVVerifier.verify(rawPDF417: barcode)
            expect(result.status == .failed, "\(issueDate) should fail closed as an invalid date")
        }
    }

    private static func testImpossibleIssueDateRequiresVCB() async {
        let barcode = AAMVATestBarcode.make(
            issuer: "636014",
            issueDate: "02312025",
            jurisdiction: "CA",
            encodedVCB: nil
        )
        let result = await CADMVVerifier.verify(rawPDF417: barcode)
        expect(result.status == .failed, "impossible issue date should fail closed when VCB is missing")
    }

    private static func testMalformedBase64VCBFails() async {
        let barcode = AAMVATestBarcode.make(
            issuer: "636014",
            issueDate: "08052025",
            jurisdiction: "CA",
            encodedVCB: "not valid base64"
        )
        let result = await CADMVVerifier.verify(rawPDF417: barcode)
        expect(result.status == .failed, "malformed base64 VCB should fail")
    }

    private static func testMalformedCBORLDFails() async {
        let barcode = AAMVATestBarcode.make(
            issuer: "636014",
            issueDate: "08052025",
            jurisdiction: "CA",
            encodedVCB: "AQIDBA"
        )
        let result = await CADMVVerifier.verify(rawPDF417: barcode)
        expect(result.status == .failed, "malformed CBOR-LD VCB should fail")

        let deeplyNestedCBOR = Data(repeating: 0x81, count: 40) + Data([0x00])
        let nestedBarcode = AAMVATestBarcode.make(
            issuer: "636014",
            issueDate: "08052025",
            jurisdiction: "CA",
            encodedVCB: base64URL(deeplyNestedCBOR)
        )
        let nestedResult = await CADMVVerifier.verify(rawPDF417: nestedBarcode)
        expect(nestedResult.status == .failed, "deeply nested CBOR VCB should fail closed")
    }

    private static func testMalformedBarcodeCorpus() async {
        let malformedInputs = [
            "",
            "ANSI",
            "@\n\u{1e}\rANSI 636014",
            "@\n\u{1e}\rANSI 6360141001XX",
            "@\n\u{1e}\rANSI 636014100102DL99999999",
            "@\n\u{1e}\rANSI 636014100101DL0037-001",
            AAMVATestBarcode.make(
                issuer: "636014",
                issueDate: "notadate",
                jurisdiction: "CA",
                encodedVCB: nil
            )
        ]

        for input in malformedInputs {
            let result = await CADMVVerifier.verify(rawPDF417: input)
            expect(result.status != .verified, "malformed barcode corpus must never verify")
        }
    }

    private static func testMalformedBarcodeDescriptorCorpus() async {
        let malformedInputs = [
            AAMVATestBarcode.makeWithRawEntry(designator: "DL", offset: "-001", length: "0010", body: "DLDAQX\r"),
            AAMVATestBarcode.makeWithRawEntry(designator: "DL", offset: "9999", length: "0001", body: "DLDAQX\r"),
            AAMVATestBarcode.makeWithRawEntry(designator: "DL", offset: "0037", length: "9999", body: "DLDAQX\r"),
            AAMVATestBarcode.makeWithRawEntry(designator: "D!", offset: "0037", length: "0007", body: "D!DAQX\r"),
            "@\n\u{1e}\rANSI 636014100199DL00370007DLDAQX\r"
        ]

        for input in malformedInputs {
            let result = await CADMVVerifier.verify(rawPDF417: input)
            expect(result.status != .verified, "malformed descriptor corpus must never verify")
        }
    }

    private static func testBase64URLRejectsMalformedLengths() {
        expect(
            CADMVVerifier.base64URLDecodeForSelfTest("AQID") == Data([1, 2, 3]),
            "valid base64url should decode"
        )
        expect(
            CADMVVerifier.base64URLDecodeForSelfTest("A") == nil,
            "base64url length 1 mod 4 should be rejected"
        )
        expect(
            CADMVVerifier.base64URLDecodeForSelfTest("AA=A") == nil,
            "base64url padding in the middle should be rejected"
        )
        expect(
            CADMVVerifier.base64URLDecodeForSelfTest("AA+A") == Data([0, 15, 128]),
            "standard base64 alphabet should remain accepted for DMV VCB compatibility"
        )
        for malformed in ["A", "AAAA=", "A===", "AA=A", "AA A", "AA\nAA"] {
            expect(
                CADMVVerifier.base64URLDecodeForSelfTest(malformed) == nil,
                "\(malformed) should be rejected by base64 decoder"
            )
        }
    }

    private static func testBase58RejectsMalformedInput() {
        for malformed in ["0", "O", "I", "l", "z0", "abc+"] {
            expect(
                CADMVVerifier.base58DecodeForSelfTest(malformed) == nil,
                "\(malformed) should be rejected by base58 decoder"
            )
        }
    }

    private static func testGzipOutputLimit() throws {
        let encodedList = "uH4sIAAAAAAAAA2tgBAAiul0NAgAAAA"
        guard let compressed = CADMVVerifier.base64URLDecodeForSelfTest(String(encodedList.dropFirst())) else {
            fatalError("test gzip payload should decode")
        }

        do {
            _ = try CADMVVerifier.gzipDecompressForSelfTest(compressed, maxOutputBytes: 1)
            fatalError("gzip output above the configured limit should fail")
        } catch {
            // Expected: status-list decompression must be bounded.
        }
    }

    private static func testBase58LeadingZeroRoundTrip() {
        let singleZero = Data([0])
        expect(
            CADMVVerifier.base58EncodeForSelfTest(singleZero) == "1",
            "single leading zero byte should encode as one base58 zero"
        )
        expect(
            CADMVVerifier.base58DecodeForSelfTest("1") == singleZero,
            "single base58 zero should decode as one zero byte"
        )

        let leadingZeros = Data([0, 0, 1, 2, 3, 255])
        let encoded = CADMVVerifier.base58EncodeForSelfTest(leadingZeros)
        expect(
            CADMVVerifier.base58DecodeForSelfTest(encoded) == leadingZeros,
            "base58 leading-zero payload should round trip"
        )
    }

    private static func testStatusBitIndexing() throws {
        let bytes = Data([0b1000_0000, 0b0000_0001])
        expect(
            CADMVVerifier.statusBitForSelfTest(uncompressedBytes: bytes, index: 0) == true,
            "status bit 0 should use high bit of first byte"
        )
        expect(
            CADMVVerifier.statusBitForSelfTest(uncompressedBytes: bytes, index: 7) == false,
            "status bit 7 should use low bit of first byte"
        )
        expect(
            CADMVVerifier.statusBitForSelfTest(uncompressedBytes: bytes, index: 15) == true,
            "status bit 15 should use low bit of second byte"
        )
        expect(
            CADMVVerifier.statusBitForSelfTest(uncompressedBytes: bytes, index: 16) == nil,
            "out-of-range status bit should be nil"
        )

        let encodedList = "uH4sIAAAAAAAAA2tgBAAiul0NAgAAAA"
        let encodedBit0 = try CADMVVerifier.statusBitForSelfTest(
            encodedList: encodedList,
            index: 0
        )
        let encodedBit15 = try CADMVVerifier.statusBitForSelfTest(
            encodedList: encodedList,
            index: 15
        )
        expect(
            encodedBit0 == true,
            "encoded status bit 0 should decode from gzip/base64url list"
        )
        expect(
            encodedBit15 == true,
            "encoded status bit 15 should decode from gzip/base64url list"
        )
    }

    private static func testMalformedStatusListCorpus() throws {
        let malformedEncodedLists = [
            "",
            "zH4sIAAAAAAAAA2tgBAAiul0NAgAAAA",
            "uA",
            "uAAAA",
            "uH4sIAAAAAAAA"
        ]

        for encodedList in malformedEncodedLists {
            do {
                _ = try CADMVVerifier.statusBitForSelfTest(encodedList: encodedList, index: 0)
                fatalError("\(encodedList) should fail status-list decoding")
            } catch {
                // Expected: malformed status-list values fail closed.
            }
        }

        expect(
            CADMVVerifier.statusBitForSelfTest(uncompressedBytes: Data([0]), index: UInt64.max) == nil,
            "huge status bit index should be out of range"
        )
    }

    private static func testSyntheticStatusListCredentialVerification() throws {
        let json = """
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
        """
        let data = Data(json.utf8)
        let verifyDataHex = try CADMVVerifier.statusListVerifyDataForSelfTest(jsonData: data)
        expect(
            verifyDataHex == "93fa093cba64513885ce626317a174530e4d19527212094b1571d4b8e665a22132f9e3eb0ef441494d9f35b40deed3703c7730e491db83245714e0a1475100c1",
            "synthetic status-list verify-data should match JS ecdsa-rdfc-2019 reference"
        )
        let verifies = try CADMVVerifier.verifyStatusListCredentialForSelfTest(
            jsonData: data,
            publicKeyMultibase: "zDnaeVp3tjD8ipWSt42tBZJLCsDA9SrtYXGvLg5dL3qXtXDKP",
            id: "did:web:uat-credentials.dmv.ca.gov#vm-vcb-1",
            controller: "did:web:uat-credentials.dmv.ca.gov"
        )
        expect(
            verifies,
            "synthetic status-list credential should verify against JS reference key"
        )
        let statusBit = try CADMVVerifier.statusBitForSelfTest(
            encodedList: "uH4sIAAAAAAAAA2NhAAD717UlAgAAAA",
            index: 5
        )
        expect(
            statusBit == true,
            "synthetic status-list credential should mark bit 5 revoked"
        )
        let revokedResult = try CADMVVerifier.statusListCheckResultForSelfTest(
            jsonData: data,
            publicKeyMultibase: "zDnaeVp3tjD8ipWSt42tBZJLCsDA9SrtYXGvLg5dL3qXtXDKP",
            id: "did:web:uat-credentials.dmv.ca.gov#vm-vcb-1",
            controller: "did:web:uat-credentials.dmv.ca.gov",
            expectedURL: "https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists/revocation/0",
            statusListIndex: 5,
            credentialIssuer: "did:web:uat-credentials.dmv.ca.gov"
        )
        expect(revokedResult == .revoked, "verified status-list bit should map to revoked")

        let notRevokedResult = try CADMVVerifier.statusListCheckResultForSelfTest(
            jsonData: data,
            publicKeyMultibase: "zDnaeVp3tjD8ipWSt42tBZJLCsDA9SrtYXGvLg5dL3qXtXDKP",
            id: "did:web:uat-credentials.dmv.ca.gov#vm-vcb-1",
            controller: "did:web:uat-credentials.dmv.ca.gov",
            expectedURL: "https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists/revocation/0",
            statusListIndex: 0,
            credentialIssuer: "did:web:uat-credentials.dmv.ca.gov"
        )
        expect(notRevokedResult == .verified, "verified clear status-list bit should map to verified")

        let tampered = Data(json.replacingOccurrences(
            of: "uH4sIAAAAAAAAA2NhAAD717UlAgAAAA",
            with: "uH4sIAAAAAAAAA2tgBAAiul0NAgAAAA"
        ).utf8)
        let tamperedVerifies = try CADMVVerifier.verifyStatusListCredentialForSelfTest(
            jsonData: tampered,
            publicKeyMultibase: "zDnaeVp3tjD8ipWSt42tBZJLCsDA9SrtYXGvLg5dL3qXtXDKP",
            id: "did:web:uat-credentials.dmv.ca.gov#vm-vcb-1",
            controller: "did:web:uat-credentials.dmv.ca.gov"
        )
        expect(
            !tamperedVerifies,
            "tampered status-list encodedList should fail signature verification"
        )

        let unsafeCanonicalValue = Data(json.replacingOccurrences(
            of: "did:web:uat-credentials.dmv.ca.gov",
            with: "did:web:uat-credentials.dmv.ca.gov\\n"
        ).utf8)
        do {
            _ = try CADMVVerifier.statusListVerifyDataForSelfTest(jsonData: unsafeCanonicalValue)
            fatalError("unsafe status-list canonicalization value must be rejected")
        } catch {
            // Expected: the narrow RDF canonicalizer only accepts safe profile strings.
        }
    }

    private static func testOfficialDMVFixtureParsing() async throws {
        let fixtures = try ReferenceSDKFixtures.load()
        expect(fixtures.validUAT.contains("ANSI 636014"), "valid UAT fixture should load")
        expect(fixtures.invalidUAT.contains("ANSI 636014"), "invalid UAT fixture should load")

        let validInspection = try CADMVVerifier.inspectForSelfTest(rawPDF417: fixtures.validUAT)
        expect(validInspection.issuerAccepted, "valid UAT fixture issuer should be accepted")
        expect(!validInspection.vcbRequired, "valid UAT fixture predates requirement date")
        expect(validInspection.vcbPresent, "valid UAT fixture should include VCB")
        expect(validInspection.decodedVCBByteCount == 144, "valid UAT VCB byte count should match reference fixture")
        expect(
            validInspection.decodedCredentialIssuer == "did:web:uat-credentials.dmv.ca.gov",
            "valid UAT issuer should match decoded reference credential"
        )
        expect(
            validInspection.decodedCredentialProofValue == "z43jxJrDSKCMo83ki5FWSjV7CTugPzco4g4xT2X2RegvyjJwpRS59U2nHbvdtLo9R9Xejvy7HqwaYU6NgnHJEAo6F",
            "valid UAT proof value should match decoded reference credential"
        )
        expect(validInspection.uatCredentialShapeValid, "valid UAT credential shape should validate in UAT mode")
        expect(!validInspection.productionCredentialShapeValid, "valid UAT credential shape should not validate in production mode")
        expect(
            validInspection.opticalDataHashHex == "88ece8411fbb63e4f45f8e460a6710cf393e1081da7071f84abd32e8fba68495",
            "valid UAT optical data hash should match JS reference; got \(validInspection.opticalDataHashHex ?? "nil")"
        )
        expect(
            validInspection.verifyDataHex == "15806ce019af44239dabfc6bd43fe9301277e1db8832f571d7f646806ba99fedabbbb98c352b3775dd421c18f8b620f40b0e680cc8e4e4ee5486b6c3de3e710db68333bc7d8bf220fbeb11b0be5a46917ceb0dd4b0d8953057645c2a22b86886",
            "valid UAT verify-data should match JS reference; got \(validInspection.verifyDataHex ?? "nil")"
        )
        expect(
            validInspection.statusListURL == "https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists/revocation/57",
            "valid UAT status-list URL should match terse status calculation; got \(validInspection.statusListURL ?? "nil")"
        )
        expect(
            validInspection.statusListIndex == 41_319_687,
            "valid UAT status-list index should match terse status calculation; got \(validInspection.statusListIndex.map(String.init) ?? "nil")"
        )

        let invalidInspection = try CADMVVerifier.inspectForSelfTest(rawPDF417: fixtures.invalidUAT)
        expect(invalidInspection.issuerAccepted, "invalid UAT fixture issuer should be accepted")
        expect(!invalidInspection.vcbRequired, "invalid UAT fixture predates requirement date")
        expect(invalidInspection.vcbPresent, "invalid UAT fixture should include VCB")
        expect(invalidInspection.decodedVCBByteCount == 144, "invalid UAT VCB byte count should match reference fixture")
        expect(
            invalidInspection.decodedCredentialIssuer == "did:web:uat-credentials.dmv.ca.gov",
            "invalid UAT issuer should match decoded reference credential"
        )
        expect(
            invalidInspection.decodedCredentialProofValue == "z2y9TzfWdhznKxM9dxkckDxmLLyFBfyVSC4rbJP5zufLxjnmYWvf6o8kuF6M9txfKPXf39pdwmKWHZpGU9HVNoWwk",
            "invalid UAT proof value should match decoded reference credential"
        )
        expect(invalidInspection.uatCredentialShapeValid, "invalid UAT credential shape should validate in UAT mode")
        expect(!invalidInspection.productionCredentialShapeValid, "invalid UAT credential shape should not validate in production mode")
        expect(
            invalidInspection.opticalDataHashHex == "066ef4ca9fae13c092405c5d223c9e05aa645137de0f4d462385042fab199fcf",
            "invalid UAT optical data hash should match JS reference; got \(invalidInspection.opticalDataHashHex ?? "nil")"
        )

        try await withFixtureNetwork { @Sendable request in
            try FixtureNetwork.response(for: request)
        } operation: {
            let validResult = await CADMVVerifier.verify(
                rawPDF417: fixtures.validUAT,
                options: CADMVVerificationOptions(mode: .uat)
            )
            expect(validResult.status == .verified, "valid UAT fixture should cryptographically verify")

            let invalidResult = await CADMVVerifier.verify(
                rawPDF417: fixtures.invalidUAT,
                options: CADMVVerificationOptions(mode: .uat)
            )
            expect(invalidResult.status == .failed, "invalid UAT fixture should fail signature verification")
        }

        let tamperedProtectedField = fixtures.validUAT.replacingOccurrences(
            of: "DAQI8887059",
            with: "DAQI8887060"
        )
        try await withFixtureNetwork { @Sendable request in
            try FixtureNetwork.response(for: request)
        } operation: {
            let tamperedResult = await CADMVVerifier.verify(
                rawPDF417: tamperedProtectedField,
                options: CADMVVerificationOptions(mode: .uat)
            )
            expect(tamperedResult.status == .failed, "tampered protected AAMVA field should fail")
        }

        let productionModeResult = await CADMVVerifier.verify(rawPDF417: fixtures.validUAT)
        expect(productionModeResult.status == .failed, "UAT fixture should fail in production mode")

        try await withFixtureNetwork { @Sendable request in
            try FixtureNetwork.response(for: request, statusURLsReturnUnavailable: true)
        } operation: {
            let statusRequiredResult = await CADMVVerifier.verify(
                rawPDF417: fixtures.validUAT,
                options: CADMVVerificationOptions(checkStatus: true, mode: .uat)
            )
            expect(statusRequiredResult.status == .unavailable, "status-required verification should be unavailable when status endpoint returns HTTP failure")
        }
    }

    private static func testDIDWebResolution() async throws {
        try await withFixtureNetwork { @Sendable request in
            try FixtureNetwork.response(for: request)
        } operation: {
            let uatKey = try await CADMVVerifier.resolveVerificationMethodForSelfTest(
                "did:web:uat-credentials.dmv.ca.gov#vm-vcb-1",
                mode: .uat
            )
            expect(
                uatKey == "02369ab0d3212491cf3526b34e146ba105ae43e6d44b45240e3c2ccf59d06720bb",
                "UAT DID key should match DMV DID document fixture"
            )

            let productionKey = try await CADMVVerifier.resolveVerificationMethodForSelfTest(
                "did:web:credentials.dmv.ca.gov#vm-vcb-1",
                mode: .production
            )
            expect(
                productionKey == "0395fd0f91f717274281270bf18d59690120db740c6dccbab6d6cc990fc33034a1",
                "production DID key should match DMV DID document fixture"
            )
        }

        do {
            _ = try await CADMVVerifier.resolveVerificationMethodForSelfTest(
                "did:web:credentials.dmv.ca.gov#vm-vcb-1",
                mode: .uat,
                timeoutSeconds: 10
            )
            fatalError("production verification method must not resolve in UAT mode")
        } catch {
            // Expected: mode/DID mismatch must fail before any arbitrary fetch.
        }

        try await withFixtureNetwork { @Sendable request in
            try FixtureNetwork.response(for: request, didStatusCode: 302)
        } operation: {
            do {
                _ = try await CADMVVerifier.resolveVerificationMethodForSelfTest(
                    "did:web:uat-credentials.dmv.ca.gov#vm-vcb-1",
                    mode: .uat
                )
                fatalError("DID redirect/non-2xx response must fail")
            } catch {
                // Expected: DID resolution only accepts direct 2xx responses.
            }
        }

        try await withFixtureNetwork { @Sendable request in
            try FixtureNetwork.response(for: request, omitAssertionMethod: true)
        } operation: {
            do {
                _ = try await CADMVVerifier.resolveVerificationMethodForSelfTest(
                    "did:web:uat-credentials.dmv.ca.gov#vm-vcb-1",
                    mode: .uat
                )
                fatalError("DID method not authorized for assertion must fail")
            } catch {
                // Expected: assertionMethod authorization is required.
            }
        }
    }

    private static func testScannerWrapper() async {
        let barcode = AAMVATestBarcode.make(
            issuer: "636014",
            issueDate: "09282025",
            jurisdiction: "CA",
            encodedVCB: nil
        )
        let scanned = CADMVScannedBarcode(rawPDF417: barcode)
        expect(scanned.rawPDF417 == barcode, "scanner wrapper should retain raw PDF417 payload")
        let result = await scanned.verify()
        expect(result.status == .notPresent, "scanner wrapper should pass payload to verifier")

        switch CADMVScanner.availability {
        case .available:
            break
        case .unavailable(let reason):
            expect(!reason.isEmpty, "scanner unavailability should include a reason")
        }
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fatalError(message)
        }
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func withFixtureNetwork(
        _ handler: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse),
        operation: () async throws -> Void
    ) async throws {
        await CADMVVerifier.setNetworkHandlerForSelfTest(handler)
        do {
            try await operation()
            await CADMVVerifier.setNetworkHandlerForSelfTest(nil)
        } catch {
            await CADMVVerifier.setNetworkHandlerForSelfTest(nil)
            throw error
        }
    }
}

enum FixtureNetwork {
    static func response(
        for request: URLRequest,
        didStatusCode: Int = 200,
        omitAssertionMethod: Bool = false,
        statusURLsReturnUnavailable: Bool = false
    ) throws -> (Data, URLResponse) {
        guard let url = request.url else {
            throw FixtureError.missingURL
        }

        let body: Data
        let statusCode: Int
        if url.absoluteString == "https://uat-credentials.dmv.ca.gov/.well-known/did.json" {
            body = didDocument(
                did: "did:web:uat-credentials.dmv.ca.gov",
                key: "zDnaeU77sUhXKYqRy8263bsCq9Np7vy2z8epZ9WJ6YSWD1TVU",
                omitAssertionMethod: omitAssertionMethod
            )
            statusCode = didStatusCode
        } else if url.absoluteString == "https://credentials.dmv.ca.gov/.well-known/did.json" {
            body = didDocument(
                did: "did:web:credentials.dmv.ca.gov",
                key: "zDnaeskmyLDwiAmeewyrsaG5SaM3Nz3oSRsw1D17i7USTks9J",
                omitAssertionMethod: omitAssertionMethod
            )
            statusCode = didStatusCode
        } else if statusURLsReturnUnavailable && url.host == "api.uat-credentials.dmv.ca.gov" {
            body = Data()
            statusCode = 503
        } else {
            throw FixtureError.unexpectedURL(url.absoluteString)
        }

        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        ) else {
            throw FixtureError.invalidResponse
        }
        return (body, response)
    }

    private static func didDocument(
        did: String,
        key: String,
        omitAssertionMethod: Bool
    ) -> Data {
        let assertionMethod = omitAssertionMethod ? "[]" : #"["\#(did)#vm-vcb-1"]"#
        return Data("""
        {
          "id": "\(did)",
          "verificationMethod": [
            {
              "id": "\(did)#vm-vcb-1",
              "type": "Multikey",
              "controller": "\(did)",
              "publicKeyMultibase": "\(key)"
            }
          ],
          "assertionMethod": \(assertionMethod)
        }
        """.utf8)
    }

    enum FixtureError: Error {
        case missingURL
        case unexpectedURL(String)
        case invalidResponse
    }
}

struct ReferenceSDKFixtures {
    let validUAT: String
    let invalidUAT: String

    static func load() throws -> ReferenceSDKFixtures {
        let testFile = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appending(path: "References/cadmv-dlid-verifier-sdk/tests/001-main.test.js")
        let source = try String(contentsOf: testFile, encoding: .utf8)

        return ReferenceSDKFixtures(
            validUAT: try extractStringLiteral(named: "validUatExample", from: source),
            invalidUAT: try extractStringLiteral(named: "invalidUatExample", from: source)
        )
    }

    private static func extractStringLiteral(named name: String, from source: String) throws -> String {
        let pattern = #"const \#(name) = '((?:\\.|[^'])*)';"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        guard let match = regex.firstMatch(in: source, range: range),
              let literalRange = Range(match.range(at: 1), in: source) else {
            throw FixtureError.missingFixture(name)
        }

        return try decodeJavaScriptSingleQuotedLiteral(String(source[literalRange]))
    }

    private static func decodeJavaScriptSingleQuotedLiteral(_ literal: String) throws -> String {
        var output = ""
        var cursor = literal.startIndex

        while cursor < literal.endIndex {
            let character = literal[cursor]
            if character != "\\" {
                output.append(character)
                cursor = literal.index(after: cursor)
                continue
            }

            let escapeStart = cursor
            cursor = literal.index(after: cursor)
            guard cursor < literal.endIndex else {
                throw FixtureError.invalidEscape
            }

            switch literal[cursor] {
            case "n":
                output.append("\n")
                cursor = literal.index(after: cursor)
            case "r":
                output.append("\r")
                cursor = literal.index(after: cursor)
            case "t":
                output.append("\t")
                cursor = literal.index(after: cursor)
            case "'", "\"", "\\":
                output.append(literal[cursor])
                cursor = literal.index(after: cursor)
            case "u":
                let hexStart = literal.index(after: cursor)
                let hexEnd = literal.index(hexStart, offsetBy: 4, limitedBy: literal.endIndex)
                guard let hexEnd,
                      hexEnd <= literal.endIndex,
                      let scalarValue = UInt32(literal[hexStart..<hexEnd], radix: 16),
                      let scalar = UnicodeScalar(scalarValue) else {
                    throw FixtureError.invalidEscape
                }
                output.unicodeScalars.append(scalar)
                cursor = hexEnd
            default:
                throw FixtureError.unsupportedEscape(String(literal[escapeStart...cursor]))
            }
        }

        return output
    }

    enum FixtureError: Error {
        case missingFixture(String)
        case invalidEscape
        case unsupportedEscape(String)
    }
}

enum AAMVATestBarcode {
    static func make(
        issuer: String,
        issueDate: String,
        jurisdiction: String,
        encodedVCB: String?
    ) -> String {
        let dlSubfile = [
            "DLDAQSYNTHETIC",
            "DBD\(issueDate)",
            "DAJ\(jurisdiction)"
        ].joined(separator: "\n") + "\r"

        let zcSubfile: String
        if let encodedVCB {
            zcSubfile = [
                "ZCZCA",
                "ZCE\(encodedVCB)"
            ].joined(separator: "\n") + "\r"
        } else {
            zcSubfile = [
                "ZCZCA"
            ].joined(separator: "\n") + "\r"
        }

        let prefix = "@\n\u{1e}\rANSI "
        let headerWithoutEntries = "\(prefix)\(issuer)100102"
        let entriesLength = 20
        let dlOffset = headerWithoutEntries.count + entriesLength
        let zcOffset = dlOffset + dlSubfile.count
        let entries = "DL\(pad(dlOffset))\(pad(dlSubfile.count))ZC\(pad(zcOffset))\(pad(zcSubfile.count))"

        return headerWithoutEntries + entries + dlSubfile + zcSubfile
    }

    private static func pad(_ value: Int) -> String {
        String(format: "%04d", value)
    }

    static func makeWithRawEntry(
        designator: String,
        offset: String,
        length: String,
        body: String
    ) -> String {
        "@\n\u{1e}\rANSI 636014100101\(designator)\(offset)\(length)\(body)"
    }
}
