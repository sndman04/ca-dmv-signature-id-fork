import Crypto
import Foundation

enum AAMVACanonicalizer {
    private static let mandatoryFields = [
        "DCA", "DCB", "DCD", "DBA", "DCS", "DAC", "DAD", "DBD", "DBB", "DBC", "DAY",
        "DAU", "DAG", "DAI", "DAJ", "DAK", "DAQ", "DCF", "DCG", "DDE", "DDF", "DDG"
    ].sorted()

    static func protectedDocument(
        from document: AAMVADocument,
        componentIndex: String
    ) throws -> [String: String] {
        let fieldIndex = try decodeComponentIndex(componentIndex)
        let selectedFields = mandatoryFields.enumerated().compactMap { index, field -> String? in
            (fieldIndex & encodeMandatoryIndex(index)) == 0 ? nil : field
        }
        let selectedFieldSet = Set(selectedFields)

        guard let identitySubfile = document.primaryIdentitySubfile else {
            throw CADMVInternalError.malformedBarcode
        }

        return identitySubfile.fields.filter { selectedFieldSet.contains($0.key) }
    }

    static func canonicalize(_ document: [String: String]) -> Data {
        let lines = document
            .map { key, value in "\(key)\(value)" }
            .sorted()
        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    static func hash(_ document: [String: String]) -> Data {
        Data(SHA256.hash(data: canonicalize(document)))
    }

    private static func decodeComponentIndex(_ value: String) throws -> Int {
        guard value.count == 5, value.first == "u" else {
            throw CADMVInternalError.unsupportedVCB
        }
        let encoded = String(value.dropFirst())
        guard let bytes = Base64URL.decode(encoded), bytes.count == 3 else {
            throw CADMVInternalError.unsupportedVCB
        }
        return bytes.reduce(0) { ($0 << 8) | Int($1) }
    }

    private static func encodeMandatoryIndex(_ index: Int) -> Int {
        1 << (23 - index)
    }
}

extension Data {
    var cadmvHexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
