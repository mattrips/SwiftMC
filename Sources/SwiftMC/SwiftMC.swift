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

// Main class
public class SwiftMC {
    
    // Variables
    let configuration: Configuration
    let eventLoopGroup: EventLoopGroup
    var serverChannel: Channel?
    var clients: [ChannelWrapper]
    var players: [ChannelWrapper] {
        get {
            return clients.filter { client in
                client.login != nil
            }
        }
    }

    // Initializer
    public init(configuration: Configuration) {
        self.configuration = configuration
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.clients = []
    }
    
    // Start server
    public func start() {
        // Start
        log("Starting server...")
        
        // Start a timer for KeepAlive
        Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(keepAlive), userInfo: nil, repeats: true)
        
        // Listen and wait
        listen()
        do {
            try serverChannel?.closeFuture.wait()
        } catch {
            log("ERROR: Failed to wait on server: \(error)")
        }
    }

    // Listen
    func listen() {
        // Create server bootstrap
        let bootstrap = makeBootstrap()
        do {
            // Get address
            var addr = sockaddr_in()
            addr.sin_port = in_port_t(configuration.port).bigEndian
            let address = SocketAddress(addr, host: "*")
            
            // Create server channel
            serverChannel = try bootstrap.bind(to: address).wait()
            
            // Check that everything is running
            if let addr = serverChannel?.localAddress {
                log("Server running on port \(addr.port ?? 25565)")
            } else {
                log("ERROR: server reported no local address?")
            }
        } catch let error as NIO.IOError {
            // Error starting server
            log("ERROR: failed to start server, errno: \(error.errnoCode)\n\(error.localizedDescription)")
        } catch {
            // Error starting server
            log("ERROR: failed to start server: \(type(of: error))\(error)")
        }
    }
    
    func makeBootstrap() -> ServerBootstrap {
        let reuseAddrOpt = ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR)
        return ServerBootstrap(group: eventLoopGroup)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: Int32(256))
            .serverChannelOption(reuseAddrOpt, value: 1)
        
            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer { channel in
                // Create objects
                let decoder = MinecraftDecoder(prot: Prot.HANDSHAKE, server: true, protocolVersion: self.configuration.protocolVersion)
                let encoder = MinecraftEncoder(prot: Prot.HANDSHAKE, server: true, protocolVersion: self.configuration.protocolVersion)
                let wrapper = ChannelWrapper(server: self, channel: channel, decoder: decoder, encoder: encoder)
                
                // Add client to list
                self.clients.append(wrapper)
                
                // Add then to pipeline
                return channel.pipeline.addHandlers([
                    ByteToMessageHandler(decoder),
                    MessageToByteHandler(encoder),
                    ClientHandler(channelWrapper: wrapper)
                ])
            }
        
            // Enable TCP_NODELAY and SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(reuseAddrOpt, value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
    }
    
    @objc func keepAlive() {
        // Send keep alive to connected clients
        clients.forEach { wrapper in
            wrapper.send(packet: KeepAlive())
        }
    }
    
    func log(_ string: String) {
        // Allow custom log channels (like remote access)
        print("[\(Date())] \(string)")
    }
    
    func getServerInfo(preferedProtocol: Int32) -> [String: Any] {
        // Get players
        let players = self.players
        
        // Return the payload
        return [
            "version": [
                "name": "SwiftMC *",
                "protocol": ProtocolConstants.supported_versions_ids.contains(preferedProtocol) ? preferedProtocol : configuration.protocolVersion
            ],
            "players": [
                "max": configuration.slots,
                "online": players.count,
                "sample": []
            ],
            "description": [
                "text": "SwiftMC: \(configuration.name)"
            ]
        ]
    }
    
}
