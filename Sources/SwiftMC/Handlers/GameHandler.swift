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

class GameHandler: PacketHandler {
    
    var channel: ChannelWrapper?
    
    func connected(channel: ChannelWrapper) {
        // Save channel
        self.channel = channel
        
        // Handle login
        if let loginSuccess = channel.login {
            // Send login packet (game starts)
            channel.send(packet: Login(entityId: 1, gameMode: 1, dimension: 0, seed: 0, difficulty: 0, maxPlayers: 1, levelType: "default", viewDistance: 16, reducedDebugInfo: false, normalRespawn: true))
            channel.send(packet: Position(x: 15, y: 100, z: 15, teleportId: 1))
            
            // Chat message
            channel.server.broadcast(packet: Chat(message: ChatMessage(extra: [
                ChatMessage(text: "[+] ").with(color: .green),
                ChatMessage(text: loginSuccess.username).with(color: .yellow)
            ])))
        }
    }
    
    func disconnected(channel: ChannelWrapper) {
        // Remove channel
        self.channel = nil
        
        // Handle logout
        if let loginSuccess = channel.login {
            // Send logout packets
            channel.server.broadcast(packet: Chat(message: ChatMessage(extra: [
                ChatMessage(text: "[-] ").with(color: .red),
                ChatMessage(text: loginSuccess.username).with(color: .yellow)
            ])))
        }
    }
    
    func shouldHandle(wrapper: PackerWrapper) -> Bool {
        return !(channel?.closing ?? true)
    }
    
    func handle(wrapper: PackerWrapper) {
        // Check packet type
        if let chat = wrapper.packet as? Chat {
            self.handle(chat: chat)
        }
    }
    
    func handle(chat: Chat) {
        // Create final message
        let message = ChatMessage(extra: [
            ChatMessage(text: "\(channel?.login?.username ?? "NULL"): ").with(color: .aqua),
            ChatMessage(text: chat.message)
        ])
        
        // Send the message to all players
        channel?.server.broadcast(packet: Chat(message: message))
        
        // Print in log the message
        channel?.server.log(message.toString())
    }
    
    func disconnect(reason: String) {
        channel?.server.log("Client disconnected: \(reason)")
        if let json = try? JSONSerialization.data(withJSONObject: ["text": reason], options: []), let string = String(bytes: json, encoding: .utf8) {
            // Send kick packet
            channel?.close(packet: Kick(message: string))
        } else {
            // Just close
            channel?.close()
        }
    }
    
}
