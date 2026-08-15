import Foundation

/// Minimal ZIP (store method) so we can share a DPDP data-export archive without extra packages.
enum SimpleZipArchive {
    static func make(files: [(name: String, data: Data)]) -> Data {
        var localChunks = Data()
        var central = Data()
        var offset: UInt32 = 0
        
        for file in files {
            let nameData = Data(file.name.utf8)
            let crc = crc32(file.data)
            let size = UInt32(file.data.count)
            let nameLen = UInt16(nameData.count)
            
            var local = Data()
            local.append(contentsOf: [0x50, 0x4b, 0x03, 0x04])
            local.append(uint16: 20)
            local.append(uint16: 0)
            local.append(uint16: 0)
            local.append(uint16: 0)
            local.append(uint16: 0)
            local.append(uint32: crc)
            local.append(uint32: size)
            local.append(uint32: size)
            local.append(uint16: nameLen)
            local.append(uint16: 0)
            local.append(nameData)
            local.append(file.data)
            
            var dir = Data()
            dir.append(contentsOf: [0x50, 0x4b, 0x01, 0x02])
            dir.append(uint16: 20)
            dir.append(uint16: 20)
            dir.append(uint16: 0)
            dir.append(uint16: 0)
            dir.append(uint16: 0)
            dir.append(uint16: 0)
            dir.append(uint32: crc)
            dir.append(uint32: size)
            dir.append(uint32: size)
            dir.append(uint16: nameLen)
            dir.append(uint16: 0)
            dir.append(uint16: 0)
            dir.append(uint16: 0)
            dir.append(uint16: 0)
            dir.append(uint32: 0)
            dir.append(uint32: offset)
            dir.append(nameData)
            
            offset += UInt32(local.count)
            localChunks.append(local)
            central.append(dir)
        }
        
        var end = Data()
        end.append(contentsOf: [0x50, 0x4b, 0x05, 0x06])
        end.append(uint16: 0)
        end.append(uint16: 0)
        end.append(uint16: UInt16(files.count))
        end.append(uint16: UInt16(files.count))
        end.append(uint32: UInt32(central.count))
        end.append(uint32: offset)
        end.append(uint16: 0)
        
        var zip = Data()
        zip.append(localChunks)
        zip.append(central)
        zip.append(end)
        return zip
    }
    
    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                let mask = UInt32(truncatingIfNeeded: -Int32(crc & 1))
                crc = (crc >> 1) ^ (0xEDB88320 & mask)
            }
        }
        return crc ^ 0xFFFFFFFF
    }
}

private extension Data {
    mutating func append(uint16 value: UInt16) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
    
    mutating func append(uint32 value: UInt32) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
}
