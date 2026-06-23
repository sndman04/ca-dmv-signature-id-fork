import Foundation
import zlib

enum Gzip {
    static func decompress(_ data: Data) throws -> Data {
        guard !data.isEmpty else {
            return Data()
        }

        var stream = z_stream()
        let initResult = inflateInit2_(
            &stream,
            MAX_WBITS + 16,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard initResult == Z_OK else {
            throw CADMVInternalError.statusListDecodeFailed
        }
        defer {
            inflateEnd(&stream)
        }

        var output = Data()
        let chunkSize = 16_384

        let result = data.withUnsafeBytes { inputBuffer -> Int32 in
            guard let inputBase = inputBuffer.baseAddress else {
                return Z_DATA_ERROR
            }
            stream.next_in = UnsafeMutablePointer<Bytef>(
                mutating: inputBase.assumingMemoryBound(to: Bytef.self)
            )
            stream.avail_in = uInt(data.count)

            var status: Int32 = Z_OK
            while status == Z_OK {
                var chunk = [UInt8](repeating: 0, count: chunkSize)
                status = chunk.withUnsafeMutableBytes { outputBuffer in
                    stream.next_out = outputBuffer.baseAddress?
                        .assumingMemoryBound(to: Bytef.self)
                    stream.avail_out = uInt(chunkSize)
                    return inflate(&stream, Z_NO_FLUSH)
                }
                let produced = chunkSize - Int(stream.avail_out)
                if produced > 0 {
                    output.append(chunk, count: produced)
                }
            }
            return status
        }

        guard result == Z_STREAM_END else {
            throw CADMVInternalError.statusListDecodeFailed
        }

        return output
    }
}
