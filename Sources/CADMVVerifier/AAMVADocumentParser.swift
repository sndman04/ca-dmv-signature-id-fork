import Foundation

struct AAMVADocumentParser {
    func parse(rawPDF417: String) throws -> AAMVADocument {
        let payload = Data(AAMVAPayloadNormalizer.normalize(rawPDF417).utf8)
        guard let ansiRange = payload.range(of: Data("ANSI ".utf8)) else {
            throw CADMVInternalError.malformedBarcode
        }

        let declaredSeparators = try declaredSeparators(payload: payload, ansiRange: ansiRange)
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

        var subfiles: [AAMVASubfile] = []
        var subfileCursor = entriesStart + minimumEntryLength
        for (descriptorIndex, descriptor) in descriptors.enumerated() {
            guard payload.count - subfileCursor >= 2 else {
                throw CADMVInternalError.malformedBarcode
            }

            let designatorEnd = subfileCursor + 2
            let designator = String(decoding: payload[subfileCursor..<designatorEnd], as: UTF8.self)
            subfileCursor = designatorEnd

            let separators = separatorsForSubfile(
                descriptor: descriptor,
                payload: payload,
                subfileStart: designatorEnd,
                declared: declaredSeparators
            )
            let terminator = payload[subfileCursor...].firstIndex(of: separators.segmentTerminator)
            guard let subfileEnd = terminator ?? unterminatedFinalSubfileEnd(
                descriptorIndex: descriptorIndex,
                descriptorCount: descriptors.count,
                payload: payload,
                subfileCursor: subfileCursor
            ) else {
                throw CADMVInternalError.malformedBarcode
            }
            guard let rawSubfile = String(data: payload[subfileCursor..<subfileEnd], encoding: .utf8) else {
                throw CADMVInternalError.malformedBarcode
            }
            subfileCursor = terminator.map { $0 + 1 } ?? subfileEnd

            let fieldData = rawSubfile.hasPrefix(designator)
                ? String(rawSubfile.dropFirst(2))
                : rawSubfile
            subfiles.append(AAMVASubfile(
                designator: designator,
                fields: AAMVAFieldParser.parse(
                    rawSubfile: fieldData,
                    elementSeparator: separators.elementSeparator,
                    segmentTerminator: separators.segmentTerminator
                )
            ))
        }

        guard !subfiles.isEmpty else {
            throw CADMVInternalError.malformedBarcode
        }

        return AAMVADocument(
            issuerIdentificationNumber: issuer,
            subfiles: subfiles
        )
    }

    private func unterminatedFinalSubfileEnd(
        descriptorIndex: Int,
        descriptorCount: Int,
        payload: Data,
        subfileCursor: Data.Index
    ) -> Data.Index? {
        guard descriptorIndex == descriptorCount - 1,
              subfileCursor < payload.endIndex else {
            return nil
        }
        return payload.endIndex
    }

    private func declaredSeparators(payload: Data, ansiRange: Range<Data.Index>) throws -> AAMVASeparators {
        if ansiRange.lowerBound >= 4 {
            return AAMVASeparators(
                elementSeparator: payload[ansiRange.lowerBound - 3],
                segmentTerminator: payload[ansiRange.lowerBound - 1],
                inferFromSubfileLength: false
            )
        }

        guard ansiRange.lowerBound < 4 else {
            throw CADMVInternalError.malformedBarcode
        }

        return AAMVASeparators(
            elementSeparator: UInt8(ascii: "\n"),
            segmentTerminator: UInt8(ascii: "\r"),
            inferFromSubfileLength: true
        )
    }

    private func separatorsForSubfile(
        descriptor: AAMVASubfileDescriptor,
        payload: Data,
        subfileStart: Data.Index,
        declared: AAMVASeparators
    ) -> AAMVASeparators {
        guard declared.inferFromSubfileLength, descriptor.length >= 3,
              let terminatorIndex = payload.index(
            subfileStart,
            offsetBy: descriptor.length - 3,
            limitedBy: payload.index(before: payload.endIndex)
        ) else {
            return declared
        }

        let segmentTerminator = payload[terminatorIndex]
        guard isControlSeparator(segmentTerminator) else {
            return declared
        }

        let bodyEnd = max(subfileStart, terminatorIndex)
        let body = payload[subfileStart..<bodyEnd]
        let elementSeparator = body.first(where: isControlSeparator) ?? declared.elementSeparator
        return AAMVASeparators(
            elementSeparator: elementSeparator == segmentTerminator ? declared.elementSeparator : elementSeparator,
            segmentTerminator: segmentTerminator,
            inferFromSubfileLength: declared.inferFromSubfileLength
        )
    }

    private func isControlSeparator(_ byte: UInt8) -> Bool {
        byte == UInt8(ascii: "\n") ||
            byte == UInt8(ascii: "\r") ||
            byte == UInt8(ascii: "\t") ||
            byte == 0x1d ||
            byte == 0x1e ||
            byte == 0x1f
    }
}

enum AAMVAPayloadNormalizer {
    static func normalize(_ value: String) -> String {
        guard shouldNormalize(value) else {
            return value
        }

        var output = ""
        output.reserveCapacity(value.count)
        var cursor = value.startIndex

        while cursor < value.endIndex {
            guard value[cursor] == "\\" else {
                output.append(value[cursor])
                cursor = value.index(after: cursor)
                continue
            }

            let escapeStart = cursor
            cursor = value.index(after: cursor)
            guard cursor < value.endIndex else {
                output.append("\\")
                break
            }

            switch value[cursor] {
            case "n":
                output.append("\n")
                cursor = value.index(after: cursor)
            case "r":
                output.append("\r")
                cursor = value.index(after: cursor)
            case "t":
                output.append("\t")
                cursor = value.index(after: cursor)
            case "u":
                let uIndex = cursor
                cursor = value.index(after: cursor)
                if cursor < value.endIndex, value[cursor] == "{" {
                    let hexStart = value.index(after: cursor)
                    guard let close = value[hexStart...].firstIndex(of: "}") else {
                        output.append(contentsOf: value[escapeStart...uIndex])
                        continue
                    }
                    let hex = String(value[hexStart..<close])
                    if let scalar = unicodeScalar(hex: hex) {
                        output.unicodeScalars.append(scalar)
                    } else {
                        output.append(contentsOf: value[escapeStart...close])
                    }
                    cursor = value.index(after: close)
                } else {
                    guard let hexEnd = value.index(cursor, offsetBy: 4, limitedBy: value.endIndex) else {
                        output.append(contentsOf: value[escapeStart..<cursor])
                        continue
                    }
                    let hex = String(value[cursor..<hexEnd])
                    if let scalar = unicodeScalar(hex: hex) {
                        output.unicodeScalars.append(scalar)
                    } else {
                        output.append(contentsOf: value[escapeStart..<hexEnd])
                    }
                    cursor = hexEnd
                }
            default:
                output.append("\\")
                output.append(value[cursor])
                cursor = value.index(after: cursor)
            }
        }

        return output
    }

    private static func shouldNormalize(_ value: String) -> Bool {
        value.contains("\\")
    }

    private static func unicodeScalar(hex: String) -> Unicode.Scalar? {
        guard !hex.isEmpty,
              hex.count <= 6,
              hex.utf8.allSatisfy({
                  (UInt8(ascii: "0")...UInt8(ascii: "9")).contains($0) ||
                      (UInt8(ascii: "A")...UInt8(ascii: "F")).contains($0) ||
                      (UInt8(ascii: "a")...UInt8(ascii: "f")).contains($0)
              }),
              let value = UInt32(hex, radix: 16) else {
            return nil
        }
        return Unicode.Scalar(value)
    }
}

private struct AAMVASubfileDescriptor {
    let designator: String
    let offset: Int
    let length: Int
}

private struct AAMVASeparators {
    let elementSeparator: UInt8
    let segmentTerminator: UInt8
    let inferFromSubfileLength: Bool
}

enum AAMVAFieldParser {
    static func parse(
        rawSubfile: String,
        elementSeparator: UInt8,
        segmentTerminator: UInt8
    ) -> [String: String] {
        var fields: [String: String] = [:]
        var normalized = rawSubfile
        if let segmentTerminator = Unicode.Scalar(Int(segmentTerminator)),
           let elementSeparator = Unicode.Scalar(Int(elementSeparator)) {
            normalized = normalized.replacingOccurrences(
                of: String(segmentTerminator),
                with: String(elementSeparator)
            )
        }
        let separatorScalar = Unicode.Scalar(Int(elementSeparator)) ?? Unicode.Scalar(10)!
        let separator = Character(separatorScalar)
        let lines = normalized.split(separator: separator, omittingEmptySubsequences: false)

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
