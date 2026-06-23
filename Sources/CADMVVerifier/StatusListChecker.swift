import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum StatusListChecker {
    private static let terseBitstringStatusListLength: UInt64 = 67_108_864

    static func check(
        credential: DMVVerifiableCredential,
        mode: CADMVVerificationMode,
        timeoutSeconds: Double
    ) async -> CADMVStatusCheckResult {
        guard let status = credential.credentialStatus,
              status.type == "TerseBitstringStatusListEntry",
              let location = statusListLocation(for: status),
              isAllowed(url: location.url, mode: mode) else {
            return .unavailable
        }

        var request = URLRequest(url: location.url)
        request.timeoutInterval = timeoutSeconds

        do {
            let (data, response) = try await CADMVNetworkSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return .unavailable
            }

            let statusListCredential = try DMVStatusListCredentialParser.parse(data)
            let key = try await DIDWebResolver.resolveVerificationMethod(
                id: statusListCredential.proof.verificationMethod,
                mode: mode,
                timeoutSeconds: timeoutSeconds
            )
            return try evaluate(
                statusListCredential: statusListCredential,
                expectedURL: location.url,
                statusListIndex: location.statusListIndex,
                credentialIssuer: credential.issuer,
                verificationKey: key
            )
        } catch {
            return .unavailable
        }
    }

    static func statusListURL(for status: DMVVerifiableCredential.CredentialStatus) -> URL? {
        statusListLocation(for: status)?.url
    }

    static func evaluate(
        statusListCredential: DMVStatusListCredential,
        expectedURL: URL,
        statusListIndex: UInt64,
        credentialIssuer: String,
        verificationKey: DIDDocumentKey
    ) throws -> CADMVStatusCheckResult {
        guard statusListCredential.id == expectedURL.absoluteString,
              statusListCredential.issuer == credentialIssuer,
              statusListCredential.credentialSubject.statusPurpose == "revocation" else {
            return .unavailable
        }

        guard try EcdsaRdfc2019Verifier.verify(
            credential: statusListCredential,
            verificationKey: verificationKey
        ) else {
            return .unavailable
        }

        guard let status = try BitstringStatusListDecoder.status(
            in: statusListCredential.credentialSubject.encodedList,
            at: statusListIndex
        ) else {
            return .unavailable
        }
        return status ? .revoked : .notRevoked
    }

    static func statusListLocation(
        for status: DMVVerifiableCredential.CredentialStatus
    ) -> CADMVStatusListLocation? {
        let listIndex = status.terseStatusListIndex / terseBitstringStatusListLength
        let statusListIndex = status.terseStatusListIndex % terseBitstringStatusListLength
        guard let url = URL(string: "\(status.terseStatusListBaseURL)/revocation/\(listIndex)") else {
            return nil
        }
        return CADMVStatusListLocation(
            url: url,
            listIndex: listIndex,
            statusListIndex: statusListIndex
        )
    }

    private static func isAllowed(url: URL, mode: CADMVVerificationMode) -> Bool {
        guard url.scheme == "https", let host = url.host else {
            return false
        }

        switch mode {
        case .production:
            return host == "api.credentials.dmv.ca.gov"
        case .uat:
            return host == "api.uat-credentials.dmv.ca.gov"
        }
    }
}

enum BitstringStatusListDecoder {
    static func status(in encodedList: String, at index: UInt64) throws -> Bool? {
        guard encodedList.first == "u",
              let compressed = Base64URL.decode(String(encodedList.dropFirst())) else {
            throw CADMVInternalError.statusListDecodeFailed
        }
        return status(in: try Gzip.decompress(compressed), at: index)
    }

    static func status(in uncompressedBytes: Data, at index: UInt64) -> Bool? {
        let byteIndex = index / 8
        guard byteIndex <= UInt64(Int.max),
              Int(byteIndex) < uncompressedBytes.count else {
            return nil
        }
        let bitOffset = UInt8(index % 8)
        let mask = UInt8(1 << (7 - bitOffset))
        return (uncompressedBytes[Int(byteIndex)] & mask) != 0
    }
}

enum CADMVStatusCheckResult: Equatable, Sendable {
    case notRevoked
    case revoked
    case unavailable
}

struct CADMVStatusListLocation: Equatable, Sendable {
    let url: URL
    let listIndex: UInt64
    let statusListIndex: UInt64
}
