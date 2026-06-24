@testable import CADMVVerifier
import Foundation
import Testing

@Suite
struct CADMVVerifierTests {
    @Test
    func malformedBarcodeReportsReason() async {
        let result = await CADMVVerifier.verify(rawPDF417: "ANSI")

        #expect(result.status == .failed)
        #expect(result.failureReason == .malformedBarcode)
    }

    @Test
    func missingOptionalVCBIsNotPresent() async {
        let barcode = AAMVATestBarcode.make(
            issuer: "636014",
            issueDate: "09282025",
            jurisdiction: "CA",
            encodedVCB: nil
        )

        let result = await CADMVVerifier.verify(rawPDF417: barcode)

        #expect(result.status == .notPresent)
        #expect(result.failureReason == .vcbMissing(required: false))
    }

    @Test
    func missingRequiredVCBFails() async {
        let barcode = AAMVATestBarcode.make(
            issuer: "636014",
            issueDate: "09292025",
            jurisdiction: "CA",
            encodedVCB: nil
        )

        let result = await CADMVVerifier.verify(rawPDF417: barcode)

        #expect(result.status == .failed)
        #expect(result.failureReason == .vcbMissing(required: true))
    }

    @Test
    func nonCaliforniaDocumentReportsReason() async {
        let barcode = AAMVATestBarcode.make(
            issuer: "636000",
            issueDate: "09292025",
            jurisdiction: "NV",
            encodedVCB: "AQIDBA"
        )

        let result = await CADMVVerifier.verify(rawPDF417: barcode)

        #expect(result.status == .notPresent)
        #expect(result.failureReason == .notCaliforniaDMV)
    }

    @Test
    func malformedVCBReportsBase64Reason() async {
        let barcode = AAMVATestBarcode.make(
            issuer: "636014",
            issueDate: "08052025",
            jurisdiction: "CA",
            encodedVCB: "not.valid.base64"
        )

        let result = await CADMVVerifier.verify(rawPDF417: barcode)

        #expect(result.status == .failed)
        #expect(result.failureReason == .vcbBase64Invalid)
    }

    @Test
    func unsupportedCBORReportsReason() async {
        let barcode = AAMVATestBarcode.make(
            issuer: "636014",
            issueDate: "08052025",
            jurisdiction: "CA",
            encodedVCB: "AQIDBA"
        )

        let result = await CADMVVerifier.verify(rawPDF417: barcode)

        #expect(result.status == .failed)
        #expect(result.failureReason == .vcbCBORUnsupported)
    }

    @Test
    func aamvaParserReadsSubfilesSequentiallyLikeReferenceDecoder() throws {
        let barcode = AAMVATestBarcode.make(
            descriptorOffsetDelta: 7,
            issuer: "636014",
            issueDate: "09282025",
            jurisdiction: "CA",
            encodedVCB: nil
        )

        let document = try AAMVADocumentParser().parse(rawPDF417: barcode)

        #expect(document.issuerIdentificationNumber == "636014")
        #expect(document.primaryIdentitySubfile?.fields["DBD"] == "09282025")
    }

    @Test
    func aamvaParserToleratesMultibyteScannerPreamble() throws {
        let barcode = AAMVATestBarcode.make(
            prefix: "é@\n\u{1e}\rANSI ",
            issuer: "636014",
            issueDate: "09282025",
            jurisdiction: "CA",
            encodedVCB: nil
        )

        let document = try AAMVADocumentParser().parse(rawPDF417: barcode)

        #expect(document.issuerIdentificationNumber == "636014")
        #expect(document.primaryIdentitySubfile?.fields["DBD"] == "09282025")
    }

    @Test
    func parserUsesDeclaredElementSeparator() throws {
        let barcode = AAMVATestBarcode.make(
            elementSeparator: "\u{1d}",
            issuer: "636014",
            issueDate: "09282025",
            jurisdiction: "CA",
            encodedVCB: nil
        )

        let document = try AAMVADocumentParser().parse(rawPDF417: barcode)

        #expect(document.issuerIdentificationNumber == "636014")
        #expect(document.primaryIdentitySubfile?.fields["DBD"] == "09282025")
        #expect(document.primaryIdentitySubfile?.fields["DAJ"] == "CA")
    }

    @Test
    func parserNormalizesEscapedControlCharacters() async {
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

        #expect(result.status == .notPresent)
        #expect(result.failureReason == .vcbMissing(required: false))
    }

    @Test
    func protectedComponentIndexDecodesAnyThreeByteBitmap() throws {
        let credential = try DMVVCBDecoder.decode(
            CBORFixture.credential(protectedComponentIndexBytes: Data([0x75, 0x01, 0x02, 0x03]))
        )

        #expect(credential.credentialSubject.protectedComponentIndex == "uAQID")
    }

    @Test
    func protectedComponentIndexAcceptsReferenceNumericForm() throws {
        let credential = try DMVVCBDecoder.decode(
            CBORFixture.credential(numericProtectedComponentIndex: 0x010203)
        )

        #expect(credential.credentialSubject.protectedComponentIndex == "uAQID")
    }

    @Test
    func protectedComponentIndexRejectsWrongMultibasePrefix() throws {
        #expect(throws: CADMVInternalError.unsupportedVCB) {
            try DMVVCBDecoder.decode(
                CBORFixture.credential(protectedComponentIndexBytes: Data([0x7a, 0x01, 0x02, 0x03]))
            )
        }
    }

    @Test
    func decoderAcceptsExpandedTextValuesFromCBORLD() throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.credential(textEncoded: true))

        #expect(credential.issuer == "did:web:uat-credentials.dmv.ca.gov")
        #expect(credential.credentialSubject.protectedComponentIndex == "uAQID")
        #expect(credential.proof.proofValue == "zLdp")
        #expect(credential.proof.verificationMethod == "did:web:uat-credentials.dmv.ca.gov#vm-vcb-1")
    }

    @Test
    func decoderAcceptsCredentialWithoutStatusBlock() throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.credential(includeStatus: false))

        #expect(credential.credentialStatus == nil)
        #expect(credential.proof.verificationMethod == "did:web:uat-credentials.dmv.ca.gov#vm-vcb-1")
    }

    @Test
    func validatorAllowsMissingStatusForStatusChecker() throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.credential(includeStatus: false))

        #expect(throws: Never.self) {
            try DMVCredentialValidator.validate(credential, mode: .uat)
        }
    }

    @Test
    func decoderAcceptsUncompressedCBORLDProfile() throws {
        let credential = try DMVVCBDecoder.decode(CBORFixture.uncompressedCredential())

        #expect(credential.context == [
            "https://www.w3.org/ns/credentials/v2",
            "https://w3id.org/vc-barcodes/v1"
        ])
        #expect(credential.type.contains("OpticalBarcodeCredential"))
        #expect(credential.credentialSubject.protectedComponentIndex == "uAQID")
        #expect(credential.credentialStatus?.terseStatusListIndex == 1)
    }

    @Test
    func decoderAcceptsLegacyUncompressedCBORLDProfile() throws {
        for tag in [UInt64(1_280), UInt64(1_536)] {
            let credential = try DMVVCBDecoder.decode(CBORFixture.uncompressedCredential(tag: tag))

            #expect(credential.issuer == "did:web:uat-credentials.dmv.ca.gov")
            #expect(credential.credentialSubject.protectedComponentIndex == "uAQID")
            #expect(credential.proof.verificationMethod == "did:web:uat-credentials.dmv.ca.gov#vm-vcb-1")
        }
    }

    @Test
    func decoderAcceptsLegacyCompressedCBORLDProfile() throws {
        for data in [
            CBORFixture.legacySingletonCompressedCredential(),
            CBORFixture.legacyRangeCompressedCredential()
        ] {
            let credential = try DMVVCBDecoder.decode(data)

            #expect(credential.issuer == "did:web:uat-credentials.dmv.ca.gov")
            #expect(credential.credentialSubject.protectedComponentIndex == "uAQID")
            #expect(credential.credentialStatus?.terseStatusListIndex == 1)
        }
    }
}

private enum AAMVATestBarcode {
    static func make(
        prefix: String = "@\n\u{1e}\rANSI ",
        elementSeparator: Character = "\n",
        recordSeparator: Character = "\u{1e}",
        segmentTerminator: Character = "\r",
        descriptorOffsetDelta: Int = 0,
        issuer: String,
        issueDate: String,
        jurisdiction: String,
        encodedVCB: String?
    ) -> String {
        let prefix = prefix == "@\n\u{1e}\rANSI "
            ? "@\(elementSeparator)\(recordSeparator)\(segmentTerminator)ANSI "
            : prefix
        let dlSubfile = [
            "DLDAQSYNTHETIC",
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
        let dlOffset = headerWithoutEntries.utf8.count + entriesLength + descriptorOffsetDelta
        let zcOffset = dlOffset + dlSubfile.utf8.count
        let entries = "DL\(pad(dlOffset))\(pad(dlSubfile.utf8.count))ZC\(pad(zcOffset))\(pad(zcSubfile.utf8.count))"

        return headerWithoutEntries + entries + dlSubfile + zcSubfile
    }

    private static func pad(_ value: Int) -> String {
        String(format: "%04d", value)
    }
}

private enum CBORFixture {
    static func credential(
        protectedComponentIndexBytes: Data = Data([0x75, 0x01, 0x02, 0x03]),
        includeStatus: Bool = true,
        textEncoded: Bool = false
    ) -> Data {
        credential(
            protectedComponentIndexValue: textEncoded
                ? text("uAQID")
                : byteString(protectedComponentIndexBytes),
            includeStatus: includeStatus,
            textEncoded: textEncoded
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

    static func uncompressedCredential(tag: UInt64 = 51_997) -> Data {
        let credential = map([
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
            (text("proof"), map([
                (text("type"), text("DataIntegrityProof")),
                (text("cryptosuite"), text("ecdsa-xi-2023")),
                (text("proofPurpose"), text("assertionMethod")),
                (text("proofValue"), text("zLdp")),
                (text("verificationMethod"), text("did:web:uat-credentials.dmv.ca.gov#vm-vcb-1"))
            ])),
            (text("ignored"), null())
        ])

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
        textEncoded: Bool
    ) -> Data {
        let payload = compressedCredentialMap(
            protectedComponentIndexValue: protectedComponentIndexValue,
            includeStatus: includeStatus,
            textEncoded: textEncoded
        )

        return tagged(51_997, array([
            unsigned(31_000_000),
            payload
        ]))
    }

    private static func compressedCredentialMap(
        protectedComponentIndexValue: Data = byteString(Data([0x75, 0x01, 0x02, 0x03])),
        includeStatus: Bool = true,
        textEncoded: Bool = false
    ) -> Data {
        var pairs: [(Data, Data)] = [
            (unsigned(1), array(textEncoded
                ? [text("https://www.w3.org/ns/credentials/v2"), text("https://w3id.org/vc-barcodes/v1")]
                : [unsigned(1), unsigned(2)])),
            (unsigned(157), array(textEncoded
                ? [text("VerifiableCredential"), text("OpticalBarcodeCredential")]
                : [unsigned(118), unsigned(164)])),
            (unsigned(180), textEncoded ? text("did:web:uat-credentials.dmv.ca.gov") : bytes([20])),
            (unsigned(176), map([
                (unsigned(156), textEncoded ? text("AamvaDriversLicenseScannableInformation") : unsigned(160)),
                (unsigned(168), protectedComponentIndexValue)
            ])),
            (unsigned(182), map([
                (unsigned(156), textEncoded ? text("DataIntegrityProof") : unsigned(108)),
                (unsigned(204), textEncoded ? text("ecdsa-xi-2023") : unsigned(1)),
                (unsigned(214), textEncoded ? text("assertionMethod") : unsigned(220)),
                (unsigned(216), textEncoded ? text("zLdp") : byteString(Data([0x7a, 0x01, 0x02, 0x03]))),
                (unsigned(218), textEncoded ? text("did:web:uat-credentials.dmv.ca.gov#vm-vcb-1") : bytes([22]))
            ]))
        ]
        if includeStatus {
            pairs.append((unsigned(174), map([
                (unsigned(156), textEncoded ? text("TerseBitstringStatusListEntry") : unsigned(166)),
                (unsigned(196), textEncoded
                    ? text("https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists")
                    : bytes([21])),
                (unsigned(198), unsigned(1))
            ])))
        }

        return map(pairs)
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
