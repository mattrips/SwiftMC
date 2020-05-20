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

public class ChannelWrapper: Player {
    
    // Channel related
    var session: String
    var server: SwiftMC
    var channel: Channel
    var handler: ChannelHandler?
    var threshold: Int32 = -1
    var closed: Bool = false
    var closing: Bool = false
    var promise: EventLoopPromise<Void>?
    
    // Other channels
    var remoteChannel: ChannelWrapper?
    var pingChannel: ChannelWrapper?
    
    // Encoding/Decoding
    var decoder: MinecraftDecoder
    var encoder: MinecraftEncoder
    var protocolVersion: Int32
    var prot: Prot
    
    // Encryption
    var encryptionRequest: EncryptionRequest?
    var sharedKey: [UInt8]?
    
    // Player related
    var receivedLogin: Bool = false
    var onlineMode: Bool = false
    var lastDimmension: Int32?
    var properties: [[String: Any]]?
    var name: String?
    var uuid: String?
    var accessToken: String?
    var world: WorldProtocol?
    
    // Plugin message channels
    var pluginMessageChannels = [String]()
    
    init(session: String, server: SwiftMC, channel: Channel, decoder: MinecraftDecoder, encoder: MinecraftEncoder, prot: Prot, protocolVersion: Int32) {
        self.session = session
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
    
    func send(packet: Packet, newProtocol: Prot? = nil, threshold: Int32? = nil, sharedKey: [UInt8]? = nil) {
        if !closed {
            // Check packet type
            if packet as? Login != nil {
                if receivedLogin {
                    // Don't send again
                    return
                }
                receivedLogin = true
            }
            if let pluginMessage = packet as? PluginMessage {
                if !pluginMessageChannels.contains(pluginMessage.tag) && pluginMessage.tag != "minecraft:register" && pluginMessage.tag != "REGISTER" {
                    // Don't send the message
                    return
                }
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
            let newPromise = channel.eventLoop.makePromise(of: Void.self)
            let send = {
                // Packet content
                self.channel.writeAndFlush(packet, promise: newPromise)
                
                // Update threshold
                if let threshold = threshold {
                    self.threshold = threshold
                }
                
                // Protocol switching
                if let newProtocol = newProtocol {
                    self.prot = newProtocol
                }
                
                // Shared key registration
                if let sharedKey = sharedKey {
                    self.sharedKey = sharedKey
                    self.decoder.iv = sharedKey
                    self.encoder.iv = sharedKey
                }
            }
            if let promise = promise {
                // After current waiting list
                promise.futureResult.whenComplete { _ in
                    send()
                }
            } else {
                // Now
                send()
            }
            self.promise = newPromise
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
                session == client.session
            })
            
            // Fire PlayerDisconnectEvent
            let event = PlayerDisconnectEvent(player: self)
            server.fireListeners(for: event)
            
            // Send close packet if there is one
            if let packet = packet {
                let _ = channel.writeAndFlush(packet).and(channel.close())
            } else {
                channel.flush()
                let _ = channel.close()
            }
        }
    }
    
    // Adapters for outside
    
    public func getName() -> String {
        return name ?? "Player"
    }
    
    public func getUUID() -> String {
        return uuid ?? "NULL"
    }
    
    public func sendMessage(message: ChatMessage) {
        self.send(packet: Chat(message: message))
    }
    
    public func goTo(world: WorldProtocol) {
        self.world?.disconnect(client: self)
        self.remoteChannel = nil
        self.world = world
        self.world?.connect(client: self)
    }
    
    public func kick(reason: String) {
        if let json = ChatMessage(text: reason).toJSON() {
            close(packet: Kick(message: json))
        } else {
            close()
        }
    }
    
    public func isOnlineMode() -> Bool {
        return onlineMode
    }
    
    public func setTabListMessage(header: ChatMessage, footer: ChatMessage) {
        send(packet: PlayerListHeaderFooter(header: header.toJSON() ?? "{}", footer: footer.toJSON() ?? "{}"))
    }
    
}
