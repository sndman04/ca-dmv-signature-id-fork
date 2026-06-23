import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum CADMVNetworkSession {
    typealias DataHandler = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        return URLSession(
            configuration: configuration,
            delegate: NoRedirectDelegate(),
            delegateQueue: nil
        )
    }()
    private static let testTransport = CADMVTestNetworkTransport()

    static func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let handler = await testTransport.handler {
            return try await handler(request)
        }
        return try await session.data(for: request)
    }

    static func setTestHandler(_ handler: DataHandler?) async {
        await testTransport.setHandler(handler)
    }
}

private actor CADMVTestNetworkTransport {
    var handler: CADMVNetworkSession.DataHandler?

    func setHandler(_ handler: CADMVNetworkSession.DataHandler?) {
        self.handler = handler
    }
}

private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
