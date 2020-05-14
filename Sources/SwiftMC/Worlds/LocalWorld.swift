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

class LocalWorld: WorldProtocol {
    
    // Connected clients
    var clients: [ChannelWrapper]
    
    // Initialize
    init() {
        self.clients = []
    }
    
    func connect(client: ChannelWrapper) {
        // Add to clients
        clients.append(client)
        
        // Login player
        let login = Login(entityId: 1, gameMode: 1, dimension: 0, seed: 0, difficulty: 0, maxPlayers: 1, levelType: "default", viewDistance: 16, reducedDebugInfo: false, normalRespawn: true)
        
        // Check if a login was already handled
        if !client.receivedLogin {
            // Just send login
            client.send(packet: login)
        } else {
            // Send an immediate respawn if required
            if client.protocolVersion >= ProtocolConstants.minecraft_1_15 {
                client.send(packet: GameState(reason: GameState.immediate_respawn, value: login.normalRespawn ? 0 : 1))
            }
            
            // Convert to respawn packet
            if client.lastDimmension == login.dimension {
                client.send(packet: Respawn(dimension: login.dimension >= 0 ? -1 : 0, hashedSeed: login.seed, difficulty: login.difficulty, gameMode: login.gameMode, levelType: login.levelType))
            }
            client.send(packet: Respawn(dimension: login.dimension, hashedSeed: login.seed, difficulty: login.difficulty, gameMode: login.gameMode, levelType: login.levelType))
        }
        
        // Save current dimension
        client.lastDimmension = login.dimension
        
        // Send position
        client.send(packet: Position(x: 15, y: 100, z: 15, teleportId: 1))
    }
    
    func disconnect(client: ChannelWrapper) {
        // Remove client from current clients
        clients.removeAll(where: { current in
            current.getName() == client.getName()
        })
    }
    
    func handle(packet: Packet, for client: ChannelWrapper) {
        // Check packet type
        if let chat = packet as? Chat {
            handle(chat: chat, for: client)
        }
    }
    
    func handle(chat: Chat, for client: ChannelWrapper) {
        // Fire PlayerChatEvent
        let event = PlayerChatEvent(player: client, message: ChatMessage(text: chat.message))
        client.server.fireListeners(for: event)
        clients.forEach { current in
            current.sendMessage(message: ChatMessage(extra: [
                ChatMessage(text: "\(client.getName()): ").with(color: .aqua),
                event.message
            ]))
        }
    }
    
    func pingWorld(from client: ChannelWrapper, completionHandler: @escaping (ServerInfo?) -> ()) {
        completionHandler(nil)
    }
    
}
