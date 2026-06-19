import Foundation
import Compression

/// A minimal read-only ZIP reader — just enough to pull named entries out of a MyCar `.dat`
/// backup (a standard ZIP). Parses the central directory and inflates STORED or DEFLATE entries
/// using the system Compression framework (Apple's `COMPRESSION_ZLIB` is raw DEFLATE, which is
/// exactly what ZIP stores). No third-party dependency.
struct ZipReader {
    private struct Entry { let method: Int; let compSize: Int; let uncompSize: Int; let localOffset: Int }
    private let bytes: [UInt8]
    private var entries: [String: Entry] = [:]

    init?(_ data: Data) {
        bytes = [UInt8](data)
        guard bytes.count > 22, let eocd = findEOCD() else { return nil }
        let count = u16(eocd + 10)
        var offset = u32(eocd + 16)
        for _ in 0..<count {
            guard offset + 46 <= bytes.count, u32(offset) == 0x02014b50 else { break }
            let method = u16(offset + 10)
            let compSize = u32(offset + 20)
            let uncompSize = u32(offset + 24)
            let nameLen = u16(offset + 28)
            let extraLen = u16(offset + 30)
            let commentLen = u16(offset + 32)
            let localOffset = u32(offset + 42)
            let nameStart = offset + 46
            guard nameStart + nameLen <= bytes.count else { break }
            let name = String(decoding: bytes[nameStart ..< nameStart + nameLen], as: UTF8.self)
            entries[name] = Entry(method: method, compSize: compSize, uncompSize: uncompSize, localOffset: localOffset)
            offset = nameStart + nameLen + extraLen + commentLen
        }
        guard !entries.isEmpty else { return nil }
    }

    var names: [String] { Array(entries.keys) }

    /// Decompressed bytes of a named entry, or nil if absent / unsupported.
    func extract(_ name: String) -> Data? {
        guard let e = entries[name] else { return nil }
        let lo = e.localOffset
        guard lo + 30 <= bytes.count, u32(lo) == 0x04034b50 else { return nil }
        let dataStart = lo + 30 + u16(lo + 26) + u16(lo + 28)
        guard dataStart + e.compSize <= bytes.count else { return nil }
        let comp = Array(bytes[dataStart ..< dataStart + e.compSize])
        if e.method == 0 { return Data(comp) }              // STORED
        guard e.method == 8 else { return nil }             // only DEFLATE otherwise
        return inflate(comp, expected: e.uncompSize)
    }

    private func inflate(_ src: [UInt8], expected: Int) -> Data? {
        guard expected > 0 else { return Data() }
        var dst = [UInt8](repeating: 0, count: expected)
        let written = src.withUnsafeBufferPointer { s in
            dst.withUnsafeMutableBufferPointer { d in
                compression_decode_buffer(d.baseAddress!, expected, s.baseAddress!, src.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written > 0 else { return nil }
        return Data(dst.prefix(written))
    }

    // little-endian readers
    private func u16(_ o: Int) -> Int { Int(bytes[o]) | (Int(bytes[o + 1]) << 8) }
    private func u32(_ o: Int) -> Int {
        Int(bytes[o]) | (Int(bytes[o + 1]) << 8) | (Int(bytes[o + 2]) << 16) | (Int(bytes[o + 3]) << 24)
    }

    /// End-of-central-directory record (signature 0x06054b50), scanning back from the end.
    private func findEOCD() -> Int? {
        let minPos = max(0, bytes.count - 22 - 65536)
        var i = bytes.count - 22
        while i >= minPos {
            if u32(i) == 0x06054b50 { return i }
            i -= 1
        }
        return nil
    }
}
