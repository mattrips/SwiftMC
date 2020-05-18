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

class RemoteWorld: WorldProtocol {
    
    // Configuration
    let server: SwiftMC
    let host: String
    let port: Int
    let ipForward: Bool
    
    // Initialize a remote world
    init(server: SwiftMC, host: String, port: Int, ipForward: Bool = false) {
        self.server = server
        self.host = host
        self.port = port
        self.ipForward = ipForward
    }
    
    // Connect a client
    func connect(client: ChannelWrapper) {
        // Get address
        if let address = getAddress() {
            // Init the channel
            makeBootstrap(for: client).connect(to: address).whenSuccess() { channel in
                // Prepare handshake
                var host = self.host
                
                // Add ip forward parameters
                if self.ipForward {
                    host += "\0\(client.channel.remoteAddress?.ipAddress ?? "")\0\(client.getUUID().replacingOccurrences(of: "-", with: ""))"
                    if let properties = client.properties, let json = try? JSONSerialization.data(withJSONObject: properties, options: []), let string = String(bytes: json, encoding: .utf8) {
                        host += "\0\(string)"
                    }
                }
                
                // Send handshake
                client.remoteChannel?.send(packet: Handshake(protocolVersion: client.protocolVersion, host: host, port: Int16(self.port), requestedProtocol: 2))
                
                // Change protocol
                client.remoteChannel?.prot = .LOGIN
                
                // Login request
                client.remoteChannel?.send(packet: LoginRequest(data: client.getName()))
            }
        }
    }
    
    // Disconnect a client
    func disconnect(client: ChannelWrapper) {
        // Disconnect from the remote world
        client.remoteChannel?.close()
    }
    
    // Handle a packet from the client
    func handle(packet: Packet, for client: ChannelWrapper) {
        // Check packet type
        
        
        // Foward to the server
        client.remoteChannel?.send(packet: packet)
    }
    
    // Handle a packet from the remote world
    func remoteHandle(packet: Packet, for client: ChannelWrapper) {
        // Check packet type
        if let setCompresion = packet as? SetCompresion {
            // Set threshold
            client.remoteChannel?.threshold = setCompresion.threshold
            return
        }
        if let loginSuccess = packet as? LoginSuccess {
            // Store success and change to game protocol
            client.remoteChannel?.name = loginSuccess.username
            client.remoteChannel?.uuid = loginSuccess.uuid
            client.remoteChannel?.prot = .GAME
            return
        }
        if let login = packet as? Login, client.receivedLogin {
            // Send an immediate respawn if required
            if client.protocolVersion >= ProtocolConstants.minecraft_1_15 {
                client.send(packet: GameState(reason: GameState.immediate_respawn, value: login.normalRespawn ? 0 : 1))
            }
            
            // Convert to respawn packet
            if client.lastDimmension == login.dimension {
                client.send(packet: Respawn(dimension: login.dimension >= 0 ? -1 : 0, hashedSeed: login.seed, difficulty: login.difficulty, gameMode: login.gameMode, levelType: login.levelType))
            }
            client.send(packet: Respawn(dimension: login.dimension, hashedSeed: login.seed, difficulty: login.difficulty, gameMode: login.gameMode, levelType: login.levelType))
            client.lastDimmension = login.dimension
            return
        }
        if let kick = packet as? Kick {
            // Check if kick reason is because if forward
            if kick.message.contains("IP forwarding") {
                // Reconnect using ip forwarding
                client.goTo(world: RemoteWorld(server: server, host: host, port: port, ipForward: true))
                return
            }
            
            // Reconnect to default server, if not self
            if let main = client.server.worlds.first, main.getName() != getName() {
                client.goTo(world: main)
                client.sendMessage(message: ChatColor.red + "Disconnected: \(ChatMessage.decode(from: kick.message)?.toString() ?? "No reason")")
                return
            }
        }
        
        // Foward to client
        client.send(packet: packet)
    }
    
    // Ping server
    func pingWorld(from client: ChannelWrapper, completionHandler: @escaping (ServerInfo?) -> ()) {
        // Get address
        if let address = getAddress() {
            // Ping
            let reuseAddrOpt = ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR)
            ClientBootstrap(group: client.server.eventLoopGroup)
                .channelOption(reuseAddrOpt, value: 1)
                .channelInitializer { channel in
                    // Create objects
                    let decoder = MinecraftDecoder(server: false)
                    let encoder = MinecraftEncoder(server: false)
                    let wrapper = ChannelWrapper(session: self.generateSession(), server: client.server, channel: channel, decoder: decoder, encoder: encoder, prot: .HANDSHAKE, protocolVersion: client.protocolVersion)
                    
                    // Add client to list
                    client.pingChannel = wrapper
                    
                    // Add then to pipeline
                    return channel.pipeline.addHandlers([
                        ByteToMessageHandler(decoder),
                        MessageToByteHandler(encoder),
                        RemoteWorldPingHandler(channelWrapper: client, completionHandler: completionHandler)
                    ])
                }
                .connect(to: address)
                .whenComplete { result in
                    if (try? result.get()) != nil {
                        // Send handshake
                        client.pingChannel?.send(packet: Handshake(protocolVersion: client.protocolVersion, host: self.host, port: Int16(self.port), requestedProtocol: 1))
                        
                        // Change protocol
                        client.pingChannel?.prot = .STATUS
                        
                        // Login request
                        client.pingChannel?.send(packet: StatusRequest())
                    } else {
                        // Server not found
                        completionHandler(nil)
                    }
                }
        }
    }
    
    func getName() -> String {
        return "\(host):\(port)"
    }
    
    func getType() -> WorldType {
        return .remote
    }
    
    func getAddress() -> SocketAddress? {
        return try? SocketAddress.makeAddressResolvingHost(host, port: port)
    }
    
    // Get a new session id
    func generateSession() -> String {
        return UUID().uuidString.lowercased()
    }
    
    // Initialize a client channel
    func makeBootstrap(for client: ChannelWrapper) -> ClientBootstrap {
        let reuseAddrOpt = ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR)
        return ClientBootstrap(group: client.server.eventLoopGroup)
            .channelOption(reuseAddrOpt, value: 1)
            .channelInitializer { channel in
                // Create objects
                let decoder = MinecraftDecoder(server: false)
                let encoder = MinecraftEncoder(server: false)
                let wrapper = ChannelWrapper(session: self.generateSession(), server: client.server, channel: channel, decoder: decoder, encoder: encoder, prot: .HANDSHAKE, protocolVersion: client.protocolVersion)
                
                // Add client to list
                client.remoteChannel = wrapper
                
                // Add then to pipeline
                return channel.pipeline.addHandlers([
                    ByteToMessageHandler(decoder),
                    MessageToByteHandler(encoder),
                    RemoteWorldHandler(channelWrapper: client)
                ])
            }
    }
    
    // Remote world reader
    class RemoteWorldHandler: ChannelInboundHandler, ChannelHandler {
        
        // Requirements
        public typealias InboundIn = Packet
        public typealias OutboundOut = Packet
        
        // Variables
        let channelWrapper: ChannelWrapper
        var handler: PacketHandler?
        
        // Initializer
        init(channelWrapper: ChannelWrapper) {
            self.channelWrapper = channelWrapper
            self.channelWrapper.remoteChannel?.handler = self
        }
        
        // Read a packet from remote world
        public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            // Read wrapper
            let packet = unwrapInboundIn(data)
            
            // Check for debug
            if channelWrapper.server.configuration.debug {
                channelWrapper.server.log("WORLD -> SERVER: \(packet.toString())")
            }
            
            // Get remote world
            if let world = channelWrapper.world as? RemoteWorld {
                world.remoteHandle(packet: packet, for: channelWrapper)
            }
        }
        
    }
    
    class RemoteWorldPingHandler: ChannelInboundHandler, ChannelHandler {
        
        // Requirements
        public typealias InboundIn = Packet
        public typealias OutboundOut = Packet
        
        // Variables
        let channelWrapper: ChannelWrapper
        var handler: PacketHandler?
        var completionHandler: (ServerInfo?) -> ()
        
        // Initializer
        init(channelWrapper: ChannelWrapper, completionHandler: @escaping (ServerInfo?) -> ()) {
            self.channelWrapper = channelWrapper
            self.completionHandler = completionHandler
            self.channelWrapper.pingChannel?.handler = self
        }
        
        // Read a packet from remote world
        public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            // Read wrapper
            let packet = unwrapInboundIn(data)
            
            // Check for debug
            if channelWrapper.server.configuration.debug {
                channelWrapper.server.log("WORLD -> SERVER: \(packet.toString())")
            }
            
            // Get remote world
            if let response = packet as? StatusResponse {
                completionHandler(ServerInfo.decode(from: response.response))
            }
        }
        
    }
    
}
