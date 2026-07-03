@_spi(Testing) import CADMVVerifier
import Foundation

@main
enum CADMVVerifierOracle {
    static func main() async throws {
        let arguments = CommandLine.arguments.dropFirst()
        if boolOption("--status-list-verify-data", in: arguments) {
            try runStatusListVerifyDataOracle()
            return
        }

        let mode = optionValue("--mode", in: arguments) == "uat"
            ? CADMVVerificationMode.uat
            : CADMVVerificationMode.production
        let requireVCB = boolOption("--require-vcb", in: arguments)
        let checkStatus = boolOption("--verify-status", in: arguments)
        let payload = String(
            decoding: FileHandle.standardInput.readDataToEndOfFile(),
            as: UTF8.self
        )

        let result = await CADMVVerifier.verify(
            rawPDF417: payload,
            options: CADMVVerificationOptions(
                requireVCB: requireVCB,
                checkStatus: checkStatus,
                mode: mode
            )
        )
        let inspection = try? CADMVVerifier.inspectForSelfTest(rawPDF417: payload)

        let output: [String: Any?] = [
            "implementation": "swift",
            "input": "stdin",
            "mode": modeName(mode),
            "requireVcb": requireVCB,
            "verifyStatus": checkStatus,
            "result": [
                "status": statusName(result.status),
                "verified": result.status == .verified,
                "firstFailureStage": firstFailureStage(result.failureReason),
                "failureReason": failureReasonName(result.failureReason),
                "issuerAccepted": inspection?.issuerAccepted,
                "vcbRequired": inspection?.vcbRequired,
                "vcbPresent": inspection?.vcbPresent,
                "vcbByteLength": inspection?.decodedVCBByteCount,
                "credentialProfile": inspection.map {
                    [
                        "uatCredentialShapeValid": $0.uatCredentialShapeValid,
                        "productionCredentialShapeValid": $0.productionCredentialShapeValid,
                        "statusListPresent": $0.statusListURL != nil
                    ]
                },
                "aamvaHashHex": inspection?.opticalDataHashHex,
                "verifyDataHex": inspection?.verifyDataHex,
                "statusListIndexPresent": inspection?.statusListIndex != nil
            ] as [String: Any?]
        ]

        let normalized = normalize(output)
        let data = try JSONSerialization.data(
            withJSONObject: normalized,
            options: [.prettyPrinted, .sortedKeys]
        )
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private static func runStatusListVerifyDataOracle() throws {
        let payload = FileHandle.standardInput.readDataToEndOfFile()
        let output: [String: Any?] = [
            "implementation": "swift",
            "input": "stdin",
            "result": [
                "verifyDataHex": try CADMVVerifier.statusListVerifyDataForSelfTest(jsonData: payload)
            ] as [String: Any?]
        ]
        let data = try JSONSerialization.data(
            withJSONObject: normalize(output),
            options: [.prettyPrinted, .sortedKeys]
        )
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private static func optionValue(
        _ name: String,
        in arguments: some Sequence<String>
    ) -> String? {
        for argument in arguments {
            if argument.hasPrefix("\(name)=") {
                return String(argument.dropFirst(name.count + 1))
            }
        }
        return nil
    }

    private static func boolOption(
        _ name: String,
        in arguments: some Sequence<String>
    ) -> Bool {
        for argument in arguments {
            if argument == name {
                return true
            }
            if argument.hasPrefix("\(name)=") {
                let value = argument.dropFirst(name.count + 1).lowercased()
                return ["1", "true", "yes"].contains(value)
            }
        }
        return false
    }

    private static func normalize(_ value: Any?) -> Any {
        switch value {
        case .none:
            return NSNull()
        case let dictionary as [String: Any?]:
            return dictionary.mapValues(normalize(_:))
        case let array as [Any?]:
            return array.map(normalize(_:))
        case let value?:
            return value
        }
    }

    private static func modeName(_ mode: CADMVVerificationMode) -> String {
        switch mode {
        case .production:
            return "prod"
        case .uat:
            return "uat"
        }
    }

    private static func statusName(_ status: CADMVVerificationStatus) -> String {
        switch status {
        case .verified:
            return "verified"
        case .failed:
            return "failed"
        case .notPresent:
            return "notPresent"
        case .revoked:
            return "revoked"
        case .expired:
            return "expired"
        case .unavailable:
            return "unavailable"
        }
    }

    private static func failureReasonName(
        _ reason: CADMVVerificationFailureReason?
    ) -> String? {
        guard let reason else {
            return nil
        }
        switch reason {
        case .malformedBarcode:
            return "malformedBarcode"
        case .notCaliforniaDMV:
            return "notCaliforniaDMV"
        case let .vcbMissing(required):
            return "vcbMissing(required: \(required))"
        case .vcbBase64Invalid:
            return "vcbBase64Invalid"
        case .vcbCBORUnsupported:
            return "vcbCBORUnsupported"
        case .unsupportedCredentialProfile:
            return "unsupportedCredentialProfile"
        case let .environmentMismatch(expected):
            return "environmentMismatch(expected: \(modeName(expected)))"
        case .protectedAAMVADataUnavailable:
            return "protectedAAMVADataUnavailable"
        case .didResolutionFailed:
            return "didResolutionFailed"
        case .signatureMismatch:
            return "signatureMismatch"
        case .statusUnavailable:
            return "statusUnavailable"
        case .revoked:
            return "revoked"
        case .expired:
            return "expired"
        }
    }

    private static func firstFailureStage(
        _ reason: CADMVVerificationFailureReason?
    ) -> String? {
        guard let reason else {
            return nil
        }
        switch reason {
        case .malformedBarcode, .notCaliforniaDMV:
            return "aamva-applicability"
        case .vcbMissing:
            return "vcb-discovery"
        case .vcbBase64Invalid, .vcbCBORUnsupported:
            return "cborld-decode"
        case .unsupportedCredentialProfile, .environmentMismatch:
            return "credential-validation"
        case .protectedAAMVADataUnavailable:
            return "aamva-protected-data"
        case .didResolutionFailed:
            return "did-resolution"
        case .signatureMismatch:
            return "data-integrity-vcb"
        case .statusUnavailable:
            return "data-integrity-status-list"
        case .revoked:
            return "status-bit"
        case .expired:
            return "expiration"
        }
    }
}
