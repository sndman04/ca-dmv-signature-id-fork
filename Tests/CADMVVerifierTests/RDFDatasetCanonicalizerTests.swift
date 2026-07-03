@testable import CADMVVerifier
import XCTest

final class RDFDatasetCanonicalizerTests: XCTestCase {
    func testProductionStatusIndexCanSortBeforeSubjectBlankNode() throws {
        let nquads = try RDFDatasetCanonicalizer.canonicalNQuads(productionCredentialQuads(
            statusListIndex: 2_663_386_499
        ))

        XCTAssert(nquads.contains("_:c14n0 <https://w3id.org/vc-barcodes#terseStatusListIndex> \"2663386499\"^^<http://www.w3.org/2001/XMLSchema#integer> ."))
        XCTAssert(nquads.contains("_:c14n1 <https://w3id.org/vc-barcodes#protectedComponentIndex> \"u_3Bg\"^^<https://w3id.org/security#multibase> ."))
        XCTAssert(nquads.contains("_:c14n2 <https://www.w3.org/2018/credentials#credentialStatus> _:c14n0 ."))
        XCTAssert(nquads.contains("_:c14n2 <https://www.w3.org/2018/credentials#credentialSubject> _:c14n1 ."))
    }

    func testProductionStatusIndexCanSortAfterSubjectBlankNode() throws {
        let nquads = try RDFDatasetCanonicalizer.canonicalNQuads(productionCredentialQuads(
            statusListIndex: 2_619_630_330
        ))

        XCTAssert(nquads.contains("_:c14n0 <https://w3id.org/vc-barcodes#protectedComponentIndex> \"u_3Bg\"^^<https://w3id.org/security#multibase> ."))
        XCTAssert(nquads.contains("_:c14n1 <https://w3id.org/vc-barcodes#terseStatusListIndex> \"2619630330\"^^<http://www.w3.org/2001/XMLSchema#integer> ."))
        XCTAssert(nquads.contains("_:c14n2 <https://www.w3.org/2018/credentials#credentialStatus> _:c14n1 ."))
        XCTAssert(nquads.contains("_:c14n2 <https://www.w3.org/2018/credentials#credentialSubject> _:c14n0 ."))
    }

    func testAmbiguousBlankNodeHashesFailClosed() {
        let quads = [
            RDFQuad(
                subject: .blank("first"),
                predicate: "https://example.com/value",
                object: .literal(value: "same", datatype: nil)
            ),
            RDFQuad(
                subject: .blank("second"),
                predicate: "https://example.com/value",
                object: .literal(value: "same", datatype: nil)
            )
        ]

        XCTAssertThrowsError(try RDFDatasetCanonicalizer.canonicalNQuads(quads)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }
    }

    private func productionCredentialQuads(statusListIndex: UInt64) -> [RDFQuad] {
        [
            RDFQuad(
                subject: .blank("root"),
                predicate: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type",
                object: .iri("https://w3id.org/vc-barcodes#OpticalBarcodeCredential")
            ),
            RDFQuad(
                subject: .blank("root"),
                predicate: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type",
                object: .iri("https://www.w3.org/2018/credentials#VerifiableCredential")
            ),
            RDFQuad(
                subject: .blank("root"),
                predicate: "https://www.w3.org/2018/credentials#credentialStatus",
                object: .blank("status")
            ),
            RDFQuad(
                subject: .blank("root"),
                predicate: "https://www.w3.org/2018/credentials#credentialSubject",
                object: .blank("subject")
            ),
            RDFQuad(
                subject: .blank("root"),
                predicate: "https://www.w3.org/2018/credentials#issuer",
                object: .iri("did:web:credentials.dmv.ca.gov")
            ),
            RDFQuad(
                subject: .blank("subject"),
                predicate: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type",
                object: .iri("https://w3id.org/vc-barcodes#AamvaDriversLicenseScannableInformation")
            ),
            RDFQuad(
                subject: .blank("subject"),
                predicate: "https://w3id.org/vc-barcodes#protectedComponentIndex",
                object: .literal(value: "u_3Bg", datatype: "https://w3id.org/security#multibase")
            ),
            RDFQuad(
                subject: .blank("status"),
                predicate: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type",
                object: .iri("https://w3id.org/vc-barcodes#TerseBitstringStatusListEntry")
            ),
            RDFQuad(
                subject: .blank("status"),
                predicate: "https://w3id.org/vc-barcodes#terseStatusListBaseUrl",
                object: .iri("https://api.credentials.dmv.ca.gov/status/dlid/1/status-lists")
            ),
            RDFQuad(
                subject: .blank("status"),
                predicate: "https://w3id.org/vc-barcodes#terseStatusListIndex",
                object: .literal(
                    value: String(statusListIndex),
                    datatype: "http://www.w3.org/2001/XMLSchema#integer"
                )
            )
        ]
    }
}
