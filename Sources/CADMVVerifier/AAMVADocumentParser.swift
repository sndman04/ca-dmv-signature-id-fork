import Foundation

struct AAMVADocumentParser {
    func parse(rawPDF417: String) throws -> AAMVADocument {
        guard let ansiRange = rawPDF417.range(of: "ANSI ") else {
            throw CADMVInternalError.malformedBarcode
        }

        let headerStart = ansiRange.upperBound
        let headerAndBody = rawPDF417[headerStart...]
        guard headerAndBody.count >= 12 else {
            throw CADMVInternalError.malformedBarcode
        }

        let issuer = String(headerAndBody.prefix(6))
        let remainder = headerAndBody.dropFirst(6)
        guard remainder.count >= 6 else {
            throw CADMVInternalError.malformedBarcode
        }

        let subfileCountText = String(remainder.dropFirst(4).prefix(2))
        guard let subfileCount = Int(subfileCountText), subfileCount >= 0 else {
            throw CADMVInternalError.malformedBarcode
        }

        let entriesStart = remainder.index(remainder.startIndex, offsetBy: 6)
        let entriesText = remainder[entriesStart...]
        let minimumEntryLength = subfileCount * 10
        guard entriesText.count >= minimumEntryLength else {
            throw CADMVInternalError.malformedBarcode
        }

        var descriptors: [AAMVASubfileDescriptor] = []
        var cursor = entriesText.startIndex
        for _ in 0..<subfileCount {
            let designatorEnd = entriesText.index(cursor, offsetBy: 2)
            let offsetEnd = entriesText.index(designatorEnd, offsetBy: 4)
            let lengthEnd = entriesText.index(offsetEnd, offsetBy: 4)
            let designator = String(entriesText[cursor..<designatorEnd])
            let offsetText = String(entriesText[designatorEnd..<offsetEnd])
            let lengthText = String(entriesText[offsetEnd..<lengthEnd])
            guard let offset = Int(offsetText), let length = Int(lengthText) else {
                throw CADMVInternalError.malformedBarcode
            }
            descriptors.append(AAMVASubfileDescriptor(
                designator: designator,
                offset: offset,
                length: length
            ))
            cursor = lengthEnd
        }

        let bodyStart = rawPDF417.index(headerStart, offsetBy: 6 + 6 + minimumEntryLength)
        let payloadPrefixLength = rawPDF417.distance(from: rawPDF417.startIndex, to: bodyStart)

        let subfiles = descriptors.compactMap { descriptor -> AAMVASubfile? in
            guard descriptor.offset >= payloadPrefixLength else {
                return nil
            }
            let startDistance = descriptor.offset
            let endDistance = descriptor.offset + descriptor.length
            guard startDistance <= rawPDF417.count, endDistance <= rawPDF417.count else {
                return nil
            }
            let start = rawPDF417.index(rawPDF417.startIndex, offsetBy: startDistance)
            let end = rawPDF417.index(rawPDF417.startIndex, offsetBy: endDistance)
            let rawSubfile = String(rawPDF417[start..<end])
            let fieldData = rawSubfile.hasPrefix(descriptor.designator)
                ? String(rawSubfile.dropFirst(2))
                : rawSubfile
            return AAMVASubfile(
                designator: descriptor.designator,
                fields: AAMVAFieldParser.parse(rawSubfile: fieldData)
            )
        }

        guard !subfiles.isEmpty else {
            throw CADMVInternalError.malformedBarcode
        }

        return AAMVADocument(
            issuerIdentificationNumber: issuer,
            subfiles: subfiles
        )
    }
}

private struct AAMVASubfileDescriptor {
    let designator: String
    let offset: Int
    let length: Int
}

enum AAMVAFieldParser {
    static func parse(rawSubfile: String) -> [String: String] {
        var fields: [String: String] = [:]
        let normalized = rawSubfile.replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)

        for line in lines where line.count >= 3 {
            let field = String(line.prefix(3))
            guard isAAMVAFieldCode(field) else {
                continue
            }
            fields[field] = String(line.dropFirst(3))
        }

        return fields
    }

    private static func isAAMVAFieldCode(_ value: String) -> Bool {
        let bytes = value.utf8
        guard bytes.count == 3 else {
            return false
        }
        return bytes.allSatisfy { byte in
            (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(byte) ||
                (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
        }
    }
}
