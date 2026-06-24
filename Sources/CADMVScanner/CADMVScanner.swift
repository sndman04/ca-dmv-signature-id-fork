import CADMVVerifier
#if canImport(VisionKit)
import VisionKit
#endif

/// Raw PDF417 payload produced by a scanner.
///
/// This wrapper is an in-memory handoff boundary. It preserves the scanner
/// payload exactly so the verifier can parse AAMVA separators and VCB data.
///
/// The payload may contain PII. Do not log or persist this value unless the
/// integrating app has a separate legal basis and retention policy.
public struct CADMVScannedBarcode: Equatable, Sendable {
    public let rawPDF417: String

    public init(rawPDF417: String) {
        self.rawPDF417 = rawPDF417
    }

    /// Passes the raw payload to the core verifier without parsing public PII.
    public func verify(
        options: CADMVVerificationOptions = .default
    ) async -> CADMVVerificationResult {
        await CADMVVerifier.verify(rawPDF417: rawPDF417, options: options)
    }
}

/// Native scanner availability for the optional scanner target.
public enum CADMVScannerAvailability: Equatable, Sendable {
    case available
    case unavailable(String)
}

public enum CADMVScanner {
    /// Reports whether package-provided native camera scanning is available.
    public static var availability: CADMVScannerAvailability {
        #if os(iOS) && canImport(VisionKit)
        if #available(iOS 16.0, *) {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                return .available
            }
            return .unavailable("Native camera scanning is not available on this device.")
        }
        #endif
        return .unavailable("Native camera scanning is not available on this platform.")
    }
}
