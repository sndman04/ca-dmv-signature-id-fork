#if os(iOS) && canImport(VisionKit) && canImport(UIKit)
import CADMVVerifier
import UIKit
import VisionKit

@available(iOS 16.0, *)
@MainActor
public final class CADMVVisionKitPDF417Scanner: NSObject {
    public typealias ScanHandler = @MainActor (CADMVScannedBarcode) -> Void

    private let onScan: ScanHandler
    private lazy var scanner = DataScannerViewController(
        recognizedDataTypes: [.barcode(symbologies: [.pdf417])],
        qualityLevel: .balanced,
        recognizesMultipleItems: false,
        isHighFrameRateTrackingEnabled: false,
        isHighlightingEnabled: true
    )

    public init(onScan: @escaping ScanHandler) {
        self.onScan = onScan
        super.init()
        scanner.delegate = self
    }

    public var viewController: UIViewController {
        scanner
    }

    public func startScanning() throws {
        try scanner.startScanning()
    }

    public func stopScanning() {
        scanner.stopScanning()
    }
}

@available(iOS 16.0, *)
extension CADMVVisionKitPDF417Scanner: DataScannerViewControllerDelegate {
    public func dataScanner(
        _ dataScanner: DataScannerViewController,
        didAdd addedItems: [RecognizedItem],
        allItems: [RecognizedItem]
    ) {
        for item in addedItems {
            guard case let .barcode(barcode) = item,
                  barcode.observation.symbology == .pdf417,
                  let payload = barcode.payloadStringValue,
                  !payload.isEmpty else {
                continue
            }
            onScan(CADMVScannedBarcode(rawPDF417: payload))
            return
        }
    }
}
#endif
