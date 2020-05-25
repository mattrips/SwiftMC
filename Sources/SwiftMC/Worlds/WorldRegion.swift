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

class WorldRegion {
    
    // Static constants
    public static let region_size: Int32 = 32
    public static let version_gzip: Int8 = 1
    public static let version_deflate: Int8 = 2
    public static let sector_bytes = 4096
    public static let sector_ints = sector_bytes / 4
    public static let chunk_header_size = 5
    
    // Region informations
    public let world: LocalWorld
    public let x: Int32
    public let z: Int32
    
    // Caching
    private var offsets: [Int32]
    private var chunkTimestamps: [Int32]
    private var buffer: ByteBuffer
    private var lastModified: Double
    private var sectorsUsed: [Bool]
    private var sizeDelta: Int
    
    // Initializer
    public init(world: LocalWorld, x: Int32, z: Int32) {
        // Region informations
        self.world = world
        self.x = x
        self.z = z
        self.offsets = [Int32](repeating: 0, count: WorldRegion.sector_ints)
        self.chunkTimestamps = [Int32](repeating: 0, count: WorldRegion.sector_ints)
        self.sizeDelta = 0
        
        // Check if the region folder exists
        let folder = world.path.appendingPathComponent("region")
        if !FileManager.default.fileExists(atPath: folder.path) {
            // Create a folder
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Get the content of the file if exists
        let file = folder.appendingPathComponent("r.\(x).\(z).mca")
        let content = FileManager.default.contents(atPath: file.path) ?? Data()
        self.buffer = ByteBufferAllocator().buffer(capacity: content.count)
        self.buffer.writeBytes(content)
        self.lastModified = (try? FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? NSDate)?.timeIntervalSince1970 ?? 0
        let initialLength = content.count
        
        // Grow the file if it is not big enough (less than 8K)
        if lastModified == 0 || initialLength < 4096 {
            // New file or files under 4K
            sizeDelta = 2 * WorldRegion.sector_bytes
            buffer.moveWriterIndex(to: 0)
            buffer.reserveCapacity(sizeDelta)
            buffer.writeBytes([UInt8](repeating: 0, count: sizeDelta))
        } else {
            // Grow again if needed
            buffer.moveWriterIndex(to: initialLength)
            if initialLength < 2 * WorldRegion.sector_bytes {
                // Still under 8K
                sizeDelta = 2 * WorldRegion.sector_bytes - initialLength
                buffer.reserveCapacity(sizeDelta)
                buffer.writeBytes([UInt8](repeating: 0, count: sizeDelta))
            } else if (initialLength & (WorldRegion.sector_bytes - 1)) != 0 {
                // Not a multiple of 4K, grow it
                sizeDelta = initialLength & (WorldRegion.sector_bytes - 1)
                buffer.reserveCapacity(sizeDelta)
                buffer.writeBytes([UInt8](repeating: 0, count: sizeDelta))
            }
        }
        
        // Setup available sector map
        buffer.moveReaderIndex(to: 0)
        let totalSectors = Int(ceil(Double(buffer.readableBytes) / Double(WorldRegion.sector_bytes)))
        self.sectorsUsed = [Bool](repeating: false, count: totalSectors + 1)
        self.sectorsUsed[0] = true
        self.sectorsUsed[1] = true
        
        // Read offset table and timestamp tables
        for i in 0 ..< WorldRegion.sector_ints {
            let offset = buffer.readInteger(as: Int32.self) ?? 0
            offsets[i] = offset
            
            let startSector = offset >> 8
            let numSectors = offset & 0xFF
            
            if offset != 0 && startSector >= 0 && startSector + numSectors <= totalSectors {
                for j in startSector ... startSector + numSectors {
                    sectorsUsed[Int(j)] = true
                }
            }
        }
        for i in 0 ..< WorldRegion.sector_ints {
            chunkTimestamps[i] = buffer.readInteger(as: Int32.self) ?? 0
        }
    }
    
    // Get offset for a chunk
    private func getOffset(x: Int32, z: Int32) -> Int32 {
        return offsets[Int(x + (z << 5))]
    }
    
    // Set offset
    private func setOffset(x: Int32, z: Int32, offset: Int32) {
        offsets[Int(x + (z << 5))] = offset
        buffer.moveWriterIndex(to: Int(x + (z << 5)) << 2)
        buffer.writeInteger(offset, as: Int32.self)
    }
    
    // Set timestamp
    private func setTimestamp(x: Int32, z: Int32, value: Int32) {
        chunkTimestamps[Int(x + (z << 5))] = value
        buffer.moveWriterIndex(to: WorldRegion.sector_bytes + Int(x + (z << 5)) << 2)
        buffer.writeInteger(value, as: Int32.self)
    }
    
    // Save to file
    public func save() {
        // Get content
        buffer.moveReaderIndex(to: 0)
        let content = Data(buffer.readBytes(length: buffer.readableBytes) ?? [])
        
        // Save to disk
        let file = world.path.appendingPathComponent("region").appendingPathComponent("r.\(x).\(z).mca")
        FileManager.default.createFile(atPath: file.path, contents: content, attributes: nil)
    }
    
    // Get buffer to read chunk
    private func getChunkBuffer(x: Int32, z: Int32) throws -> ByteBuffer? {
        // Check chunk offset
        let offset = getOffset(x: x, z: z)
        if offset == 0 { return nil }
        
        // Check sectors
        let totalSectors = sectorsUsed.count
        let sectorNumber = offset >> 8
        let numSectors = offset & 0xFF
        if sectorNumber + numSectors > totalSectors { return nil }
        
        // Read sectors
        self.buffer.moveReaderIndex(to: Int(sectorNumber) * WorldRegion.sector_bytes)
        let length = Int(buffer.readInteger(as: Int32.self) ?? 0)
        if length > WorldRegion.sector_bytes * Int(numSectors) || length <= 0 { return nil }
        
        // Read compression information
        let version = buffer.readInteger(as: Int8.self)
        var data = ByteBufferAllocator().buffer(capacity: length - 1)
        data.writeBytes(buffer.readBytes(length: length - 1) ?? [])
        if version == WorldRegion.version_gzip {
            data = try data.decompress(with: .gzip)
        } else if version == WorldRegion.version_deflate {
            data = try data.decompress(with: .deflate)
        }
        
        // Return the final buffer
        return data
    }
    
    // Get a chunk (in region coordinates)
    public func loadChunk(x: Int32, z: Int32) -> EventLoopFuture<WorldChunk> {
        // Prepare the promise
        let ev = world.server.eventLoopGroup.next()
        let promise = ev.makePromise(of: WorldChunk.self)
        
        // Get the buffer
        var buffer = try? getChunkBuffer(x: x, z: z)
        
        // Do the work
        ev.execute {
            // Create the chunk
            let chunk = WorldChunk(x: WorldRegion.region_size * self.x + x, z: WorldRegion.region_size * self.z + z)
            
            // Get the chunk from NBT
            let level = (buffer?.readNBT() as? NBTCompound)?["Level"] as? NBTCompound
            
            // If data exists from NBT
            if let level = level, (level["xPos"] as? NBTInt)?.value == chunk.x, (level["zPos"] as? NBTInt)?.value == chunk.z {
                // Load the sections
                if let sections = level["Sections"] as? NBTList {
                    for section in sections.values {
                        if let section = section as? NBTCompound, let y = section["Y"] as? NBTByte {
                            chunk.sections[y.value] = WorldChunkSection(tag: section)
                        }
                    }
                }
                
                // Read biomes
                if let biomes = level["Biomes"] as? NBTByteArray {
                    chunk.biomes = biomes.values
                }
            } else {
                // Generate a new chunk
                let random = Random(seed: self.world.config.randomSeed)
                
                // Biomes
                chunk.biomes = [Int8](repeating: 127, count: 256)
                
                // Chunk data
                let chunkData = self.world.getGenerator().generateChunkData(world: self.world, random: random, chunkX: chunk.x, chunkZ: chunk.z, biome: chunk.biomes)
                
                // Load the sections
                for y in 0 ..< WorldChunk.section_count {
                    // Check section
                    let section = chunkData.getSections()[y]
                    if !section.isEmpty {
                        chunk.sections[Int8(y)] = WorldChunkSection(types: section.map({ Int32($0) }))
                    }
                }
            }
            
            // Return the created chunk
            return promise.succeed(chunk)
        }
        
        // Return the future result
        return promise.futureResult
    }
    
    public func getChunk(x: Int32, z: Int32) -> WorldChunk? {
        return try? loadChunk(x: x, z: z).wait()
    }

}
