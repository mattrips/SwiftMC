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

public class OverworldGenerator: WorldGenerator {
    
    public func generateChunkData(world: LocalWorld, random: Random, chunkX: Int32, chunkZ: Int32, biome: [Int8]) -> WorldChunkData {
        let chunkData = WorldChunkData(world: world)
        let perlin = PerlinGenerator(random: random)
        
        for x: Int32 in 0 ..< 16 {
            for z: Int32 in 0 ..< 16 {
                let h = Int32(perlin.octaveNoise(x: Float(chunkX * 16 + x) / 50, y: Float(chunkZ * 16 + z) / 50, octaves: 2, persistence: 0.5) * 30 + 55)
                for y: Int32 in 0 ..< max(h, 64) {
                    if y < 4 {
                        // Always bedrock
                        chunkData.setBlock(x: x, y: y, z: z, blockId: 7)
                    } else if y < h - 10 || h > 70 {
                        // Stone until a change
                        chunkData.setBlock(x: x, y: y, z: z, blockId: 1)
                    } else if y < h - 1 {
                        // Check if we are under a lake
                        if h < 64 {
                            // Sandstone
                            chunkData.setBlock(x: x, y: y, z: z, blockId: 24)
                        } else {
                            // Some dirt
                            chunkData.setBlock(x: x, y: y, z: z, blockId: 3)
                        }
                    } else if y < h {
                        // Check if we are under a lake
                        if h < 64 {
                            // Sandstone
                            chunkData.setBlock(x: x, y: y, z: z, blockId: 12)
                        } else {
                            // And grass
                            chunkData.setBlock(x: x, y: y, z: z, blockId: 2)
                        }
                    } else {
                        // Fill missing blocks with water
                        chunkData.setBlock(x: x, y: y, z: z, blockId: 8)
                    }
                }
            }
        }
        
        return chunkData
    }
    
    public func getName() -> String {
        return "overworld"
    }
    
}
