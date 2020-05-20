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

class PlayerInfo: Packet {
    
    var action: Action
    var items: [Item]
    
    required init() {
        action = .add_player
        items = []
    }
    
    init(action: Action, items: [Item]) {
        self.action = action
        self.items = items
    }
    
    func readPacket(from buffer: inout ByteBuffer, direction: DirectionData, protocolVersion: Int32) {
        self.action = getAction(for: buffer.readVarInt() ?? 0)
        let count = buffer.readVarInt() ?? 0
        for _ in 0 ..< count {
            var item = Item(uuid: buffer.readUUID())
            if action == .add_player {
                item.username = buffer.readVarString()
                item.properties = []
                let count2 = buffer.readVarInt() ?? 0
                for _ in 0 ..< count2 {
                    let name = buffer.readVarString() ?? ""
                    let value = buffer.readVarString() ?? ""
                    if buffer.readBool() ?? false {
                        item.properties?.append([name, value, buffer.readVarString() ?? ""])
                    } else {
                        item.properties?.append([name, value])
                    }
                }
                item.gamemode = buffer.readVarInt()
                item.ping = buffer.readVarInt()
                if buffer.readBool() ?? false {
                    item.displayname = buffer.readVarString()
                }
            } else if action == .update_gamemode {
                item.gamemode = buffer.readVarInt()
            } else if action == .update_latency {
                item.ping = buffer.readVarInt()
            } else if action == .update_displayname {
                if buffer.readBool() ?? false {
                    item.displayname = buffer.readVarString()
                }
            }
            items.append(item)
        }
    }
    
    func writePacket(to buffer: inout ByteBuffer, direction: DirectionData, protocolVersion: Int32) {
        buffer.writeVarInt(value: action.rawValue)
        buffer.writeVarInt(value: Int32(items.count))
        for item in items {
            buffer.writeUUID(value: item.uuid ?? "")
            if action == .add_player {
                buffer.writeVarString(string: item.username ?? "")
                buffer.writeVarInt(value: Int32(item.properties?.count ?? 0))
                for property in item.properties ?? [] {
                    buffer.writeVarString(string: property[0])
                    buffer.writeVarString(string: property[1])
                    if property.count >= 3 {
                        buffer.writeBool(value: true)
                        buffer.writeVarString(string: property[2])
                    } else {
                        buffer.writeBool(value: false)
                    }
                }
                buffer.writeVarInt(value: item.gamemode ?? 0)
                buffer.writeVarInt(value: item.ping ?? 0)
                buffer.writeBool(value: item.displayname != nil)
                if let displayname = item.displayname {
                    buffer.writeVarString(string: displayname)
                }
            } else if action == .update_gamemode {
                buffer.writeVarInt(value: item.gamemode ?? 0)
            } else if action == .update_latency {
                buffer.writeVarInt(value: item.ping ?? 0)
            } else if action == .update_displayname {
                buffer.writeBool(value: item.displayname != nil)
                if let displayname = item.displayname {
                    buffer.writeVarString(string: displayname)
                }
            }
        }
    }
    
    func toString() -> String {
        return "PlayerInfo(action: \(action), items: \(items))"
    }
    
    enum Action: Int32 {
        case add_player = 0
        case update_gamemode = 1
        case update_latency = 2
        case update_displayname = 3
        case remove_player = 4
    }
    
    func getAction(for value: Int32) -> Action {
        for action in [.add_player, .update_gamemode, .update_latency, .update_displayname, .remove_player] as [Action] {
            if value == action.rawValue {
                return action
            }
        }
        return .add_player
    }
    
    struct Item: Player {
        // All
        var uuid: String?
        
        // Add player
        var username: String?
        var properties: [[String]]?
        
        // Add player and update gamemode
        var gamemode: Int32?
        
        // Add player and update latency
        var ping: Int32?
        
        // Add player and update displayname
        var displayname: String?
        
        // Player methods (for conformance)
        func getUUID() -> String { uuid ?? "NULL" }
        func goTo(world: WorldProtocol) {}
        func kick(reason: String) {}
        func isOnlineMode() -> Bool { return false }
        func hasSwiftMCPremium() -> Bool { return false }
        func setTabListMessage(header: ChatMessage, footer: ChatMessage) {}
        func getName() -> String { username ?? "Player" }
        func sendMessage(message: ChatMessage) {}
    }
    
}
