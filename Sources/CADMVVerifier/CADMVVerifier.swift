import Foundation

/// Privacy-minimized verification outcome for a California DMV DL/ID barcode.
public enum CADMVVerificationStatus: Equatable, Sendable {
    /// The DMV digital-signature verification passed.
    case verified
    /// Verification failed, or required signed data was malformed or unsupported.
    case failed
    /// A California DMV digital signature was not present or not applicable.
    case notPresent
    /// The credential status list indicates revocation.
    case revoked
    /// The credential is expired.
    case expired
    /// Required online verification infrastructure was temporarily unavailable.
    case unavailable
}

/// Privacy-safe diagnostic reason for a non-verified result.
///
/// These reasons intentionally avoid raw barcode data, parsed identity fields,
/// proof values, DID documents, and status-list contents.
public enum CADMVVerificationFailureReason: Equatable, Sendable {
    case malformedBarcode
    case notCaliforniaDMV
    case vcbMissing(required: Bool)
    case vcbBase64Invalid
    case vcbCBORUnsupported
    case unsupportedCredentialProfile
    case environmentMismatch(expected: CADMVVerificationMode)
    case protectedAAMVADataUnavailable
    case didResolutionFailed
    case signatureMismatch
    case statusUnavailable
    case revoked
    case expired
}

/// Privacy-minimized result safe for normal app control flow and UI messaging.
public struct CADMVVerificationResult: Equatable, Sendable {
    public let status: CADMVVerificationStatus
    public let message: String?
    public let failureReason: CADMVVerificationFailureReason?

    public init(
        status: CADMVVerificationStatus,
        message: String? = nil,
        failureReason: CADMVVerificationFailureReason? = nil
    ) {
        self.status = status
        self.message = message
        self.failureReason = failureReason
    }
}

/// Verification controls that do not expose or retain parsed identity data.
public struct CADMVVerificationOptions: Sendable {
    /// Require VCB data even for documents issued before the DMV requirement date.
    public var requireVCB: Bool
    /// Check revocation/status infrastructure when cryptographic verification is available.
    public var checkStatus: Bool
    /// DMV environment to enforce for issuers, DID documents, and status hosts.
    public var mode: CADMVVerificationMode
    /// Network timeout for online DID/status checks.
    public var networkTimeoutSeconds: Double

    public init(
        requireVCB: Bool = false,
        checkStatus: Bool = false,
        mode: CADMVVerificationMode = .production,
        networkTimeoutSeconds: Double = 10
    ) {
        self.requireVCB = requireVCB
        self.checkStatus = checkStatus
        self.mode = mode
        self.networkTimeoutSeconds = networkTimeoutSeconds
    }

    public static let `default` = CADMVVerificationOptions()
}

/// DMV environment selection.
public enum CADMVVerificationMode: Equatable, Sendable {
    case production
    case uat
}

public enum CADMVVerifier {
    /// Verifies already scanned raw PDF417 barcode data.
    ///
    /// Pass the full scanner-provided payload, such as
    /// `AVMetadataMachineReadableCodeObject.stringValue`, without parsing and
    /// reconstructing it or normalizing AAMVA separator characters. Trimming
    /// leading/trailing whitespace and newlines is tolerated.
    ///
    /// The raw barcode may contain PII. This API does not log, persist, or
    /// expose parsed identity fields. When status checking is required but
    /// DMV status infrastructure is unavailable, the result is `.unavailable`.
    public static func verify(
        rawPDF417: String,
        options: CADMVVerificationOptions = .default
    ) async -> CADMVVerificationResult {
        do {
            return try await VerificationPipeline(options: options)
                .verify(rawPDF417: rawPDF417)
        } catch CADMVInternalError.malformedBarcode {
            return VerificationMessages.result(
                for: .failed,
                failureReason: .malformedBarcode
            )
        } catch {
            return VerificationMessages.result(
                for: .failed,
                failureReason: .unsupportedCredentialProfile
            )
        }
    }
}
