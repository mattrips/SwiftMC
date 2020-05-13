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
    
    // Vars
    var server: SwiftMC
    var channel: Channel
    var handler: ClientHandler?
    var decoder: MinecraftDecoder
    var encoder: MinecraftEncoder
    var login: LoginSuccess?
    var closed: Bool = false
    var closing: Bool = false
    
    init(server: SwiftMC, channel: Channel, decoder: MinecraftDecoder, encoder: MinecraftEncoder) {
        self.server = server
        self.channel = channel
        self.decoder = decoder
        self.encoder = encoder
    }
    
    func setProtocol(prot: Prot) {
        decoder.prot = prot
        encoder.prot = prot
    }
    
    func setVersion(version: Int32) {
        decoder.protocolVersion = version
        encoder.protocolVersion = version
    }
    
    func setHandler(handler: PacketHandler) {
        self.handler?.handler?.disconnected(channel: self)
        self.handler?.handler = handler
        self.handler?.handler?.connected(channel: self)
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
                server.log("SERVER -> CLIENT: \(packet.toString())")
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
