@testable import CADMVVerifier
import XCTest

final class RDFDatasetCanonicalizerTests: XCTestCase {
    func testVCBJSONLDExpanderBuildsDocumentQuadsFromCredentialModel() throws {
        let nquads = try VCBJSONLDRDFExpander.canonicalNQuads(vcbCredential(
            validFrom: "2026-01-01T00:00:00Z",
            validUntil: "2030-01-01T00:00:00Z"
        ))

        XCTAssert(nquads.contains("<https://www.w3.org/2018/credentials#VerifiableCredential>"))
        XCTAssert(nquads.contains("<https://w3id.org/vc-barcodes#OpticalBarcodeCredential>"))
        XCTAssert(nquads.contains("<did:web:uat-credentials.dmv.ca.gov>"))
        XCTAssert(nquads.contains("\"uAQID\"^^<https://w3id.org/security#multibase>"))
        XCTAssert(nquads.contains("<https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists>"))
        XCTAssert(nquads.contains("\"1\"^^<http://www.w3.org/2001/XMLSchema#integer>"))
        XCTAssert(nquads.contains("\"2026-01-01T00:00:00Z\"^^<http://www.w3.org/2001/XMLSchema#dateTime>"))
        XCTAssert(nquads.contains("\"2030-01-01T00:00:00Z\"^^<http://www.w3.org/2001/XMLSchema#dateTime>"))
    }

    func testVCBJSONLDExpanderOmitsAbsentStatusAndValidityDates() throws {
        let quads = try VCBJSONLDRDFExpander.documentQuads(vcbCredential(
            credentialStatus: nil
        ))

        XCTAssertEqual(quads.count, 6)
        XCTAssertFalse(quads.contains {
            $0.predicate == "https://www.w3.org/2018/credentials#credentialStatus"
        })
        XCTAssertFalse(quads.contains {
            $0.predicate == "https://www.w3.org/2018/credentials#validFrom"
        })
        XCTAssertFalse(quads.contains {
            $0.predicate == "https://www.w3.org/2018/credentials#validUntil"
        })
    }

    func testVCBJSONLDExpanderBuildsJSONLDDocumentBeforeRDFConversion() {
        let document = VCBJSONLDRDFExpander.jsonLDDocument(from: vcbCredential(
            validFrom: "2026-01-01T00:00:00Z"
        ))

        XCTAssertEqual(document["@context"], .array([
            .string("https://www.w3.org/ns/credentials/v2"),
            .string("https://w3id.org/vc-barcodes/v1")
        ]))
        XCTAssertEqual(document["issuer"], .string("did:web:uat-credentials.dmv.ca.gov"))
        XCTAssertEqual(document["validFrom"], .string("2026-01-01T00:00:00Z"))
    }

    func testSupportedJSONLDConverterRejectsUnsupportedContextAndTerms() throws {
        var document = VCBJSONLDRDFExpander.jsonLDDocument(from: vcbCredential())
        document["@context"] = .array([.string("https://example.invalid/context")])

        XCTAssertThrowsError(try SupportedJSONLDRDFConverter.quads(from: document)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }

        var unknownTermDocument = VCBJSONLDRDFExpander.jsonLDDocument(from: vcbCredential())
        unknownTermDocument["unknownSignedField"] = .string("must-not-drop")

        XCTAssertThrowsError(try SupportedJSONLDRDFConverter.quads(from: unknownTermDocument)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }

        var unknownTypeDocument = VCBJSONLDRDFExpander.jsonLDDocument(from: vcbCredential())
        unknownTypeDocument["type"] = .array([.string("VerifiableCredential"), .string("UnknownCredential")])

        XCTAssertThrowsError(try SupportedJSONLDRDFConverter.quads(from: unknownTypeDocument)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }
    }

    func testStatusListJSONLDExpanderBuildsDocumentQuadsFromCredentialModel() throws {
        let credential = statusListCredential(
            validFrom: "2026-01-01T00:00:00Z",
            validUntil: "2030-01-01T00:00:00Z",
            name: "Status List Credential",
            description: "Revocation status list"
        )
        let document = StatusListJSONLDRDFExpander.jsonLDDocument(from: credential)
        let nquads = try StatusListJSONLDRDFExpander.canonicalNQuads(credential)

        XCTAssertEqual(document["@context"], .array([
            .string("https://www.w3.org/ns/credentials/v2")
        ]))
        XCTAssertEqual(document["id"], .string("https://example.com/status/1"))
        XCTAssertEqual(document["issuer"], .string("did:web:credentials.dmv.ca.gov"))
        XCTAssert(nquads.contains("<https://www.w3.org/2018/credentials#VerifiableCredential>"))
        XCTAssert(nquads.contains("<https://www.w3.org/ns/credentials/status#BitstringStatusListCredential>"))
        XCTAssert(nquads.contains("<https://www.w3.org/ns/credentials/status#BitstringStatusList>"))
        XCTAssert(nquads.contains("\"uH4sIAAAAAAAAA2NhAAD717UlAgAAAA\"^^<https://w3id.org/security#multibase>"))
        XCTAssert(nquads.contains("\"revocation\""))
        XCTAssert(nquads.contains("\"Status List Credential\""))
        XCTAssert(nquads.contains("\"Revocation status list\""))
        XCTAssert(nquads.contains("\"2026-01-01T00:00:00Z\"^^<http://www.w3.org/2001/XMLSchema#dateTime>"))
        XCTAssert(nquads.contains("\"2030-01-01T00:00:00Z\"^^<http://www.w3.org/2001/XMLSchema#dateTime>"))
    }

    func testStatusListJSONLDExpanderOmitsAbsentOptionalFields() throws {
        let quads = try StatusListJSONLDRDFExpander.documentQuads(statusListCredential())

        XCTAssertEqual(quads.count, 7)
        XCTAssertFalse(quads.contains {
            $0.predicate == "https://schema.org/name"
        })
        XCTAssertFalse(quads.contains {
            $0.predicate == "https://schema.org/description"
        })
        XCTAssertFalse(quads.contains {
            $0.predicate == "https://www.w3.org/2018/credentials#validFrom"
        })
        XCTAssertFalse(quads.contains {
            $0.predicate == "https://www.w3.org/2018/credentials#validUntil"
        })
    }

    func testStatusListJSONLDConverterRejectsUnsupportedContextTermsAndTypes() throws {
        var document = StatusListJSONLDRDFExpander.jsonLDDocument(from: statusListCredential())
        document["@context"] = .array([.string("https://example.invalid/context")])

        XCTAssertThrowsError(try SupportedStatusListJSONLDRDFConverter.quads(from: document)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .statusListDecodeFailed)
        }

        var unknownTermDocument = StatusListJSONLDRDFExpander.jsonLDDocument(from: statusListCredential())
        unknownTermDocument["unknownSignedField"] = .string("must-not-drop")

        XCTAssertThrowsError(try SupportedStatusListJSONLDRDFConverter.quads(from: unknownTermDocument)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .statusListDecodeFailed)
        }

        var unknownTypeDocument = StatusListJSONLDRDFExpander.jsonLDDocument(from: statusListCredential())
        unknownTypeDocument["type"] = .array([.string("VerifiableCredential"), .string("UnknownCredential")])

        XCTAssertThrowsError(try SupportedStatusListJSONLDRDFConverter.quads(from: unknownTypeDocument)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .statusListDecodeFailed)
        }

        var unsafeDateDocument = StatusListJSONLDRDFExpander.jsonLDDocument(from: statusListCredential())
        unsafeDateDocument["validFrom"] = .string("2026-01-01T00:00:00Z\" .")

        XCTAssertThrowsError(try SupportedStatusListJSONLDRDFConverter.quads(from: unsafeDateDocument)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .statusListDecodeFailed)
        }
    }

    func testDataIntegrityProofCanonicalizerIncludesOptionalCreatedAndExpires() throws {
        let nquads = try DataIntegrityProofCanonicalizer.canonicalNQuads(
            type: "DataIntegrityProof",
            created: "2024-05-20T00:00:00Z",
            expires: "2026-05-20T00:00:00Z",
            cryptosuite: "ecdsa-xi-2023",
            proofPurpose: "assertionMethod",
            verificationMethod: "did:web:credentials.dmv.ca.gov#vm-vcb-1"
        )

        XCTAssertEqual(nquads, """
        _:c14n0 <http://purl.org/dc/terms/created> "2024-05-20T00:00:00Z"^^<http://www.w3.org/2001/XMLSchema#dateTime> .
        _:c14n0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://w3id.org/security#DataIntegrityProof> .
        _:c14n0 <https://w3id.org/security#cryptosuite> "ecdsa-xi-2023"^^<https://w3id.org/security#cryptosuiteString> .
        _:c14n0 <https://w3id.org/security#expiration> "2026-05-20T00:00:00Z"^^<http://www.w3.org/2001/XMLSchema#dateTime> .
        _:c14n0 <https://w3id.org/security#proofPurpose> <https://w3id.org/security#assertionMethod> .
        _:c14n0 <https://w3id.org/security#verificationMethod> <did:web:credentials.dmv.ca.gov#vm-vcb-1> .

        """)
    }

    func testDataIntegrityProofCanonicalizerOmitsAbsentOptionalDates() throws {
        let nquads = try DataIntegrityProofCanonicalizer.canonicalNQuads(
            type: "DataIntegrityProof",
            created: nil,
            expires: nil,
            cryptosuite: "ecdsa-rdfc-2019",
            proofPurpose: "assertionMethod",
            verificationMethod: "did:web:credentials.dmv.ca.gov#vm-status-1"
        )

        XCTAssertEqual(nquads, """
        _:c14n0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://w3id.org/security#DataIntegrityProof> .
        _:c14n0 <https://w3id.org/security#cryptosuite> "ecdsa-rdfc-2019"^^<https://w3id.org/security#cryptosuiteString> .
        _:c14n0 <https://w3id.org/security#proofPurpose> <https://w3id.org/security#assertionMethod> .
        _:c14n0 <https://w3id.org/security#verificationMethod> <did:web:credentials.dmv.ca.gov#vm-status-1> .

        """)
    }

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

    func testSharedFirstDegreeHashesUseNDegreeCanonicalization() throws {
        let quads = [
            RDFQuad(
                subject: .iri("http://example.com/#p"),
                predicate: "http://example.com/#q",
                object: .blank("e0")
            ),
            RDFQuad(
                subject: .iri("http://example.com/#p"),
                predicate: "http://example.com/#q",
                object: .blank("e1")
            ),
            RDFQuad(
                subject: .blank("e0"),
                predicate: "http://example.com/#p",
                object: .blank("e2")
            ),
            RDFQuad(
                subject: .blank("e1"),
                predicate: "http://example.com/#p",
                object: .blank("e3")
            ),
            RDFQuad(
                subject: .blank("e2"),
                predicate: "http://example.com/#r",
                object: .blank("e3")
            )
        ]

        XCTAssertEqual(try RDFDatasetCanonicalizer.canonicalNQuads(quads), """
        <http://example.com/#p> <http://example.com/#q> _:c14n2 .
        <http://example.com/#p> <http://example.com/#q> _:c14n3 .
        _:c14n0 <http://example.com/#r> _:c14n1 .
        _:c14n2 <http://example.com/#p> _:c14n1 .
        _:c14n3 <http://example.com/#p> _:c14n0 .

        """)
    }

    func testCanonicalizerRendersNamedGraphIRI() throws {
        let nquads = try RDFDatasetCanonicalizer.canonicalNQuads([
            RDFQuad(
                subject: .iri("https://example.com/subject"),
                predicate: "https://example.com/predicate",
                object: .literal(value: "value", datatype: nil),
                graph: .iri("https://example.com/graph")
            )
        ])

        XCTAssertEqual(nquads, """
        <https://example.com/subject> <https://example.com/predicate> "value" <https://example.com/graph> .

        """)
    }

    func testCanonicalizerIncludesBlankGraphNamesInCanonicalLabels() throws {
        let nquads = try RDFDatasetCanonicalizer.canonicalNQuads([
            RDFQuad(
                subject: .iri("https://example.com/subject"),
                predicate: "https://example.com/predicate",
                object: .literal(value: "first", datatype: nil),
                graph: .blank("graphA")
            ),
            RDFQuad(
                subject: .blank("subject"),
                predicate: "https://example.com/predicate",
                object: .literal(value: "second", datatype: nil),
                graph: .blank("graphA")
            )
        ])

        XCTAssertEqual(nquads, """
        <https://example.com/subject> <https://example.com/predicate> "first" _:c14n1 .
        _:c14n0 <https://example.com/predicate> "second" _:c14n1 .

        """)
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

    private func vcbCredential(
        credentialStatus: DMVVerifiableCredential.CredentialStatus? = DMVVerifiableCredential.CredentialStatus(
            type: "TerseBitstringStatusListEntry",
            terseStatusListBaseURL: "https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists",
            terseStatusListIndex: 1
        ),
        validFrom: String? = nil,
        validUntil: String? = nil
    ) -> DMVVerifiableCredential {
        DMVVerifiableCredential(
            context: [
                "https://www.w3.org/ns/credentials/v2",
                "https://w3id.org/vc-barcodes/v1"
            ],
            type: [
                "VerifiableCredential",
                "OpticalBarcodeCredential"
            ],
            issuer: "did:web:uat-credentials.dmv.ca.gov",
            validFrom: validFrom,
            validUntil: validUntil,
            credentialSubject: DMVVerifiableCredential.CredentialSubject(
                type: "AamvaDriversLicenseScannableInformation",
                protectedComponentIndex: "uAQID"
            ),
            credentialStatus: credentialStatus,
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
    }

    private func statusListCredential(
        validFrom: String? = nil,
        validUntil: String? = nil,
        name: String? = nil,
        description: String? = nil
    ) -> DMVStatusListCredential {
        DMVStatusListCredential(
            id: "https://example.com/status/1",
            type: [
                "VerifiableCredential",
                "BitstringStatusListCredential"
            ],
            issuer: "did:web:credentials.dmv.ca.gov",
            validFrom: validFrom,
            validUntil: validUntil,
            name: name,
            description: description,
            credentialSubject: DMVStatusListCredential.CredentialSubject(
                id: "https://example.com/status/1#list",
                type: "BitstringStatusList",
                encodedList: "uH4sIAAAAAAAAA2NhAAD717UlAgAAAA",
                statusPurpose: "revocation"
            ),
            proof: DMVStatusListCredential.Proof(
                type: "DataIntegrityProof",
                created: "2026-01-01T00:00:00Z",
                verificationMethod: "did:web:credentials.dmv.ca.gov#vm-status-1",
                cryptosuite: "ecdsa-rdfc-2019",
                proofPurpose: "assertionMethod",
                proofValue: "zLdp"
            )
        )
    }
}
