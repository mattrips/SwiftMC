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
        
        // Login to first world
        if let world = channel.server.worlds.first {
            channel.setWorld(world: world)
        } else {
            disconnect(reason: "No world found on this server!")
        }
        
        // Chat message
        if let loginSuccess = channel.login {
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
        
        // Foward to remote world
        if let world = channel.world {
            world.disconnect(client: channel)
        }
    }
    
    func shouldHandle(packet: Packet) -> Bool {
        return !(channel?.closing ?? true)
    }
    
    func handle(packet: Packet) {
        // Check packet type
        if let chat = packet as? Chat {
            self.handle(chat: chat)
        }
        
        // Foward packets to world
        if let channel = channel, let world = channel.world {
            world.handle(packet: packet, for: channel)
        }
    }
    
    func handle(chat: Chat) {
        if let channel = channel, let login = channel.login {
            // Check for a command
            if chat.message.starts(with: "/") {
                // Log
                channel.server.log("\(login.username) executed command \(chat.message)")
                
                // Handle a command
                let _ = chat.message.removeFirst()
                var args = chat.message.split(separator: " ").map {
                    String($0)
                }
                if args.count > 0 {
                    // Get command name
                    let name = args.removeFirst().lowercased()
                    
                    // Check if command exists
                    if let command = channel.server.commands[name] {
                        // Execute
                        command.execute(sender: channel, args: args)
                    } else {
                        // Command not found
                        channel.send(packet: Chat(message: ChatMessage(text: "Command /\(name) not found").with(color: .red)))
                    }
                }
                
                // Stop here
                return
            }
            
            // Create final message
            let message = ChatMessage(extra: [
                ChatMessage(text: "\(login.username): ").with(color: .aqua),
                ChatMessage(text: chat.message)
            ])
            
            // Send the message to all players
            channel.server.broadcast(packet: Chat(message: message))
            
            // Print in log the message
            channel.server.log(message.toString())
        }
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
