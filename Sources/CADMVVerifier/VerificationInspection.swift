import Foundation

@_spi(Testing)
public struct CADMVVerificationInspection: Equatable, Sendable {
    public let issuerAccepted: Bool
    public let vcbRequired: Bool
    public let vcbPresent: Bool
    public let decodedVCBByteCount: Int?
    public let decodedCredentialIssuer: String?
    public let decodedCredentialProofValue: String?
    public let uatCredentialShapeValid: Bool
    public let productionCredentialShapeValid: Bool
    public let opticalDataHashHex: String?
    public let verifyDataHex: String?
    public let statusListURL: String?
    public let statusListIndex: UInt64?

    public init(
        issuerAccepted: Bool,
        vcbRequired: Bool,
        vcbPresent: Bool,
        decodedVCBByteCount: Int?,
        decodedCredentialIssuer: String?,
        decodedCredentialProofValue: String?,
        uatCredentialShapeValid: Bool,
        productionCredentialShapeValid: Bool,
        opticalDataHashHex: String?,
        verifyDataHex: String?,
        statusListURL: String?,
        statusListIndex: UInt64?
    ) {
        self.issuerAccepted = issuerAccepted
        self.vcbRequired = vcbRequired
        self.vcbPresent = vcbPresent
        self.decodedVCBByteCount = decodedVCBByteCount
        self.decodedCredentialIssuer = decodedCredentialIssuer
        self.decodedCredentialProofValue = decodedCredentialProofValue
        self.uatCredentialShapeValid = uatCredentialShapeValid
        self.productionCredentialShapeValid = productionCredentialShapeValid
        self.opticalDataHashHex = opticalDataHashHex
        self.verifyDataHex = verifyDataHex
        self.statusListURL = statusListURL
        self.statusListIndex = statusListIndex
    }
}

@_spi(Testing)
extension CADMVVerifier {
    public static func inspectForSelfTest(rawPDF417: String) throws -> CADMVVerificationInspection {
        let document = try AAMVADocumentParser().parse(rawPDF417: rawPDF417)
        let encodedVCB = document.verifiableCredentialBarcode
        let decodedVCB = encodedVCB.flatMap(Base64URL.decode(_:))
        let credential = try decodedVCB.map(DMVVCBDecoder.decode(_:))
        let opticalDataHash = try credential.map {
            try AAMVACanonicalizer.hash(AAMVACanonicalizer.protectedDocument(
                from: document,
                componentIndex: $0.credentialSubject.protectedComponentIndex
            ))
        }

        return CADMVVerificationInspection(
            issuerAccepted: document.isCaliforniaDMVDocument,
            vcbRequired: document.requiresCaliforniaVCB,
            vcbPresent: encodedVCB != nil,
            decodedVCBByteCount: decodedVCB?.count,
            decodedCredentialIssuer: credential?.issuer,
            decodedCredentialProofValue: credential?.proof.proofValue,
            uatCredentialShapeValid: credential.map {
                (try? DMVCredentialValidator.validate($0, mode: .uat)) != nil
            } ?? false,
            productionCredentialShapeValid: credential.map {
                (try? DMVCredentialValidator.validate($0, mode: .production)) != nil
            } ?? false,
            opticalDataHashHex: opticalDataHash?.cadmvHexString,
            verifyDataHex: try credential.flatMap { credential in
                try opticalDataHash.map {
                    try EcdsaXi2023Verifier.createVerifyData(
                        credential: credential,
                        opticalDataHash: $0
                    ).cadmvHexString
                }
            },
            statusListURL: credential?.credentialStatus
                .flatMap(StatusListChecker.statusListLocation(for:))?
                .url
                .absoluteString,
            statusListIndex: credential?.credentialStatus
                .flatMap(StatusListChecker.statusListLocation(for:))?
                .statusListIndex
        )
    }

    public static func resolveVerificationMethodForSelfTest(
        _ verificationMethod: String,
        mode: CADMVVerificationMode
    ) async throws -> String {
        let key = try await DIDWebResolver.resolveVerificationMethod(
            id: verificationMethod,
            mode: mode,
            timeoutSeconds: 10
        )
        return key.compressedP256Key.cadmvHexString
    }

    public static func resolveVerificationMethodForSelfTest(
        _ verificationMethod: String,
        mode: CADMVVerificationMode,
        timeoutSeconds: Double
    ) async throws -> String {
        let key = try await DIDWebResolver.resolveVerificationMethod(
            id: verificationMethod,
            mode: mode,
            timeoutSeconds: timeoutSeconds
        )
        return key.compressedP256Key.cadmvHexString
    }

    public static func statusBitForSelfTest(uncompressedBytes: Data, index: UInt64) -> Bool? {
        BitstringStatusListDecoder.status(in: uncompressedBytes, at: index)
    }

    public static func statusBitForSelfTest(encodedList: String, index: UInt64) throws -> Bool? {
        try BitstringStatusListDecoder.status(in: encodedList, at: index)
    }

    public static func base58EncodeForSelfTest(_ data: Data) -> String {
        Base58BTC.encode(data)
    }

    public static func base58DecodeForSelfTest(_ value: String) -> Data? {
        Base58BTC.decode(value)
    }

    public static func base64URLDecodeForSelfTest(_ value: String) -> Data? {
        Base64URL.decode(value)
    }

    public static func decodeVCBForSelfTest(_ data: Data) throws {
        _ = try DMVVCBDecoder.decode(data)
    }

    public static func gzipDecompressForSelfTest(_ data: Data, maxOutputBytes: Int) throws -> Data {
        try Gzip.decompress(data, maxOutputBytes: maxOutputBytes)
    }

    public static func setNetworkHandlerForSelfTest(
        _ handler: (@Sendable (URLRequest) async throws -> (Data, URLResponse))?
    ) async {
        await CADMVNetworkSession.setTestHandler(handler)
    }

    public static func statusListVerifyDataForSelfTest(jsonData: Data) throws -> String {
        try EcdsaRdfc2019Verifier.createVerifyData(
            DMVStatusListCredentialParser.parse(jsonData)
        ).cadmvHexString
    }

    public static func verifyStatusListCredentialForSelfTest(
        jsonData: Data,
        publicKeyMultibase: String,
        id: String,
        controller: String
    ) throws -> Bool {
        return try EcdsaRdfc2019Verifier.verify(
            credential: DMVStatusListCredentialParser.parse(jsonData),
            verificationKey: didDocumentKeyForSelfTest(
                publicKeyMultibase: publicKeyMultibase,
                id: id,
                controller: controller
            )
        )
    }

    public static func statusListCheckResultForSelfTest(
        jsonData: Data,
        publicKeyMultibase: String,
        id: String,
        controller: String,
        expectedURL: String,
        statusListIndex: UInt64,
        credentialIssuer: String
    ) throws -> CADMVVerificationStatus {
        guard let url = URL(string: expectedURL) else {
            throw CADMVInternalError.statusListDecodeFailed
        }
        switch try StatusListChecker.evaluate(
            statusListCredential: DMVStatusListCredentialParser.parse(jsonData),
            expectedURL: url,
            statusListIndex: statusListIndex,
            credentialIssuer: credentialIssuer,
            verificationKey: didDocumentKeyForSelfTest(
                publicKeyMultibase: publicKeyMultibase,
                id: id,
                controller: controller
            )
        ) {
        case .notRevoked:
            return .verified
        case .revoked:
            return .revoked
        case .unavailable:
            return .unavailable
        }
    }

    private static func didDocumentKeyForSelfTest(
        publicKeyMultibase: String,
        id: String,
        controller: String
    ) throws -> DIDDocumentKey {
        guard publicKeyMultibase.first == "z",
              let decoded = Base58BTC.decode(String(publicKeyMultibase.dropFirst())),
              decoded.count == 35,
              decoded[decoded.startIndex] == 0x80,
              decoded[decoded.index(after: decoded.startIndex)] == 0x24 else {
            throw CADMVInternalError.unsupportedDIDKey
        }
        return DIDDocumentKey(
            id: id,
            controller: controller,
            type: "Multikey",
            publicKeyMultibase: publicKeyMultibase,
            compressedP256Key: decoded.dropFirst(2)
        )
    }
}
