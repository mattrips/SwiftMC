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
    
    func bindChannel(channel: ChannelWrapper?) {
        self.channel = channel
        
        if let channel = channel {
            // Send login packet (game starts)
            channel.send(packet: Login(entityId: 1, gameMode: 1, dimension: 0, seed: 0, difficulty: 0, maxPlayers: 1, levelType: "DEFAULT", viewDistance: 16, reducedDebugInfo: false, normalRespawn: true))
        }
    }
    
    func connected(channel: ChannelWrapper) {
        self.channel = channel
    }
    
    func disconnected(channel: ChannelWrapper) {
        self.channel = nil
    }
    
    func shouldHandle(wrapper: PackerWrapper) -> Bool {
        return !(channel?.closing ?? true)
    }
    
    func handle(wrapper: PackerWrapper) {
        // Check packet type
        if let keepAlive = wrapper.packet as? KeepAlive {
            self.handle(keepAlive: keepAlive)
        }
    }
    
    func handle(keepAlive: KeepAlive) {
        // Send back the packet
        channel?.send(packet: keepAlive)
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
