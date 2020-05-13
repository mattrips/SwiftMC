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

class Login: Packet {
    
    var entityId: Int32
    var gameMode: UInt8
    var dimension: Int32
    var seed: Int64
    var difficulty: UInt8
    var maxPlayers: UInt8
    var levelType: String
    var viewDistance: Int32
    var reducedDebugInfo: Bool
    var normalRespawn: Bool
    
    required init() {
        entityId = 0
        gameMode = 0
        dimension = 0
        seed = 0
        difficulty = 0
        maxPlayers = 0
        levelType = ""
        viewDistance = 0
        reducedDebugInfo = false
        normalRespawn = true
    }
    
    init(entityId: Int32, gameMode: UInt8, dimension: Int32, seed: Int64, difficulty: UInt8, maxPlayers: UInt8, levelType: String, viewDistance: Int32, reducedDebugInfo: Bool, normalRespawn: Bool) {
        self.entityId = entityId
        self.gameMode = gameMode
        self.dimension = dimension
        self.seed = seed
        self.difficulty = difficulty
        self.maxPlayers = maxPlayers
        self.levelType = levelType
        self.viewDistance = viewDistance
        self.reducedDebugInfo = reducedDebugInfo
        self.normalRespawn = normalRespawn
    }
    
    func readPacket(from buffer: inout ByteBuffer, direction: DirectionData, protocolVersion: Int32) {
        entityId = buffer.readInteger(as: Int32.self) ?? entityId
        gameMode = buffer.readBytes(length: 1)?.first ?? gameMode
        if protocolVersion > ProtocolConstants.minecraft_1_9 {
            dimension = buffer.readInteger(as: Int32.self) ?? dimension
        } else {
            dimension = Int32(buffer.readBytes(length: 1)?.first ?? 0)
        }
        if protocolVersion >= ProtocolConstants.minecraft_1_15 {
            seed = buffer.readInteger(as: Int64.self) ?? seed
        }
        if protocolVersion < ProtocolConstants.minecraft_1_14 {
            difficulty = buffer.readBytes(length: 1)?.first ?? difficulty
        }
        maxPlayers = buffer.readBytes(length: 1)?.first ?? maxPlayers
        levelType = buffer.readVarString() ?? levelType
        if protocolVersion >= ProtocolConstants.minecraft_1_14 {
            viewDistance = buffer.readVarInt() ?? viewDistance
        }
        if protocolVersion >= 29 {
            reducedDebugInfo = buffer.readBool() ?? reducedDebugInfo
        }
        if protocolVersion >= ProtocolConstants.minecraft_1_15 {
            normalRespawn = buffer.readBool() ?? normalRespawn
        }
    }
    
    func writePacket(to buffer: inout ByteBuffer, direction: DirectionData, protocolVersion: Int32) {
        buffer.writeInteger(entityId)
        buffer.writeBytes([gameMode])
        if protocolVersion > ProtocolConstants.minecraft_1_9 {
            buffer.writeInteger(dimension)
        } else {
            buffer.writeBytes([UInt8(dimension)])
        }
        if protocolVersion >= ProtocolConstants.minecraft_1_15 {
            buffer.writeInteger(seed)
        }
        if protocolVersion < ProtocolConstants.minecraft_1_14 {
            buffer.writeBytes([difficulty])
        }
        buffer.writeBytes([maxPlayers])
        buffer.writeVarString(string: levelType)
        if protocolVersion >= ProtocolConstants.minecraft_1_14 {
            buffer.writeVarInt(value: viewDistance)
        }
        if protocolVersion >= 29 {
            buffer.writeBool(value: reducedDebugInfo)
        }
        if protocolVersion >= ProtocolConstants.minecraft_1_15 {
            buffer.writeBool(value: normalRespawn)
        }
    }
    
    func toString() -> String {
        return "Login()"
    }
    
}
