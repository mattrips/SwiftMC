/*
*  Copyright (C) 2020 Groupe MINASTE
*
* This program is free software; you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation; either version 2 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with this program; if not, write to the Free Software Foundation, Inc.,
* 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*
*/

import Foundation
import NIO

public class WorldChunk {

    // Static constants
    public static let width = 16
    public static let height = 16
    public static let depth = 256
    public static let section_depth = 16
    public static let section_count = depth / section_depth
    
    // Chunk coordinates
    public let x: Int32
    public let z: Int32
    
    // Chunk sections
    internal var sections: [Int8: WorldChunkSection]
    
    // Initializer
    internal init(x: Int32, z: Int32) {
        self.x = x
        self.z = z
        self.sections = [:]
    }
    
    // Convert to MapChunk packet
    public func toMapChunkPacket(skylight: Bool = true, entireChunk: Bool = true) -> MapChunk {
        // Calculate bitMap
        let maxY = sections.map({ $0.key }).max() ?? 0
        let maxBitMap = (1 << maxY) - 1
        var bitMap = entireChunk ? maxBitMap : 0 & maxBitMap
        for y in 0 ..< maxY {
            if sections[y]?.isEmpty() ?? true {
                bitMap = bitMap & ~(1 << y)
            }
        }
        
        // Write sections
        var buffer = ByteBufferAllocator().buffer(capacity: 1024*1024*1024)
        for y in 0 ..< maxY {
            if (bitMap & 1 << y) != 0 {
                sections[y]?.write(to: &buffer, skylight: skylight)
            }
        }
        let data = buffer.readBytes(length: buffer.readableBytes) ?? []
        
        // Create the packet
        return MapChunk(x: x, z: z, groundUp: true, bitMap: Int32(bitMap), heightmaps: NBTCompound(), biomes: [], chunkData: data, blockEntities: [])
    }

}
