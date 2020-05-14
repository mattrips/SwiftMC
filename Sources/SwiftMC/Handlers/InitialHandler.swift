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

class InitialHandler: PacketHandler {
    
    var channel: ChannelWrapper?
    
    func connected(channel: ChannelWrapper) {
        self.channel = channel
    }
    
    func disconnected(channel: ChannelWrapper) {
        self.channel = nil
    }
    
    func shouldHandle(packet: Packet) -> Bool {
        return !(channel?.closing ?? true)
    }
    
    func handle(packet: Packet) {
        // Check packet type
        if let pingPacket = packet as? PingPacket {
            self.handle(pingPacket: pingPacket)
        }
        if let handshake = packet as? Handshake {
            self.handle(handshake: handshake)
        }
        if let statusRequest = packet as? StatusRequest {
            self.handle(statusRequest: statusRequest)
        }
        if let loginRequest = packet as? LoginRequest {
            self.handle(loginRequest: loginRequest)
        }
    }
    
    func handle(pingPacket: PingPacket) {
        // Send back
        channel?.send(packet: pingPacket)
        
        // And disconnect
        channel?.close()
    }
    
    func handle(handshake: Handshake) {
        if let channel = channel {
            // Save
            channel.protocolVersion = handshake.protocolVersion
            
            // Remove FML from host
            if handshake.host.contains("\0") {
                let split = handshake.host.split(separator: "\0", maxSplits: 2, omittingEmptySubsequences: true)
                handshake.host = String(split[0])
            }
            
            // Remove . at the end (dns record)
            if handshake.host.count > 0 && handshake.host.last == "." {
                let _ = handshake.host.removeLast()
            }
            
            // Check request protocol
            switch handshake.requestedProtocol {
                
            case 1:
                // Ping
                channel.prot = .STATUS
            case 2:
                // Login
                channel.prot = .LOGIN
                
                // Check server/client version
                if !ProtocolConstants.supported_versions_ids.contains(handshake.protocolVersion) {
                    if handshake.protocolVersion > channel.server.configuration.protocolVersion {
                        disconnect(reason: "Outdated server!")
                    } else {
                        disconnect(reason: "Outdated client!")
                    }
                }
            default:
                return
                
            }
        }
    }
    
    func handle(statusRequest: StatusRequest) {
        // Send packet
        if let channel = channel, let json = channel.server.getServerInfo(preferedProtocol: channel.protocolVersion).toJSON() {
            channel.send(packet: StatusResponse(response: json))
        }
    }
    
    func handle(loginRequest: LoginRequest) {
        if let channel = channel {
            // Check number of slots + not already connected
            let connected = channel.server.players.count
            let slots = channel.server.configuration.slots
            if connected >= slots {
                // To many people
                disconnect(reason: "Too many people are connected, try again later!")
                return
            }
            
            // Check for online mode
            // If yes, send encryption packet
            // Else, finish
            

            // Get UUID
            if let uuid = loginRequest.data.getUUID() {
                // End login
                finish(success: LoginSuccess(uuid: uuid, username: loginRequest.data))
            }
        }
    }
    
    func finish(success: LoginSuccess) {
        // Enable threshold
        channel?.send(packet: SetCompresion(threshold: 256))
        channel?.threshold = 256
        
        // Send success packet and switch to game protocol
        channel?.server.log("Authenticating player \(success.username)... (\(success.uuid))")
        channel?.send(packet: success)
        channel?.prot = .GAME
        channel?.setHandler(handler: GameHandler())
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
