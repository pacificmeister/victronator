import Foundation

/// Reads fields from a byte buffer as an LSB-first bit stream.
/// Victron BLE payloads pack fields at the bit level, starting from the
/// least-significant bit of the first byte.
struct BitReader {
    private let data: Data
    private(set) var bitOffset: Int = 0

    init(data: Data) {
        self.data = data
    }

    /// Read an unsigned integer of the given bit width (up to 32 bits).
    mutating func readUnsigned(bits: Int) -> UInt32 {
        var result: UInt32 = 0
        for i in 0..<bits {
            let byteIndex = (bitOffset + i) / 8
            let bitIndex = (bitOffset + i) % 8
            guard byteIndex < data.count else { break }
            let bit = (UInt32(data[byteIndex]) >> bitIndex) & 1
            result |= bit << i
        }
        bitOffset += bits
        return result
    }

    /// Read a signed integer of the given bit width (up to 32 bits).
    /// Uses two's complement: if the high bit is set, the value is negative.
    mutating func readSigned(bits: Int) -> Int32 {
        let raw = readUnsigned(bits: bits)
        let signBit: UInt32 = 1 << (bits - 1)
        if raw & signBit != 0 {
            // Two's complement: value = raw - 2^bits
            return Int32(raw) - Int32(1 << bits)
        }
        return Int32(raw)
    }

    /// Number of bits remaining in the buffer.
    var bitsRemaining: Int {
        max(0, data.count * 8 - bitOffset)
    }
}
