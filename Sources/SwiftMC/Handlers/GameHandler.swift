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
        
        // Fire PlayerConnectEvent
        let event = PlayerConnectEvent(player: channel, world: channel.server.worlds.first)
        channel.server.fireListeners(for: event)
        
        // Login to the selected world
        if let world = event.world {
            channel.goTo(world: world)
        } else {
            disconnect(reason: "No world found on this server!")
            return
        }
    }
    
    func disconnected(channel: ChannelWrapper) {
        // Remove channel
        self.channel = nil
        
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
            if self.handle(chat: chat) {
                return
            }
        }
        
        // Foward packets to world
        if let channel = channel, let world = channel.world {
            world.handle(packet: packet, for: channel)
        }
    }
    
    func handle(chat: Chat) -> Bool {
        if let channel = channel {
            // Check for a command
            if chat.message.starts(with: "/") {
                // Handle the command
                let follow = channel.world as? RemoteWorld != nil
                if channel.server.dispatchCommand(sender: channel, command: String(chat.message.suffix(chat.message.count - 1)), showError: !follow) {
                    return true
                }
                return !follow
            }
        }
        return false
    }
    
    func disconnect(reason: String) {
        channel?.kick(reason: reason)
    }
    
}
