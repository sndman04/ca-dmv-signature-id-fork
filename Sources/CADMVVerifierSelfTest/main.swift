@_spi(Testing) import CADMVVerifier
import Foundation

@main
enum CADMVVerifierSelfTest {
    static func main() async {
        await testMissingOptionalVCB()
        await testRequiredMissingVCB()
        await testRequireVCBOption()
        await testNonCaliforniaBarcode()
        await testMalformedBase64VCBFails()
        await testMalformedCBORLDFails()
        await testMalformedBarcodeCorpus()
        try! testStatusBitIndexing()
        try! testSyntheticStatusListCredentialVerification()
        try! await testOfficialDMVFixtureParsing()
        try! await testDIDWebResolution()
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
    }

    private static func testMalformedBarcodeCorpus() async {
        let malformedInputs = [
            "",
            "ANSI",
            "@\n\u{1e}\rANSI 636014",
            "@\n\u{1e}\rANSI 6360141001XX",
            "@\n\u{1e}\rANSI 636014100102DL99999999",
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

        let tamperedProtectedField = fixtures.validUAT.replacingOccurrences(
            of: "DAQI8887059",
            with: "DAQI8887060"
        )
        let tamperedResult = await CADMVVerifier.verify(
            rawPDF417: tamperedProtectedField,
            options: CADMVVerificationOptions(mode: .uat)
        )
        expect(tamperedResult.status == .failed, "tampered protected AAMVA field should fail")

        let productionModeResult = await CADMVVerifier.verify(rawPDF417: fixtures.validUAT)
        expect(productionModeResult.status == .failed, "UAT fixture should fail in production mode")

        let statusRequiredResult = await CADMVVerifier.verify(
            rawPDF417: fixtures.validUAT,
            options: CADMVVerificationOptions(checkStatus: true, mode: .uat)
        )
        expect(statusRequiredResult.status == .unavailable, "status-required verification should be unavailable until status checks are implemented")
    }

    private static func testDIDWebResolution() async throws {
        let uatKey = try await CADMVVerifier.resolveVerificationMethodForSelfTest(
            "did:web:uat-credentials.dmv.ca.gov#vm-vcb-1",
            mode: .uat
        )
        expect(
            uatKey == "02369ab0d3212491cf3526b34e146ba105ae43e6d44b45240e3c2ccf59d06720bb",
            "UAT DID key should match DMV DID document"
        )

        let productionKey = try await CADMVVerifier.resolveVerificationMethodForSelfTest(
            "did:web:credentials.dmv.ca.gov#vm-vcb-1",
            mode: .production
        )
        expect(
            productionKey == "0395fd0f91f717274281270bf18d59690120db740c6dccbab6d6cc990fc33034a1",
            "production DID key should match DMV DID document"
        )

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
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fatalError(message)
        }
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
}
