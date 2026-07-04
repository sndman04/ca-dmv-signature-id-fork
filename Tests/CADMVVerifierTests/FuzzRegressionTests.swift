@_spi(Testing) @testable import CADMVVerifier
import Foundation
import XCTest

final class FuzzRegressionTests: XCTestCase {
    func testCBORAndVCBDecodersHandleDeterministicMalformedSeeds() {
        let seeds = fixedMalformedCBORSeeds() + generatedByteSeeds(count: 192, maximumLength: 96)

        for (index, seed) in seeds.enumerated() {
            XCTAssertNoThrow(try assertCBORSeedIsBounded(seed), "CBOR seed \(index) escaped bounded handling")
            XCTAssertNoThrow(try assertVCBSeedFailsClosed(seed), "VCB seed \(index) escaped fail-closed handling")
        }
    }

    func testAAMVAParserHandlesDeterministicScannerPayloadSeeds() {
        let parser = AAMVADocumentParser()

        for (index, seed) in scannerPayloadSeeds().enumerated() {
            do {
                _ = try parser.parse(rawPDF417: seed)
            } catch let error as CADMVInternalError {
                XCTAssertEqual(error, .malformedBarcode, "Scanner seed \(index) failed with unexpected internal error")
            } catch {
                XCTFail("Scanner seed \(index) failed with unexpected error: \(error)")
            }
        }
    }

    func testPublicVerifierMapsMalformedFuzzSeedsToPrivacySafeResults() async {
        for (index, seed) in scannerPayloadSeeds().prefix(64).enumerated() {
            let result = await CADMVVerifier.verify(rawPDF417: seed)

            XCTAssertNotEqual(result.status, .verified, "Malformed scanner seed \(index) verified")
            XCTAssertNil(result.message?.range(of: seed))
            XCTAssertNotNil(result.failureReason, "Malformed scanner seed \(index) omitted a privacy-safe reason")
        }
    }

    private func assertCBORSeedIsBounded(_ seed: Data) throws {
        do {
            _ = try CBORReader.decode(seed)
        } catch CADMVInternalError.malformedCBOR, CADMVInternalError.unsupportedCBOR {
            return
        } catch {
            XCTFail("Unexpected CBOR error: \(error)")
        }
    }

    private func assertVCBSeedFailsClosed(_ seed: Data) throws {
        do {
            _ = try DMVVCBDecoder.decode(seed)
            XCTFail("Malformed VCB seed decoded successfully")
        } catch CADMVInternalError.malformedCBOR,
                CADMVInternalError.unsupportedCBOR,
                CADMVInternalError.unsupportedVCB {
            return
        } catch {
            XCTFail("Unexpected VCB decode error: \(error)")
        }
    }

    private func fixedMalformedCBORSeeds() -> [Data] {
        [
            Data(),
            Data([0x18]),
            Data([0x19, 0x00]),
            Data([0x1a, 0x00, 0x00]),
            Data([0x1b, 0x00, 0x00, 0x00]),
            Data([0x3b, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
            Data([0x5f, 0xff]),
            Data([0x7f, 0xff]),
            Data([0x9f, 0x01, 0xff]),
            Data([0xbf, 0x01, 0x02, 0xff]),
            Data([0x82, 0x01]),
            Data([0xa2, 0x01, 0x02]),
            Data([0xa2, 0x01, 0x02, 0x01, 0x03]),
            Data([0xc2]),
            Data([0xd9, 0xcb, 0x1d]),
            Data([0xd9, 0xcb, 0x1d, 0x82, 0x1a, 0x01]),
            Data([0xf9, 0x3c, 0x00]),
            Data([0xfa, 0x3f, 0x80, 0x00, 0x00]),
            Data([0xfb, 0x3f, 0xf0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),
            Data([0xff])
        ]
    }

    private func generatedByteSeeds(count: Int, maximumLength: Int) -> [Data] {
        var generator = DeterministicGenerator(state: 0x4341_444d_565f_465a)
        return (0..<count).map { index in
            let length = index % (maximumLength + 1)
            return Data((0..<length).map { _ in generator.nextByte() })
        }
    }

    private func scannerPayloadSeeds() -> [String] {
        var generator = DeterministicGenerator(state: 0x5044_4634_3137_465a)
        var seeds = [
            "",
            "ANSI",
            "ANSI ",
            "ANSI 636014",
            "\\u{001e}\\rANSI 636014010102DL00000000",
            "@\\n\\u{001e}\\rANSI 636014010102DL00000000DLDAQ",
            "ANSI 636014010102DL00000010DL0001",
            "ANSI 636014010102DL99999999DL0001",
            "ANSI 636014010102DL00000004DLDAJCA",
            "\\u{001e}\\rANSI 636014010102DL00000020DLDAQSYNTHETIC\\r"
        ]

        let alphabet = Array("ANSI 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz\\{}_-:\r\n\t")
        for index in 0..<192 {
            let length = index % 96
            var value = ""
            value.reserveCapacity(length)
            for _ in 0..<length {
                value.append(alphabet[Int(generator.nextUInt64() % UInt64(alphabet.count))])
            }
            if index % 3 == 0 {
                value.insert(contentsOf: "ANSI ", at: value.startIndex)
            }
            seeds.append(value)
        }
        return seeds
    }
}

private struct DeterministicGenerator {
    private var state: UInt64

    init(state: UInt64) {
        self.state = state
    }

    mutating func nextByte() -> UInt8 {
        UInt8(truncatingIfNeeded: nextUInt64() >> 32)
    }

    mutating func nextUInt64() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
