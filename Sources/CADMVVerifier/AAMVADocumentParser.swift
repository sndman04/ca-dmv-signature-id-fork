import Foundation

struct AAMVADocumentParser {
    func parse(rawPDF417: String) throws -> AAMVADocument {
        let payload = Data(rawPDF417.utf8)
        guard let ansiRange = payload.range(of: Data("ANSI ".utf8)) else {
            throw CADMVInternalError.malformedBarcode
        }

        let headerStart = ansiRange.upperBound
        guard payload.count - headerStart >= 12 else {
            throw CADMVInternalError.malformedBarcode
        }

        let issuerBytes = payload[headerStart..<headerStart + 6]
        guard let issuer = String(data: Data(issuerBytes), encoding: .utf8) else {
            throw CADMVInternalError.malformedBarcode
        }
        let remainderStart = headerStart + 6
        let subfileCountRange = (remainderStart + 4)..<(remainderStart + 6)
        let subfileCountText = String(decoding: payload[subfileCountRange], as: UTF8.self)
        guard let subfileCount = Int(subfileCountText), subfileCount >= 0 else {
            throw CADMVInternalError.malformedBarcode
        }

        let entriesStart = remainderStart + 6
        let minimumEntryLength = subfileCount * 10
        guard payload.count - entriesStart >= minimumEntryLength else {
            throw CADMVInternalError.malformedBarcode
        }

        var descriptors: [AAMVASubfileDescriptor] = []
        var cursor = entriesStart
        for _ in 0..<subfileCount {
            let designatorEnd = cursor + 2
            let offsetEnd = designatorEnd + 4
            let lengthEnd = offsetEnd + 4
            let designator = String(decoding: payload[cursor..<designatorEnd], as: UTF8.self)
            let offsetText = String(decoding: payload[designatorEnd..<offsetEnd], as: UTF8.self)
            let lengthText = String(decoding: payload[offsetEnd..<lengthEnd], as: UTF8.self)
            guard let offset = Int(offsetText),
                  let length = Int(lengthText),
                  offset >= 0,
                  length >= 0 else {
                throw CADMVInternalError.malformedBarcode
            }
            descriptors.append(AAMVASubfileDescriptor(
                designator: designator,
                offset: offset,
                length: length
            ))
            cursor = lengthEnd
        }

        let payloadPrefixLength = headerStart + 6 + 6 + minimumEntryLength

        let subfiles = descriptors.compactMap { descriptor -> AAMVASubfile? in
            guard descriptor.offset >= payloadPrefixLength else {
                return nil
            }
            let startDistance = descriptor.offset
            let end = descriptor.offset.addingReportingOverflow(descriptor.length)
            guard !end.overflow,
                  startDistance <= payload.count,
                  end.partialValue <= payload.count else {
                return nil
            }
            guard let rawSubfile = String(
                data: payload[startDistance..<end.partialValue],
                encoding: .utf8
            ) else {
                return nil
            }
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
