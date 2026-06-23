import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct DIDDocumentKey: Equatable, Sendable {
    let id: String
    let controller: String
    let type: String
    let publicKeyMultibase: String
    let compressedP256Key: Data
}

enum DIDWebResolver {
    static func resolveVerificationMethod(
        id verificationMethod: String,
        mode: CADMVVerificationMode,
        timeoutSeconds: Double
    ) async throws -> DIDDocumentKey {
        let policy = DIDWebPolicy(mode: mode)
        guard verificationMethod.hasPrefix(policy.did + "#") else {
            throw CADMVInternalError.didResolutionFailed
        }

        let url = policy.didDocumentURL
        var request = URLRequest(url: url)
        request.timeoutInterval = timeoutSeconds
        let (data, response) = try await CADMVNetworkSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw CADMVInternalError.didResolutionFailed
        }

        let json = try JSONSerialization.jsonObject(with: data)
        guard let root = json as? [String: Any],
              root["id"] as? String == policy.did,
              let verificationMethods = root["verificationMethod"] as? [[String: Any]],
              let assertionMethods = root["assertionMethod"] as? [String],
              assertionMethods.contains(verificationMethod),
              let method = verificationMethods.first(where: { $0["id"] as? String == verificationMethod }) else {
            throw CADMVInternalError.didResolutionFailed
        }

        return try parseKey(method, expectedController: policy.did)
    }

    private static func parseKey(
        _ method: [String: Any],
        expectedController: String
    ) throws -> DIDDocumentKey {
        guard let id = method["id"] as? String,
              let controller = method["controller"] as? String,
              controller == expectedController,
              let type = method["type"] as? String,
              type == "Multikey",
              let publicKeyMultibase = method["publicKeyMultibase"] as? String else {
            throw CADMVInternalError.unsupportedDIDKey
        }

        let compressedKey = try compressedP256Key(from: publicKeyMultibase)
        return DIDDocumentKey(
            id: id,
            controller: controller,
            type: type,
            publicKeyMultibase: publicKeyMultibase,
            compressedP256Key: compressedKey
        )
    }

    private static func compressedP256Key(from publicKeyMultibase: String) throws -> Data {
        guard publicKeyMultibase.first == "z",
              let decoded = Base58BTC.decode(String(publicKeyMultibase.dropFirst())),
              decoded.count == 35,
              decoded[decoded.startIndex] == 0x80,
              decoded[decoded.index(after: decoded.startIndex)] == 0x24 else {
            throw CADMVInternalError.unsupportedDIDKey
        }
        return decoded.dropFirst(2)
    }
}

private struct DIDWebPolicy {
    let did: String
    let didDocumentURL: URL

    init(mode: CADMVVerificationMode) {
        switch mode {
        case .production:
            did = "did:web:credentials.dmv.ca.gov"
            didDocumentURL = URL(string: "https://credentials.dmv.ca.gov/.well-known/did.json")!
        case .uat:
            did = "did:web:uat-credentials.dmv.ca.gov"
            didDocumentURL = URL(string: "https://uat-credentials.dmv.ca.gov/.well-known/did.json")!
        }
    }
}
