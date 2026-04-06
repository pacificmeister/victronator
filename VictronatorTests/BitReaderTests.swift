import XCTest
@testable import Victronator

final class BitReaderTests: XCTestCase {

    func testReadSingleByte() {
        // 0xA5 = 10100101 in binary
        let data = Data([0xA5])
        var reader = BitReader(data: data)

        // LSB first: bits are 1,0,1,0,0,1,0,1
        XCTAssertEqual(reader.readUnsigned(bits: 1), 1)
        XCTAssertEqual(reader.readUnsigned(bits: 1), 0)
        XCTAssertEqual(reader.readUnsigned(bits: 1), 1)
        XCTAssertEqual(reader.readUnsigned(bits: 1), 0)
        XCTAssertEqual(reader.readUnsigned(bits: 1), 0)
        XCTAssertEqual(reader.readUnsigned(bits: 1), 1)
        XCTAssertEqual(reader.readUnsigned(bits: 1), 0)
        XCTAssertEqual(reader.readUnsigned(bits: 1), 1)
    }

    func testReadMultiBit() {
        // 0x3F = 00111111
        let data = Data([0x3F])
        var reader = BitReader(data: data)

        // Read 4 bits LSB-first: bits 0-3 = 1111 = 15
        XCTAssertEqual(reader.readUnsigned(bits: 4), 15)
        // Read 4 bits: bits 4-7 = 0011 = 3
        XCTAssertEqual(reader.readUnsigned(bits: 4), 3)
    }

    func testReadAcrossBytes() {
        // 0xF0, 0x0F -> bits: 00001111 11110000
        // LSB first from byte 0: 0,0,0,0,1,1,1,1 then byte 1: 0,0,0,0,1,1,1,1
        let data = Data([0xF0, 0x0F])
        var reader = BitReader(data: data)

        // Read 12 bits spanning both bytes
        // Bits 0-11: from byte0=0xF0 bits 0-7 (0,0,0,0,1,1,1,1) + byte1=0x0F bits 0-3 (1,1,1,1)
        // = 1111 1111 0000 in MSB-first = 0xFF0 = 4080? No...
        // LSB-first accumulation: bit0=0, bit1=0, bit2=0, bit3=0, bit4=1, bit5=1, bit6=1, bit7=1,
        //                         bit8=1, bit9=1, bit10=1, bit11=1
        // = 0*1 + 0*2 + 0*4 + 0*8 + 1*16 + 1*32 + 1*64 + 1*128 + 1*256 + 1*512 + 1*1024 + 1*2048
        // = 16+32+64+128+256+512+1024+2048 = 4080
        XCTAssertEqual(reader.readUnsigned(bits: 12), 4080)
    }

    func testReadSigned() {
        // -1 in 8-bit signed = 0xFF = 11111111
        let data = Data([0xFF])
        var reader = BitReader(data: data)
        XCTAssertEqual(reader.readSigned(bits: 8), -1)
    }

    func testReadSignedPositive() {
        // +127 in 8 bits = 0x7F
        let data = Data([0x7F])
        var reader = BitReader(data: data)
        XCTAssertEqual(reader.readSigned(bits: 8), 127)
    }

    func testReadSigned16() {
        // -256 in 16-bit = 0xFF00
        let data = Data([0x00, 0xFF])  // little-endian at bit level
        var reader = BitReader(data: data)
        XCTAssertEqual(reader.readSigned(bits: 16), -256)
    }

    func testRead16BitUnsigned() {
        // 0x1234 stored as bytes [0x34, 0x12] (LSB first at bit level = LE byte order)
        let data = Data([0x34, 0x12])
        var reader = BitReader(data: data)
        XCTAssertEqual(reader.readUnsigned(bits: 16), 0x1234)
    }

    func testBitsRemaining() {
        let data = Data([0x00, 0x00])
        var reader = BitReader(data: data)
        XCTAssertEqual(reader.bitsRemaining, 16)
        _ = reader.readUnsigned(bits: 10)
        XCTAssertEqual(reader.bitsRemaining, 6)
    }
}
