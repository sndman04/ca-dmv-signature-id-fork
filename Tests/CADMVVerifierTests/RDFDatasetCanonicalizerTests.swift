@testable import CADMVVerifier
import XCTest

final class RDFDatasetCanonicalizerTests: XCTestCase {
    func testPinnedJSONLDTermRegistryMapsSupportedTerms() throws {
        XCTAssertEqual(
            try PinnedJSONLDTermRegistry.vcbTypeIRI("OpticalBarcodeCredential"),
            "https://w3id.org/vc-barcodes#OpticalBarcodeCredential"
        )
        XCTAssertEqual(
            try PinnedJSONLDTermRegistry.statusListTypeIRI("BitstringStatusListCredential"),
            "https://www.w3.org/ns/credentials/status#BitstringStatusListCredential"
        )
        XCTAssertEqual(
            try PinnedJSONLDTermRegistry.proofTypeIRI("DataIntegrityProof"),
            "https://w3id.org/security#DataIntegrityProof"
        )
        XCTAssertEqual(
            try PinnedJSONLDTermRegistry.vcbPredicate("terseStatusListIndex"),
            "https://w3id.org/vc-barcodes#terseStatusListIndex"
        )
        XCTAssertEqual(
            try PinnedJSONLDTermRegistry.statusListPredicate("encodedList"),
            "https://www.w3.org/ns/credentials/status#encodedList"
        )
        XCTAssertEqual(
            try PinnedJSONLDTermRegistry.proofPredicate("created"),
            "http://purl.org/dc/terms/created"
        )
        XCTAssertEqual(
            PinnedJSONLDTermRegistry.securityMultibaseDatatype,
            "https://w3id.org/security#multibase"
        )
        XCTAssertEqual(
            PinnedJSONLDTermRegistry.cryptosuiteStringDatatype,
            "https://w3id.org/security#cryptosuiteString"
        )
    }

    func testPinnedJSONLDTermRegistryRejectsUnsupportedTermsWithProfileErrors() {
        XCTAssertThrowsError(try PinnedJSONLDTermRegistry.vcbTypeIRI("UnknownCredential")) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }
        XCTAssertThrowsError(try PinnedJSONLDTermRegistry.statusListTypeIRI("UnknownStatusList")) { error in
            XCTAssertEqual(error as? CADMVInternalError, .statusListDecodeFailed)
        }
        XCTAssertThrowsError(try PinnedJSONLDTermRegistry.proofTypeIRI("UnknownProof")) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }
        XCTAssertThrowsError(try PinnedJSONLDTermRegistry.vcbPredicate("unknownSignedField")) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }
        XCTAssertThrowsError(try PinnedJSONLDTermRegistry.statusListPredicate("unknownSignedField")) { error in
            XCTAssertEqual(error as? CADMVInternalError, .statusListDecodeFailed)
        }
        XCTAssertThrowsError(try PinnedJSONLDTermRegistry.proofPredicate("proofValue")) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }
    }

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

    func testVCBDocumentCanonicalizationRoutesThroughConfiguredEngine() throws {
        let engine = RecordingJSONLDCanonicalizationEngine()
        let nquads = try VCBJSONLDRDFExpander.canonicalNQuads(
            vcbCredential(validFrom: "2026-01-01T00:00:00Z"),
            engine: engine
        )

        XCTAssertEqual(nquads, RecordingJSONLDCanonicalizationEngine.sentinelNQuads)
        XCTAssertEqual(engine.canonicalProfiles, [.vcbDocument])
        XCTAssertEqual(engine.canonicalDocuments.first?["validFrom"], .string("2026-01-01T00:00:00Z"))
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

    func testStatusListDocumentCanonicalizationRoutesThroughConfiguredEngine() throws {
        let engine = RecordingJSONLDCanonicalizationEngine()
        let nquads = try StatusListJSONLDRDFExpander.canonicalNQuads(
            statusListCredential(name: "Status List Credential"),
            engine: engine
        )

        XCTAssertEqual(nquads, RecordingJSONLDCanonicalizationEngine.sentinelNQuads)
        XCTAssertEqual(engine.canonicalProfiles, [.statusListDocument])
        XCTAssertEqual(engine.canonicalDocuments.first?["name"], .string("Status List Credential"))
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

    func testDataIntegrityProofCanonicalizerBuildsJSONLDDocumentBeforeRDFConversion() {
        let document = DataIntegrityProofCanonicalizer.jsonLDDocument(
            contexts: [
                "https://www.w3.org/ns/credentials/v2",
                "https://w3id.org/vc-barcodes/v1"
            ],
            type: "DataIntegrityProof",
            created: "2026-01-01T00:00:00Z",
            expires: "2030-01-01T00:00:00Z",
            cryptosuite: "ecdsa-xi-2023",
            proofPurpose: "assertionMethod",
            verificationMethod: "did:web:uat-credentials.dmv.ca.gov#vm-vcb-1"
        )

        XCTAssertEqual(document["@context"], .array([
            .string("https://www.w3.org/ns/credentials/v2"),
            .string("https://w3id.org/vc-barcodes/v1")
        ]))
        XCTAssertEqual(document["type"], .string("DataIntegrityProof"))
        XCTAssertEqual(document["cryptosuite"], .string("ecdsa-xi-2023"))
        XCTAssertEqual(document["created"], .string("2026-01-01T00:00:00Z"))
        XCTAssertEqual(document["expires"], .string("2030-01-01T00:00:00Z"))
    }

    func testProofCanonicalizationRoutesThroughConfiguredEngine() throws {
        let engine = RecordingJSONLDCanonicalizationEngine()
        let nquads = try DataIntegrityProofCanonicalizer.canonicalNQuads(
            contexts: [
                "https://www.w3.org/ns/credentials/v2",
                "https://w3id.org/vc-barcodes/v1"
            ],
            type: "DataIntegrityProof",
            created: "2026-01-01T00:00:00Z",
            expires: nil,
            cryptosuite: "ecdsa-xi-2023",
            proofPurpose: "assertionMethod",
            verificationMethod: "did:web:uat-credentials.dmv.ca.gov#vm-vcb-1",
            engine: engine
        )

        XCTAssertEqual(nquads, RecordingJSONLDCanonicalizationEngine.sentinelNQuads)
        XCTAssertEqual(engine.canonicalProfiles, [.dataIntegrityProof])
        XCTAssertEqual(engine.canonicalDocuments.first?["created"], .string("2026-01-01T00:00:00Z"))
    }

    func testSupportedProofJSONLDConverterRejectsUnsupportedContextTermsAndValues() throws {
        var document = DataIntegrityProofCanonicalizer.jsonLDDocument(
            type: "DataIntegrityProof",
            created: nil,
            expires: nil,
            cryptosuite: "ecdsa-rdfc-2019",
            proofPurpose: "assertionMethod",
            verificationMethod: "did:web:credentials.dmv.ca.gov#vm-status-1"
        )
        document["@context"] = .array([.string("https://example.invalid/context")])

        XCTAssertThrowsError(try SupportedProofJSONLDRDFConverter.quads(from: document)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }

        var unknownTermDocument = DataIntegrityProofCanonicalizer.jsonLDDocument(
            type: "DataIntegrityProof",
            created: nil,
            expires: nil,
            cryptosuite: "ecdsa-rdfc-2019",
            proofPurpose: "assertionMethod",
            verificationMethod: "did:web:credentials.dmv.ca.gov#vm-status-1"
        )
        unknownTermDocument["proofValue"] = .string("must-not-canonicalize")

        XCTAssertThrowsError(try SupportedProofJSONLDRDFConverter.quads(from: unknownTermDocument)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }

        var unsupportedCryptosuiteDocument = DataIntegrityProofCanonicalizer.jsonLDDocument(
            type: "DataIntegrityProof",
            created: nil,
            expires: nil,
            cryptosuite: "ecdsa-unknown-2026",
            proofPurpose: "assertionMethod",
            verificationMethod: "did:web:credentials.dmv.ca.gov#vm-status-1"
        )

        XCTAssertThrowsError(try SupportedProofJSONLDRDFConverter.quads(from: unsupportedCryptosuiteDocument)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }

        unsupportedCryptosuiteDocument["cryptosuite"] = .string("ecdsa-rdfc-2019")
        unsupportedCryptosuiteDocument["created"] = .string("2026-01-01T00:00:00Z\" .")

        XCTAssertThrowsError(try SupportedProofJSONLDRDFConverter.quads(from: unsupportedCryptosuiteDocument)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }
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

    func testNDegreeCanonicalizationFailsClosedWhenWorkBudgetIsExceeded() {
        let quads = (0..<129).map { index in
            RDFQuad(
                subject: .blank("node\(index)"),
                predicate: "https://example.com/predicate",
                object: .literal(value: "same-first-degree-hash", datatype: nil)
            )
        }

        XCTAssertThrowsError(try RDFDatasetCanonicalizer.canonicalNQuads(quads)) { error in
            XCTAssertEqual(error as? CADMVInternalError, .unsupportedVCB)
        }
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

    func testW3CRDFC10ConformanceSubset() throws {
        // Subset copied from the W3C RDFC-1.0 test suite. These cover the
        // current native RDF model surface: blank nodes, named graphs, shared
        // graph names, language/datatype literals, and duplicate input quads.
        let cases: [(id: String, input: String, expected: String)] = [
            (
                "test001c",
                "",
                ""
            ),
            (
                "test003c",
                """
                _:e0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://example.org/vocab#Foo> .

                """,
                """
                _:c14n0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://example.org/vocab#Foo> .

                """
            ),
            (
                "test020c",
                """
                <http://example.org/vocab#test> <http://example.org/vocab#A> _:e0 .
                <http://example.org/vocab#test> <http://example.org/vocab#B> _:e1 .
                _:e0 <http://example.org/vocab#next> _:e2 .
                _:e1 <http://example.org/vocab#next> _:e2 .

                """,
                """
                <http://example.org/vocab#test> <http://example.org/vocab#A> _:c14n2 .
                <http://example.org/vocab#test> <http://example.org/vocab#B> _:c14n0 .
                _:c14n0 <http://example.org/vocab#next> _:c14n1 .
                _:c14n2 <http://example.org/vocab#next> _:c14n1 .

                """
            ),
            (
                "test057c",
                """
                _:b1 <http://xmlns.com/foaf/0.1/homepage> <http://manu.sporny.org/> _:g .
                _:b1 <http://xmlns.com/foaf/0.1/name> "Manu Sporny" _:g .

                """,
                """
                _:c14n1 <http://xmlns.com/foaf/0.1/homepage> <http://manu.sporny.org/> _:c14n0 .
                _:c14n1 <http://xmlns.com/foaf/0.1/name> "Manu Sporny" _:c14n0 .

                """
            ),
            (
                "test070c",
                """
                <http://example.org/test> <http://example.org/vocab#A> _:e0 .
                <http://example.org/test> <http://example.org/vocab#B> _:e0 .
                <http://example.org/test> <http://example.org/vocab#embed> _:e0 .
                <http://example.org/test> <http://example.org/vocab#A> _:e1 <http://example.org/g1> .
                <http://example.org/test> <http://example.org/vocab#B> _:e1 <http://example.org/g1> .
                <http://example.org/test> <http://example.org/vocab#embed> _:e1 <http://example.org/g1> .

                """,
                """
                <http://example.org/test> <http://example.org/vocab#A> _:c14n0 .
                <http://example.org/test> <http://example.org/vocab#A> _:c14n1 <http://example.org/g1> .
                <http://example.org/test> <http://example.org/vocab#B> _:c14n0 .
                <http://example.org/test> <http://example.org/vocab#B> _:c14n1 <http://example.org/g1> .
                <http://example.org/test> <http://example.org/vocab#embed> _:c14n0 .
                <http://example.org/test> <http://example.org/vocab#embed> _:c14n1 <http://example.org/g1> .

                """
            ),
            (
                "test071c",
                """
                <http://example.org/test> <http://example.org/vocab#A> _:e0 .
                <http://example.org/test> <http://example.org/vocab#B> _:e0 .
                <http://example.org/test> <http://example.org/vocab#embed> _:e0 .
                <http://example.org/test> <http://example.org/vocab#A> _:e1 _:g1 .
                <http://example.org/test> <http://example.org/vocab#B> _:e1 _:g1 .
                <http://example.org/test> <http://example.org/vocab#embed> _:e1 _:g1 .

                """,
                """
                <http://example.org/test> <http://example.org/vocab#A> _:c14n0 .
                <http://example.org/test> <http://example.org/vocab#A> _:c14n2 _:c14n1 .
                <http://example.org/test> <http://example.org/vocab#B> _:c14n0 .
                <http://example.org/test> <http://example.org/vocab#B> _:c14n2 _:c14n1 .
                <http://example.org/test> <http://example.org/vocab#embed> _:c14n0 .
                <http://example.org/test> <http://example.org/vocab#embed> _:c14n2 _:c14n1 .

                """
            ),
            (
                "test072c",
                """
                <http://example.org/test> <http://example.org/vocab#A> _:e0 .
                <http://example.org/test> <http://example.org/vocab#B> _:e0 .
                <http://example.org/test> <http://example.org/vocab#embed> _:e0 .
                <http://example.org/test> <http://example.org/vocab#A> _:e0 <http://example.org/g1> .
                <http://example.org/test> <http://example.org/vocab#B> _:e0 <http://example.org/g1> .
                <http://example.org/test> <http://example.org/vocab#embed> _:e0 <http://example.org/g1> .

                """,
                """
                <http://example.org/test> <http://example.org/vocab#A> _:c14n0 .
                <http://example.org/test> <http://example.org/vocab#A> _:c14n0 <http://example.org/g1> .
                <http://example.org/test> <http://example.org/vocab#B> _:c14n0 .
                <http://example.org/test> <http://example.org/vocab#B> _:c14n0 <http://example.org/g1> .
                <http://example.org/test> <http://example.org/vocab#embed> _:c14n0 .
                <http://example.org/test> <http://example.org/vocab#embed> _:c14n0 <http://example.org/g1> .

                """
            ),
            (
                "test073c",
                """
                <http://example.org/test> <http://example.org/vocab#A> _:e0 .
                <http://example.org/test> <http://example.org/vocab#B> _:e0 .
                <http://example.org/test> <http://example.org/vocab#embed> _:e0 .
                <http://example.org/test> <http://example.org/vocab#graph> _:g1 .
                <http://example.org/test> <http://example.org/vocab#A> _:e0  _:g1 .
                <http://example.org/test> <http://example.org/vocab#B> _:e0 _:g1 .
                <http://example.org/test> <http://example.org/vocab#embed> _:e0 _:g1 .

                """,
                """
                <http://example.org/test> <http://example.org/vocab#A> _:c14n1 .
                <http://example.org/test> <http://example.org/vocab#A> _:c14n1 _:c14n0 .
                <http://example.org/test> <http://example.org/vocab#B> _:c14n1 .
                <http://example.org/test> <http://example.org/vocab#B> _:c14n1 _:c14n0 .
                <http://example.org/test> <http://example.org/vocab#embed> _:c14n1 .
                <http://example.org/test> <http://example.org/vocab#embed> _:c14n1 _:c14n0 .
                <http://example.org/test> <http://example.org/vocab#graph> _:c14n0 .

                """
            ),
            (
                "test043c",
                """
                <http://example.org/test> <http://example.org/vocab#test> "test"@en .

                """,
                """
                <http://example.org/test> <http://example.org/vocab#test> "test"@en .

                """
            ),
            (
                "test061c",
                """
                <http://example.com> <http://example.com/label> "test"@en .
                <http://example.com> <http://example.com/label> "test"@fr .

                """,
                """
                <http://example.com> <http://example.com/label> "test"@en .
                <http://example.com> <http://example.com/label> "test"@fr .

                """
            ),
            (
                "test062c",
                """
                <http://example.com> <http://example.com/label> "test"^^<http://example.com/t1> .
                <http://example.com> <http://example.com/label> "test"^^<http://example.com/t2> .

                """,
                """
                <http://example.com> <http://example.com/label> "test"^^<http://example.com/t1> .
                <http://example.com> <http://example.com/label> "test"^^<http://example.com/t2> .

                """
            ),
            (
                "test060c-core-escaping",
                """
                <urn:ex:s:000:s\\u20701> <urn:ex:000:p\\u2070> <urn:ex:000:o\\u2070> <urn:ex:000:g\\u2070> .
                <urn:ex:s:000:s⁰2> <urn:ex:000:p⁰> <urn:ex:000:o⁰> <urn:ex:000:g⁰> .
                <urn:ex:s:001> <urn:ex:000:empty> "" .
                <urn:ex:s:001> <urn:ex:001:simple> "simple" .
                <urn:ex:s:001> <urn:ex:002:quote> "\\"" .
                <urn:ex:s:001> <urn:ex:003:backslash> "\\\\" .
                <urn:ex:s:001> <urn:ex:004:nl> "\\n" .
                <urn:ex:s:001> <urn:ex:005:cr> "\\r" .
                <urn:ex:s:001> <urn:ex:006:all> "\\"\\\\\\n\\r" .
                <urn:ex:s:001> <urn:ex:007:uchar> "\\u0022\\u005c" .
                <urn:ex:s:001> <urn:ex:008:echar> "\\t\\b\\n\\r\\f\\"\\'\\\\" .
                <urn:ex:s:001> <urn:ex:009> "\\\\u0039" .
                <urn:ex:s:001> <urn:ex:010> "\\\\n" .
                <urn:ex:s:001> <urn:ex:011> "\\\\\\\\" .
                <urn:ex:s:001> <urn:ex:012> "\\"\\"" .
                <urn:ex:s:001> <urn:ex:015> "\\u221e" .
                <urn:ex:s:001> <urn:ex:016> "∞" .
                <urn:ex:s:001> <urn:ex:017> <urn:ex:\\u0065\\u0078> .
                <urn:ex:s:001> <urn:ex:018> <urn:ex:\\u221e> .
                <urn:ex:s:001> <urn:ex:019> <urn:ex:\\u002b> .
                <urn:ex:s:003> <urn:ex:022> "d"^^<urn:ex:\\u0064\\u0074> .
                <urn:ex:s:003> <urn:ex:023> "d"^^<urn:ex:\\u0064> .
                <urn:ex:s:004> <urn:ex:024> "\\u0000\\u0001\\u0002\\u0003\\u0004\\u0005\\u0006\\u0007\\u0008\\u0009\\u000a\\u000b\\u000c\\u000d\\u000e\\u000f" .
                <urn:ex:s:004> <urn:ex:025> "\\u0010\\u0011\\u0012\\u0013\\u0014\\u0015\\u0016\\u0017\\u0018\\u0019\\u001a\\u001b\\u001c\\u001d\\u001e\\u001f" .
                <urn:ex:s:004> <urn:ex:026> "\\u0020\\u0021\\u0022\\u0023\\u0024\\u0025\\u0026\\u0027\\u0028\\u0029\\u002a\\u002b\\u002c\\u002d\\u002e\\u002f" .
                <urn:ex:s:004> <urn:ex:027> "\\u0030\\u0031\\u0032\\u0033\\u0034\\u0035\\u0036\\u0037\\u0038\\u0039\\u003a\\u003b\\u003c\\u003d\\u003e\\u003f" .
                <urn:ex:s:004> <urn:ex:028> "\\u0040\\u0041\\u0042\\u0043\\u0044\\u0045\\u0046\\u0047\\u0048\\u0049\\u004a\\u004b\\u004c\\u004d\\u004e\\u004f" .
                <urn:ex:s:004> <urn:ex:029> "\\u0050\\u0051\\u0052\\u0053\\u0054\\u0055\\u0056\\u0057\\u0058\\u0059\\u005a\\u005b\\u005c\\u005d\\u005e\\u005f" .
                <urn:ex:s:004> <urn:ex:030> "\\u0060\\u0061\\u0062\\u0063\\u0064\\u0065\\u0066\\u0067\\u0068\\u0069\\u006a\\u006b\\u006c\\u006d\\u006e\\u006f" .
                <urn:ex:s:004> <urn:ex:031> "\\u0070\\u0071\\u0072\\u0073\\u0074\\u0075\\u0076\\u0077\\u0078\\u0079\\u007a\\u007b\\u007c\\u007d\\u007e\\u007f" .
                <urn:ex:s:004> <urn:ex:033> "\\U0001F303" .
                <urn:ex:s:004> <urn:ex:034> "🌃" .
                <urn:ex:s:005> <urn:ex:035> <urn:ex:\\U0001F303> .
                <urn:ex:s:006> <urn:ex:036> "o" <urn:ex:\\u221e> .
                <urn:ex:s:006> <urn:ex:037> "o" <urn:ex:∞> .
                <urn:ex:s:006> <urn:ex:039> "\\u0009\\u0020<>\\"{}|^`\\\\" .

                """,
                """
                <urn:ex:s:000:s⁰1> <urn:ex:000:p⁰> <urn:ex:000:o⁰> <urn:ex:000:g⁰> .
                <urn:ex:s:000:s⁰2> <urn:ex:000:p⁰> <urn:ex:000:o⁰> <urn:ex:000:g⁰> .
                <urn:ex:s:001> <urn:ex:000:empty> "" .
                <urn:ex:s:001> <urn:ex:001:simple> "simple" .
                <urn:ex:s:001> <urn:ex:002:quote> "\\"" .
                <urn:ex:s:001> <urn:ex:003:backslash> "\\\\" .
                <urn:ex:s:001> <urn:ex:004:nl> "\\n" .
                <urn:ex:s:001> <urn:ex:005:cr> "\\r" .
                <urn:ex:s:001> <urn:ex:006:all> "\\"\\\\\\n\\r" .
                <urn:ex:s:001> <urn:ex:007:uchar> "\\"\\\\" .
                <urn:ex:s:001> <urn:ex:008:echar> "\\t\\b\\n\\r\\f\\"'\\\\" .
                <urn:ex:s:001> <urn:ex:009> "\\\\u0039" .
                <urn:ex:s:001> <urn:ex:010> "\\\\n" .
                <urn:ex:s:001> <urn:ex:011> "\\\\\\\\" .
                <urn:ex:s:001> <urn:ex:012> "\\"\\"" .
                <urn:ex:s:001> <urn:ex:015> "∞" .
                <urn:ex:s:001> <urn:ex:016> "∞" .
                <urn:ex:s:001> <urn:ex:017> <urn:ex:ex> .
                <urn:ex:s:001> <urn:ex:018> <urn:ex:∞> .
                <urn:ex:s:001> <urn:ex:019> <urn:ex:+> .
                <urn:ex:s:003> <urn:ex:022> "d"^^<urn:ex:dt> .
                <urn:ex:s:003> <urn:ex:023> "d"^^<urn:ex:d> .
                <urn:ex:s:004> <urn:ex:024> "\\u0000\\u0001\\u0002\\u0003\\u0004\\u0005\\u0006\\u0007\\b\\t\\n\\u000B\\f\\r\\u000E\\u000F" .
                <urn:ex:s:004> <urn:ex:025> "\\u0010\\u0011\\u0012\\u0013\\u0014\\u0015\\u0016\\u0017\\u0018\\u0019\\u001A\\u001B\\u001C\\u001D\\u001E\\u001F" .
                <urn:ex:s:004> <urn:ex:026> " !\\"#$%&'()*+,-./" .
                <urn:ex:s:004> <urn:ex:027> "0123456789:;<=>?" .
                <urn:ex:s:004> <urn:ex:028> "@ABCDEFGHIJKLMNO" .
                <urn:ex:s:004> <urn:ex:029> "PQRSTUVWXYZ[\\\\]^_" .
                <urn:ex:s:004> <urn:ex:030> "`abcdefghijklmno" .
                <urn:ex:s:004> <urn:ex:031> "pqrstuvwxyz{|}~\\u007F" .
                <urn:ex:s:004> <urn:ex:033> "🌃" .
                <urn:ex:s:004> <urn:ex:034> "🌃" .
                <urn:ex:s:005> <urn:ex:035> <urn:ex:🌃> .
                <urn:ex:s:006> <urn:ex:036> "o" <urn:ex:∞> .
                <urn:ex:s:006> <urn:ex:037> "o" <urn:ex:∞> .
                <urn:ex:s:006> <urn:ex:039> "\\t <>\\"{}|^`\\\\" .

                """
            ),
            (
                "test076c",
                """
                <https://www.example.org/s> <https://www.example.org/p> <https://www.example.org/o> .
                <https://www.example.org/s> <https://www.example.org/p> <https://www.example.org/o> .

                """,
                """
                <https://www.example.org/s> <https://www.example.org/p> <https://www.example.org/o> .

                """
            ),
            (
                "test077c",
                """
                <https://www.example.org/s> <https://www.example.org/p> _:o .
                <https://www.example.org/s> <https://www.example.org/p> _:o .

                """,
                """
                <https://www.example.org/s> <https://www.example.org/p> _:c14n0 .

                """
            )
        ]

        for testCase in cases {
            XCTAssertEqual(
                try RDFDatasetCanonicalizer.canonicalNQuads(parseNQuads(testCase.input)),
                testCase.expected,
                testCase.id
            )
        }
    }

    func testW3CRDFC10IssuedIdentifierMapSubset() throws {
        let cases: [(id: String, input: String, expected: [String: String])] = [
            (
                "test003m",
                """
                _:e0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://example.org/vocab#Foo> .

                """,
                ["e0": "c14n0"]
            ),
            (
                "test020m",
                """
                <http://example.org/vocab#test> <http://example.org/vocab#A> _:e0 .
                <http://example.org/vocab#test> <http://example.org/vocab#B> _:e1 .
                _:e0 <http://example.org/vocab#next> _:e2 .
                _:e1 <http://example.org/vocab#next> _:e2 .

                """,
                ["e1": "c14n0", "e2": "c14n1", "e0": "c14n2"]
            ),
            (
                "test057m",
                """
                _:b1 <http://xmlns.com/foaf/0.1/homepage> <http://manu.sporny.org/> _:g .
                _:b1 <http://xmlns.com/foaf/0.1/name> "Manu Sporny" _:g .

                """,
                ["g": "c14n0", "b1": "c14n1"]
            ),
            (
                "test070m",
                """
                <http://example.org/test> <http://example.org/vocab#A> _:e0 .
                <http://example.org/test> <http://example.org/vocab#B> _:e0 .
                <http://example.org/test> <http://example.org/vocab#embed> _:e0 .
                <http://example.org/test> <http://example.org/vocab#A> _:e1 <http://example.org/g1> .
                <http://example.org/test> <http://example.org/vocab#B> _:e1 <http://example.org/g1> .
                <http://example.org/test> <http://example.org/vocab#embed> _:e1 <http://example.org/g1> .

                """,
                ["e0": "c14n0", "e1": "c14n1"]
            ),
            (
                "test071m",
                """
                <http://example.org/test> <http://example.org/vocab#A> _:e0 .
                <http://example.org/test> <http://example.org/vocab#B> _:e0 .
                <http://example.org/test> <http://example.org/vocab#embed> _:e0 .
                <http://example.org/test> <http://example.org/vocab#A> _:e1 _:g1 .
                <http://example.org/test> <http://example.org/vocab#B> _:e1 _:g1 .
                <http://example.org/test> <http://example.org/vocab#embed> _:e1 _:g1 .

                """,
                ["e0": "c14n0", "g1": "c14n1", "e1": "c14n2"]
            ),
            (
                "test072m",
                """
                <http://example.org/test> <http://example.org/vocab#A> _:e0 .
                <http://example.org/test> <http://example.org/vocab#B> _:e0 .
                <http://example.org/test> <http://example.org/vocab#embed> _:e0 .
                <http://example.org/test> <http://example.org/vocab#A> _:e0 <http://example.org/g1> .
                <http://example.org/test> <http://example.org/vocab#B> _:e0 <http://example.org/g1> .
                <http://example.org/test> <http://example.org/vocab#embed> _:e0 <http://example.org/g1> .

                """,
                ["e0": "c14n0"]
            ),
            (
                "test073m",
                """
                <http://example.org/test> <http://example.org/vocab#A> _:e0 .
                <http://example.org/test> <http://example.org/vocab#B> _:e0 .
                <http://example.org/test> <http://example.org/vocab#embed> _:e0 .
                <http://example.org/test> <http://example.org/vocab#graph> _:g1 .
                <http://example.org/test> <http://example.org/vocab#A> _:e0  _:g1 .
                <http://example.org/test> <http://example.org/vocab#B> _:e0 _:g1 .
                <http://example.org/test> <http://example.org/vocab#embed> _:e0 _:g1 .

                """,
                ["g1": "c14n0", "e0": "c14n1"]
            )
        ]

        for testCase in cases {
            XCTAssertEqual(
                try RDFDatasetCanonicalizer.canonicalIdentifierMap(parseNQuads(testCase.input)),
                testCase.expected,
                testCase.id
            )
        }
    }

    func testW3CRDFC10NegativeCliqueGraphFailsClosed() {
        let quads = (0..<10).flatMap { subjectIndex in
            (0..<10).map { objectIndex in
                RDFQuad(
                    subject: .blank("e\(subjectIndex)"),
                    predicate: "http:/example.com/p",
                    object: .blank("e\(objectIndex)")
                )
            }
        }

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

    private func parseNQuads(_ text: String) throws -> [RDFQuad] {
        try text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .compactMap { lineNumber, rawLine -> RDFQuad? in
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                guard !line.isEmpty else {
                    return nil
                }
                do {
                    var parser = NQuadsLineParser(line)
                    return try parser.parseQuad()
                } catch {
                    XCTFail("Failed to parse N-Quads fixture line \(lineNumber + 1): \(line)")
                    throw error
                }
            }
    }
}

private final class RecordingJSONLDCanonicalizationEngine: JSONLDCanonicalizationEngine, @unchecked Sendable {
    static let sentinelNQuads = "<https://example.com/subject> <https://example.com/predicate> \"sentinel\" .\n"

    private(set) var canonicalDocuments: [[String: SupportedJSONLDValue]] = []
    private(set) var canonicalProfiles: [SupportedJSONLDCanonicalizationProfile] = []

    func canonicalNQuads(
        document: [String: SupportedJSONLDValue],
        profile: SupportedJSONLDCanonicalizationProfile
    ) throws -> String {
        canonicalDocuments.append(document)
        canonicalProfiles.append(profile)
        return Self.sentinelNQuads
    }

    func quads(
        from document: [String: SupportedJSONLDValue],
        profile: SupportedJSONLDCanonicalizationProfile
    ) throws -> [RDFQuad] {
        canonicalDocuments.append(document)
        canonicalProfiles.append(profile)
        return [
            RDFQuad(
                subject: .iri("https://example.com/subject"),
                predicate: "https://example.com/predicate",
                object: .literal(value: "sentinel", datatype: nil)
            )
        ]
    }
}

private struct NQuadsLineParser {
    private let line: String
    private var index: String.Index

    init(_ line: String) {
        self.line = line
        self.index = line.startIndex
    }

    mutating func parseQuad() throws -> RDFQuad {
        let subject = try parseTerm()
        try skipSpaces()
        let predicate = try parseIRI()
        try skipSpaces()
        let object = try parseTerm()
        try skipSpaces()
        let graph: RDFTerm?
        if peek() == "." {
            graph = nil
        } else {
            graph = try parseTerm()
            try skipSpaces()
        }
        try consume(".")
        try skipSpaces()
        guard index == line.endIndex else {
            throw CADMVInternalError.unsupportedVCB
        }
        return RDFQuad(
            subject: subject,
            predicate: predicate,
            object: object,
            graph: graph
        )
    }

    private mutating func parseTerm() throws -> RDFTerm {
        try skipSpaces()
        if peek() == "<" {
            return .iri(try parseIRI())
        }
        if line[index...].hasPrefix("_:") {
            try consume("_:")
            return .blank(try consumeIdentifier())
        }
        if peek() == "\"" {
            let value = try parseLiteral()
            if line[index...].hasPrefix("@") {
                try consume("@")
                return .languageLiteral(value: value, language: try consumeIdentifier())
            }
            if line[index...].hasPrefix("^^") {
                try consume("^^")
                return .literal(value: value, datatype: try parseIRI())
            }
            return .literal(value: value, datatype: nil)
        }
        throw CADMVInternalError.unsupportedVCB
    }

    private mutating func parseIRI() throws -> String {
        try consume("<")
        var iri = ""
        while index < line.endIndex, line[index] != ">" {
            if line[index] == "\\" {
                iri.append(try parseEscape())
            } else {
                iri.append(line[index])
                index = line.index(after: index)
            }
        }
        guard index < line.endIndex else {
            throw CADMVInternalError.unsupportedVCB
        }
        try consume(">")
        return iri
    }

    private mutating func parseLiteral() throws -> String {
        try consume("\"")
        var value = ""
        while index < line.endIndex {
            let character = line[index]
            if character == "\"" {
                index = line.index(after: index)
                return value
            }
            if character == "\\" {
                value.append(try parseEscape())
            } else {
                value.append(character)
                index = line.index(after: index)
            }
        }
        throw CADMVInternalError.unsupportedVCB
    }

    private mutating func parseEscape() throws -> Character {
        try consume("\\")
        guard index < line.endIndex else {
            throw CADMVInternalError.unsupportedVCB
        }
        let escaped = line[index]
        index = line.index(after: index)
        switch escaped {
        case "\"", "'", "\\":
            return escaped
        case "n":
            return "\n"
        case "r":
            return "\r"
        case "t":
            return "\t"
        case "b":
            return "\u{08}"
        case "f":
            return "\u{0C}"
        case "u":
            return try parseUnicodeEscape(hexDigitCount: 4)
        case "U":
            return try parseUnicodeEscape(hexDigitCount: 8)
        default:
            throw CADMVInternalError.unsupportedVCB
        }
    }

    private mutating func parseUnicodeEscape(hexDigitCount: Int) throws -> Character {
        var hex = ""
        for _ in 0..<hexDigitCount {
            guard index < line.endIndex, line[index].isHexDigit else {
                throw CADMVInternalError.unsupportedVCB
            }
            hex.append(line[index])
            index = line.index(after: index)
        }
        guard let value = UInt32(hex, radix: 16),
              let scalar = UnicodeScalar(value) else {
            throw CADMVInternalError.unsupportedVCB
        }
        return Character(scalar)
    }

    private mutating func consumeIdentifier() throws -> String {
        let start = index
        while index < line.endIndex, !line[index].isWhitespace, line[index] != "." {
            index = line.index(after: index)
        }
        guard start != index else {
            throw CADMVInternalError.unsupportedVCB
        }
        return String(line[start..<index])
    }

    private mutating func consume(_ text: String) throws {
        guard line[index...].hasPrefix(text) else {
            throw CADMVInternalError.unsupportedVCB
        }
        index = line.index(index, offsetBy: text.count)
    }

    private mutating func skipSpaces() throws {
        while index < line.endIndex, line[index].isWhitespace {
            index = line.index(after: index)
        }
    }

    private func peek() -> Character? {
        index < line.endIndex ? line[index] : nil
    }
}
