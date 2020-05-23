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

class WorldChunkSection {
    
    // Static constants
    public static let array_size = WorldChunk.width * WorldChunk.height * WorldChunk.section_depth
    public static let empty_block_light: Int8 = 0
    public static let empty_skylight: Int8 = 0
    public static let default_block_light: Int8 = 0
    public static let default_skylight: Int8 = 0xF
    public static let global_palette_bits_per_block = 13
    
    // Palette
    private var palette: [Int32]?
    private var data: VariableValueArray!
    private var oldData: [UInt8]!
    
    // Sky light and block light
    private var skyLight: NibbleArray
    private var blockLight: NibbleArray
    private var count: Int = 0
    
    // Initializer (from types)
    public init(types: [Int32] = [Int32](repeating: 0, count: WorldChunkSection.array_size), skyLight: NibbleArray = NibbleArray(size: WorldChunkSection.array_size, value: WorldChunkSection.default_skylight), blockLight: NibbleArray = NibbleArray(size: WorldChunkSection.array_size, value: WorldChunkSection.default_block_light)) {
        // Store light data
        self.skyLight = skyLight
        self.blockLight = blockLight
        
        // Calculate block data from array
        self.loadTypeArray(types)
    }
    
    // Initializer (from data)
    public init(data: VariableValueArray, palette: [Int32]?, skyLight: NibbleArray = NibbleArray(size: WorldChunkSection.array_size, value: WorldChunkSection.default_skylight), blockLight: NibbleArray = NibbleArray(size: WorldChunkSection.array_size, value: WorldChunkSection.default_block_light)) {
        // Store data
        self.data = data
        self.palette = palette
        self.skyLight = skyLight
        self.blockLight = blockLight
    }
    
    // Initializer (from NBT)
    public convenience init(tag: NBTCompound) {
        let rawTypes = (tag["Blocks"] as? NBTByteArray)?.values ?? []
        let data = NibbleArray(rawData: (tag["Data"] as? NBTByteArray)?.values ?? [])
        let blockLight = NibbleArray(rawData: (tag["BlockLight"] as? NBTByteArray)?.values ?? [])
        let skyLight = NibbleArray(rawData: (tag["SkyLight"] as? NBTByteArray)?.values ?? [])
        
        var types = [Int32]()
        for i in 0 ..< rawTypes.count {
            types.append((Int32(rawTypes[i]) & 0xFF) << 4 | Int32(data[i]))
        }
        
        self.init(types: types, skyLight: skyLight, blockLight: blockLight)
    }
    
    // Load from types
    public func loadTypeArray(_ types: [Int32]) {
        // Build the palette and the count
        self.count = 0
        self.palette = []
        for type in types {
            if type != 0 {
                count += 1
            }
            if !(palette?.contains(type) ?? false) {
                palette?.append(type)
            }
        }
        
        // Build the list
        var bitsPerBlock = VariableValueArray.neededBits(for: palette?.count ?? 0)
        if bitsPerBlock < 4 {
            bitsPerBlock = 4
        } else if bitsPerBlock > 8 {
            palette = nil
            bitsPerBlock = WorldChunkSection.global_palette_bits_per_block
        }
        self.data = VariableValueArray(bitsPerValue: bitsPerBlock, capacity: WorldChunkSection.array_size)
        self.oldData = []
        for i in 0 ..< WorldChunkSection.array_size {
            if let palette = palette {
                data[i] = Int32(palette.firstIndex(of: types[i]) ?? 0)
            } else {
                data[i] = types[i]
            }
            oldData.append(contentsOf: [UInt8(types[i] & 0xFF), UInt8(types[i] >> 8)])
        }
    }
    
    // Check if a section is empty
    public func isEmpty() -> Bool {
        return count == 0
    }
    
    // Write the chunk section to a byte buffer
    
    internal func writeBlocks(to buffer: inout ByteBuffer) {
        // Check that chunk is not empty
        if isEmpty() {
            return
        }
        
        // Bits per value (varies)
        buffer.writeBytes([UInt8(data.bitsPerValue)])
            
        // Palette
        if let palette = palette {
            buffer.writeVarInt(value: Int32(palette.count))
            for value in palette {
                buffer.writeVarInt(value: value)
            }
        } else {
            buffer.writeVarInt(value: 0)
        }
        
        // Chunk data
        buffer.writeVarInt(value: Int32(data.backing.count))
        for value in data.backing {
            buffer.writeInteger(value, as: Int64.self)
        }
    }
    
    internal func writeBlocksOld(to buffer: inout ByteBuffer) {
        // Check that chunk is not empty
        if isEmpty() {
            return
        }
        
        // Write section without palette
        buffer.writeBytes(oldData)
    }
    
    internal func writeBlockLight(to buffer: inout ByteBuffer) {
        // Check that chunk is not empty
        if isEmpty() {
            return
        }
        
        // Block light
        buffer.writeBytes(blockLight.rawData.map({ UInt8(bitPattern: $0) }))
    }
    
    internal func writeSkyLight(to buffer: inout ByteBuffer) {
        // Check that chunk is not empty
        if isEmpty() {
            return
        }
        
        // Skylight
        buffer.writeBytes(skyLight.rawData.map({ UInt8(bitPattern: $0) }))
    }

}
