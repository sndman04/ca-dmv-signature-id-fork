enum VerificationMessages {
    static func result(for status: CADMVVerificationStatus) -> CADMVVerificationResult {
        CADMVVerificationResult(status: status, message: message(for: status))
    }

    static func message(for status: CADMVVerificationStatus) -> String {
        switch status {
        case .verified:
            "DMV digital-signature verification passed."
        case .failed:
            "DMV digital-signature verification failed."
        case .notPresent:
            "California DMV digital signature is not present."
        case .revoked:
            "This DMV digital credential has been revoked."
        case .expired:
            "This DMV digital credential is expired."
        case .unavailable:
            "DMV digital-signature verification is temporarily unavailable."
        }
    }
}
