import Foundation

enum CredentialExpiration {
    static func isExpired(_ credential: DMVVerifiableCredential, now: Date = Date()) throws -> Bool {
        if let validUntil = credential.validUntil {
            if try hasExpired(validUntil, now: now) {
                return true
            }
        }
        if let proofExpires = credential.proof.expires {
            return try hasExpired(proofExpires, now: now)
        }
        return false
    }

    static func hasExpired(_ dateTime: String, now: Date) throws -> Bool {
        guard let expirationDate = CADMVDateTime.parse(dateTime) else {
            throw CADMVInternalError.unsupportedVCB
        }
        return now >= expirationDate
    }
}

enum CADMVDateTime {
    static func parse(_ dateTime: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateTime) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateTime)
    }
}
