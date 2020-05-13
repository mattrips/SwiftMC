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

public class ChannelWrapper {
    
    // Channel related
    var server: SwiftMC
    var channel: Channel
    var handler: ChannelHandler?
    var threshold: Int32 = -1
    var closed: Bool = false
    var closing: Bool = false
    
    // Encoding/Decoding
    var decoder: MinecraftDecoder
    var encoder: MinecraftEncoder
    var protocolVersion: Int32
    var prot: Prot
    
    // Player related
    var login: LoginSuccess?
    var world: WorldProtocol?
    var remoteChannel: ChannelWrapper?
    
    init(server: SwiftMC, channel: Channel, decoder: MinecraftDecoder, encoder: MinecraftEncoder, prot: Prot, protocolVersion: Int32) {
        self.server = server
        self.channel = channel
        self.decoder = decoder
        self.encoder = encoder
        self.prot = prot
        self.protocolVersion = protocolVersion
        self.decoder.channel = self
        self.encoder.channel = self
    }
    
    func setHandler(handler: PacketHandler) {
        self.handler?.handler?.disconnected(channel: self)
        self.handler?.handler = handler
        self.handler?.handler?.connected(channel: self)
    }
    
    func setWorld(world: WorldProtocol) {
        self.world?.disconnect(client: self)
        self.remoteChannel = nil
        self.world = world
        self.world?.connect(client: self)
    }
    
    func send(packet: Packet) {
        if !closed {
            // Check packet type
            if let login = packet as? LoginSuccess {
                // Save user login
                self.login = login
            }
            
            // Check for debug
            if server.configuration.debug {
                if handler is RemoteWorld.RemoteWorldHandler {
                    server.log("SERVER -> WORLD: \(packet.toString())")
                } else {
                    server.log("SERVER -> CLIENT: \(packet.toString())")
                }
            }
            
            // Send packet
            channel.writeAndFlush(packet, promise: nil)
        }
    }
    
    func close(packet: Packet? = nil) {
        if !closed {
            // Mark as closed
            closing = true
            closed = true
            handler?.handler?.disconnected(channel: self)
            
            // Remove from server clients
            server.clients.removeAll(where: { client in
                client.channel.localAddress == channel.localAddress
            })
            
            // Send close packet if there is one
            if let packet = packet {
                let _ = channel.writeAndFlush(packet).and(channel.close())
            } else {
                channel.flush()
                let _ = channel.close()
            }
        }
    }
    
}
