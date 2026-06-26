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
        request.timeoutInterval = CADMVNetworkSession.normalizedTimeout(timeoutSeconds)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await CADMVNetworkSession.data(for: request)
        } catch is CancellationError {
            throw CADMVInternalError.didResolutionFailed
        } catch {
            throw CADMVInternalError.didResolutionFailed
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw CADMVInternalError.didResolutionFailed
        }

        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw CADMVInternalError.didResolutionFailed
        }

        guard let root = json as? [String: Any],
              root["id"] as? String == policy.did,
              let method = verificationMethodObject(
                  in: root,
                  id: verificationMethod,
                  did: policy.did
              ) else {
            throw CADMVInternalError.didResolutionFailed
        }

        return try parseKey(
            method,
            expectedID: verificationMethod,
            expectedController: policy.did
        )
    }

    private static func verificationMethodObject(
        in root: [String: Any],
        id verificationMethod: String,
        did: String
    ) -> [String: Any]? {
        guard let assertionMethods = root["assertionMethod"] as? [Any] else {
            return nil
        }

        let assertionMethodObjects = assertionMethods.compactMap { value -> [String: Any]? in
            guard let method = value as? [String: Any],
                  normalizedDIDURL(method["id"] as? String, did: did) == verificationMethod else {
                return nil
            }
            return method
        }
        if let embeddedMethod = assertionMethodObjects.first {
            return embeddedMethod
        }

        let assertionMethodIDs = assertionMethods.compactMap { value -> String? in
            guard let id = value as? String else {
                return nil
            }
            return normalizedDIDURL(id, did: did)
        }
        guard assertionMethodIDs.contains(verificationMethod),
              let verificationMethods = root["verificationMethod"] as? [[String: Any]] else {
            return nil
        }

        return verificationMethods.first {
            normalizedDIDURL($0["id"] as? String, did: did) == verificationMethod
        }
    }

    private static func parseKey(
        _ method: [String: Any],
        expectedID: String,
        expectedController: String
    ) throws -> DIDDocumentKey {
        guard let id = normalizedDIDURL(method["id"] as? String, did: expectedController),
              id == expectedID,
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

    private static func normalizedDIDURL(_ value: String?, did: String) -> String? {
        guard let value else {
            return nil
        }
        if value.hasPrefix("#") {
            return did + value
        }
        if value.hasPrefix(did + "#") {
            return value
        }
        return nil
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
