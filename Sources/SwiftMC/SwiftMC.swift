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
    let protocolVersion: Int32
    let port: Int
    let eventLoopGroup: EventLoopGroup
    var serverChannel: Channel?

    // Initializer
    public init(protocolVersion: Int32, port: Int) {
        self.protocolVersion = protocolVersion
        self.port = port
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    }
    
    // Start server
    public func start() {
        // Listen and wait
        listenAndWait()
    }
    
    // Start listening
    func listenAndWait() {
        listen()
        do {
            try serverChannel?.closeFuture.wait()
        } catch {
            print("[!] ERROR: Failed to wait on server: \(error)")
        }
    }

    // Listen
    func listen() {
        // Create server bootstrap
        let bootstrap = makeBootstrap()
        do {
            // Get address
            var addr = sockaddr_in()
            addr.sin_port = in_port_t(port).bigEndian
            let address = SocketAddress(addr, host: "*")
            
            // Create server channel
            serverChannel = try bootstrap.bind(to: address).wait()
            
            // Check that everything is running
            if let addr = serverChannel?.localAddress {
                print("[+] Server running on: \(addr)")
            } else {
                print("[!] ERROR: server reported no local address?")
            }
        } catch let error as NIO.IOError {
            // Error starting server
            print("[!] ERROR: failed to start server, errno: \(error.errnoCode)\n\(error.localizedDescription)")
        } catch {
            // Error starting server
            print("[!] ERROR: failed to start server: \(type(of: error))\(error)")
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
                channel.pipeline.addHandler(ByteToMessageHandler(MinecraftDecoder(prot: Prot.HANDSHAKE, server: true, protocolVersion: self.protocolVersion)), name: "PACKER_DECODER", position: .last).flatMap {
                    channel.pipeline.addHandler(MessageToByteHandler(MinecraftEncoder(prot: Prot.HANDSHAKE, server: true, protocolVersion: self.protocolVersion)), name: "PACKER_ENCODER", position: .last)
                }.flatMap {
                    channel.pipeline.addHandler(ClientHandler(protocolVersion: self.protocolVersion), name: "BOSS_HANDLER", position: .last)
                }
            }
        
            // Enable TCP_NODELAY and SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(reuseAddrOpt, value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
    }
    
}
