@testable import CADMVVerifier
import Foundation
import Testing

@Suite
struct CADMVVerifierTests {
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
    }

    @Test
    func aamvaOffsetsAreByteOffsets() throws {
        let barcode = AAMVATestBarcode.make(
            prefix: "@\n\u{1e}\réANSI ",
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
    func protectedComponentIndexDecodesAnyThreeByteBitmap() throws {
        let credential = try DMVVCBDecoder.decode(
            CBORFixture.credential(protectedComponentIndexBytes: Data([0x75, 0x01, 0x02, 0x03]))
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
}

private enum AAMVATestBarcode {
    static func make(
        prefix: String = "@\n\u{1e}\rANSI ",
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

        let headerWithoutEntries = "\(prefix)\(issuer)100102"
        let entriesLength = 20
        let dlOffset = headerWithoutEntries.utf8.count + entriesLength
        let zcOffset = dlOffset + dlSubfile.utf8.count
        let entries = "DL\(pad(dlOffset))\(pad(dlSubfile.utf8.count))ZC\(pad(zcOffset))\(pad(zcSubfile.utf8.count))"

        return headerWithoutEntries + entries + dlSubfile + zcSubfile
    }

    private static func pad(_ value: Int) -> String {
        String(format: "%04d", value)
    }
}

private enum CBORFixture {
    static func credential(protectedComponentIndexBytes: Data) -> Data {
        tagged(51_997, array([
            unsigned(31_000_000),
            map([
                (unsigned(1), array([unsigned(1), unsigned(2)])),
                (unsigned(157), array([unsigned(118), unsigned(164)])),
                (unsigned(180), bytes([20])),
                (unsigned(176), map([
                    (unsigned(156), unsigned(160)),
                    (unsigned(168), byteString(protectedComponentIndexBytes))
                ])),
                (unsigned(174), map([
                    (unsigned(156), unsigned(166)),
                    (unsigned(196), bytes([21])),
                    (unsigned(198), unsigned(1))
                ])),
                (unsigned(182), map([
                    (unsigned(156), unsigned(108)),
                    (unsigned(204), unsigned(1)),
                    (unsigned(214), unsigned(220)),
                    (unsigned(216), byteString(Data([0x7a, 0x01, 0x02, 0x03]))),
                    (unsigned(218), bytes([22]))
                ]))
            ])
        ]))
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
