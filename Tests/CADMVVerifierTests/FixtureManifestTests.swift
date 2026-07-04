import Foundation
import XCTest

final class FixtureManifestTests: XCTestCase {
    func testFixtureManifestCoversRequiredPhaseTwoCategories() throws {
        let manifest = try fixtureManifest()
        let fixtures = try XCTUnwrap(manifest["fixtures"] as? [[String: Any]])
        let categories = Set(fixtures.flatMap { fixture -> [String] in
            fixture["categories"] as? [String] ?? []
        })

        let missing = requiredPhaseTwoCategories.subtracting(categories)

        XCTAssertTrue(missing.isEmpty, "Missing fixture manifest categories: \(missing.sorted())")
    }

    func testFixtureManifestDoesNotAllowCommittedPrivateData() throws {
        let manifest = try fixtureManifest()
        let policy = try XCTUnwrap(manifest["policy"] as? [String: Any])
        let fixtures = try XCTUnwrap(manifest["fixtures"] as? [[String: Any]])

        XCTAssertEqual(policy["rawRealPayloadsCommitted"] as? Bool, false)
        XCTAssertEqual(policy["realPIICommitted"] as? Bool, false)

        for fixture in fixtures {
            XCTAssertNil(fixture["rawPDF417"], "Manifest must not contain raw PDF417 data.")
            XCTAssertNil(fixture["parsedAAMVA"], "Manifest must not contain parsed AAMVA data.")
            XCTAssertNil(fixture["proofValue"], "Manifest must not contain proof values.")
        }
    }

    func testDocumentedGapsHaveReasons() throws {
        let manifest = try fixtureManifest()
        let fixtures = try XCTUnwrap(manifest["fixtures"] as? [[String: Any]])
        let documentedGaps = fixtures.filter {
            $0["storageLevel"] as? String == "documented-gap"
        }

        for fixture in documentedGaps {
            let reason = fixture["gapReason"] as? String
            XCTAssertFalse(reason?.isEmpty ?? true, "Documented gaps must explain why coverage is not materialized.")
        }
    }

    private func fixtureManifest() throws -> [String: Any] {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "fixture-manifest",
            withExtension: "json"
        ))
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private var requiredPhaseTwoCategories: Set<String> {
        [
            "valid-production-credential-shape",
            "valid-uat",
            "signature-mismatch-proof",
            "missing-vcb-before-requirement",
            "missing-vcb-after-requirement",
            "require-vcb-before-requirement",
            "non-california-issuer",
            "california-issuer-non-ca-daj",
            "dl-primary-subfile",
            "id-primary-subfile",
            "multiple-subfiles-valid-offsets",
            "malformed-subfile-descriptors",
            "unknown-subfile-designators",
            "escaped-scanner-control-characters",
            "raw-control-characters",
            "segment-terminator-variants",
            "empty-payload",
            "payload-missing-ansi",
            "truncated-header",
            "truncated-descriptors",
            "invalid-issue-dates",
            "boundary-issue-dates",
            "leap-year-dates",
            "impossible-dates",
            "malformed-base64-vcb",
            "base64-with-scanner-whitespace",
            "cborld-valid-minimal-dmv-credential",
            "unsupported-cborld-registry",
            "unknown-ignorable-cborld-values",
            "duplicate-cbor-map-keys",
            "oversized-cbor-array-declaration",
            "oversized-cbor-map-declaration",
            "deeply-nested-cbor",
            "unsupported-credential-contexts",
            "unsupported-credential-types",
            "unsupported-proof-types",
            "unsupported-cryptosuites",
            "unsupported-proof-purposes",
            "uat-credential-in-production-mode",
            "production-credential-in-uat-mode",
            "did-resolution-timeout",
            "did-document-missing-verification-method",
            "did-document-key-type-mismatch",
            "did-document-host-redirect",
            "did-document-malformed-json",
            "did-document-wrong-controller",
            "did-document-multiple-verification-methods",
            "did-document-unsupported-key-type",
            "status-checking-disabled",
            "status-checking-enabled-not-revoked",
            "status-checking-enabled-revoked",
            "status-checking-enabled-unavailable",
            "status-list-credential-proof-invalid",
            "status-list-profile-unknown-signed-fields",
            "status-list-bit-index-0",
            "status-list-bit-index-7",
            "status-list-bit-index-8",
            "status-list-bit-index-63",
            "status-list-bit-index-64",
            "status-list-bit-index-last",
            "status-list-bit-index-out-of-range",
            "credential-before-expiration",
            "credential-exactly-at-expiration",
            "credential-after-expiration",
            "credential-malformed-expiration-date",
            "proof-expires-and-validUntil"
        ]
    }
}
