import Foundation

struct AAMVADocument: Equatable, Sendable {
    let issuerIdentificationNumber: String
    let subfiles: [AAMVASubfile]

    var isCaliforniaDMVDocument: Bool {
        issuerIdentificationNumber == CaliforniaDMV.issuerIdentificationNumber &&
            ["DL", "ID"].contains(primaryIdentitySubfile?.designator) &&
            primaryIdentitySubfile?.fields["DAJ"] == CaliforniaDMV.issuingJurisdiction
    }

    var requiresCaliforniaVCB: Bool {
        guard let issueDate = primaryIdentitySubfile?.fields["DBD"]
            .flatMap(AAMVADate.parseMMDDCCYY(_:)) else {
            return true
        }
        return issueDate >= CaliforniaDMV.digitalSignatureRequiredDate
    }

    var verifiableCredentialBarcode: String? {
        subfiles.first { $0.designator == CaliforniaDMV.vcbSubfile }?
            .fields[CaliforniaDMV.vcbField]
    }

    var primaryIdentitySubfile: AAMVASubfile? {
        subfiles.first { ["DL", "ID"].contains($0.designator) }
    }
}

struct AAMVASubfile: Equatable, Sendable {
    let designator: String
    let fields: [String: String]
}

enum CaliforniaDMV {
    static let issuerIdentificationNumber = "636014"
    static let issuingJurisdiction = "CA"
    static let vcbSubfile = "ZC"
    static let vcbField = "ZCE"
    static let digitalSignatureRequiredDate = AAMVADate(month: 9, day: 29, year: 2025)
}

struct AAMVADate: Equatable, Comparable, Sendable {
    let month: Int
    let day: Int
    let year: Int

    static func < (lhs: AAMVADate, rhs: AAMVADate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    static func parseMMDDCCYY(_ value: String) -> AAMVADate? {
        guard value.count == 8,
              let month = Int(value.prefix(2)),
              let day = Int(value.dropFirst(2).prefix(2)),
              let year = Int(value.suffix(4)),
              (1...9999).contains(year),
              (1...12).contains(month),
              (1...31).contains(day),
              isValidDate(month: month, day: day, year: year) else {
            return nil
        }
        return AAMVADate(month: month, day: day, year: year)
    }

    private static func isValidDate(month: Int, day: Int, year: Int) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        return components.isValidDate(in: calendar)
    }
}
