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
public class SwiftMC: CommandSender {
    
    // Publics vars
    public let configuration: Configuration
    public var players: [Player] {
        get {
            return clients.filter { client in
                client.login != nil
            }
        }
    }
    public var isRunning: Bool {
        get {
            return running
        }
    }
    
    // Internal vars
    internal var running: Bool = false
    internal let eventLoopGroup: EventLoopGroup
    internal var serverChannel: Channel?
    internal var commands: [String: Command]
    internal var listeners: [EventListener]
    internal var worlds: [WorldProtocol]
    internal var clients: [ChannelWrapper]

    // Initializer
    public init(configuration: Configuration) {
        self.configuration = configuration
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.commands = [:]
        self.listeners = []
        self.worlds = []
        self.clients = []
    }
    
    // Start server
    public func start() {
        // Start
        log("Starting server...")
        running = true
        
        // Register basic commands
        log("Registering server commands...")
        registerCommand("stop", command: StopCommand())
        registerCommand("help", command: HelpCommand())
        registerCommand("chat", command: ChatCommand())
        registerCommand("world", command: WorldCommand())
        
        // Load worlds
        log("Loading worlds...")
        
        // Start a timer for KeepAlive
        eventLoopGroup.next().scheduleRepeatedTask(initialDelay: TimeAmount.seconds(1), delay: TimeAmount.seconds(1)) { task in
            // Send keep alive to connected clients
            self.players.filter { player in
                if let channel = player as? ChannelWrapper {
                    return channel.remoteChannel == nil
                }
                return false
            }.forEach { player in
                if let channel = player as? ChannelWrapper {
                    channel.send(packet: KeepAlive())
                }
            }
        }
        
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
                logError("ERROR: server reported no local address?")
            }
        } catch let error as NIO.IOError {
            // Error starting server
            logError("ERROR: failed to start server, errno: \(error.errnoCode)\n\(error.localizedDescription)")
        } catch {
            // Error starting server
            logError("ERROR: failed to start server: \(type(of: error))\(error)")
        }
        
        // Wait
        do {
            try serverChannel?.closeFuture.wait()
            running = false
        } catch {
            logError("ERROR: Failed to wait on server: \(error)")
        }
    }

    // Stop server
    public func stop() {
        players.forEach { player in
            player.kick(reason: "Server closed")
        }
        serverChannel?.close().whenComplete({ _ in
            self.log("Stopping server...")
        })
    }
    
    // Initialize server channels
    func makeBootstrap() -> ServerBootstrap {
        let reuseAddrOpt = ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR)
        return ServerBootstrap(group: eventLoopGroup)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: Int32(256))
            .serverChannelOption(reuseAddrOpt, value: 1)
        
            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer { channel in
                // Create objects
                let decoder = MinecraftDecoder(server: true)
                let encoder = MinecraftEncoder(server: true)
                let wrapper = ChannelWrapper(session: self.generateSession(), server: self, channel: channel, decoder: decoder, encoder: encoder, prot: .HANDSHAKE, protocolVersion: self.configuration.protocolVersion)
                
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
    }
    
    // Log
    func log(_ message: ChatMessage) {
        // Allow custom log channels (like remote access)
        configuration.logger(ChatMessage(extra: [
            ChatMessage(text: "§r[\(getCurrentTime())] "), message
        ]))
    }
    
    func log(_ string: String) {
        // Send with correct format
        log(ChatMessage(text: string))
    }
    
    func logError(_ string: String) {
        // Send with correct format
        log(ChatMessage(text: string).with(format: .red))
    }
    
    func getCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm:ss"
        return formatter.string(from: Date())
    }
    
    // Get server infos for ping
    func getServerInfo(preferedProtocol: Int32) -> ServerInfo {
        // Get players
        let players = self.players
        
        // Return the payload
        return ServerInfo(
            version: ServerInfo.ServerVersion(
                name: "SwiftMC *",
                protocolVersion: Int(ProtocolConstants.supported_versions_ids.contains(preferedProtocol) ? preferedProtocol : configuration.protocolVersion)
            ),
            players: ServerInfo.ServerPlayers(
                max: configuration.slots,
                online: players.count,
                sample: []
            ),
            description: ChatMessage(text: configuration.motd ?? "A SwiftMC server"),
            favicon: configuration.favicon
        )
    }
    
    // Broadcast a packet to all players
    func broadcast(packet: Packet) {
        // Send to all players
        players.forEach { player in
            if let channel = player as? ChannelWrapper {
                channel.send(packet: packet)
            }
        }
        
        // Check for a chat message to log it
        if let chat = packet as? Chat, let message = ChatMessage.decode(from: chat.message) {
            sendMessage(message: message)
        }
    }
    
    // Call listeners
    func fireListeners(for event: Event) {
        for listener in listeners {
            event.call(listener: listener)
        }
    }
    
    // Get a new session id
    func generateSession() -> String {
        var session: String
        repeat {
            session = UUID().uuidString.lowercased()
        } while !clients.filter({ $0.session == session }).isEmpty
        return session
    }
    
    // Register a command
    public func registerCommand(_ name: String, command: Command) {
        let name = name.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " "))
        if commands[name] != nil {
            return
        }
        commands[name] = command
        log("Registered command /\(name)")
    }
    
    // Get name of a command sender
    public func getName() -> String {
        return "Server"
    }
    
    // Send a message to the server
    public func sendMessage(message: ChatMessage) {
        log(message)
    }
    
    // Unregister a command
    public func unregisterCommand(_ name: String) {
        let name = name.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " "))
        commands.removeValue(forKey: name)
        log("Unregistered command /\(name)")
    }
    
    // Register a listener
    public func registerListener(listener: EventListener) {
        listeners.append(listener)
    }
    
    // Load a world
    public func loadWorld(world: WorldProtocol) {
        worlds.append(world)
        log("Loaded one world!")
    }
    
    // Create a local world
    public func createLocalWorld(name: String) -> WorldProtocol {
        return LocalWorld(server: self, name: name)
    }
    
    // Create a remote world
    public func createRemoteWorld(host: String, port: Int) -> WorldProtocol {
        return RemoteWorld(server: self, host: host, port: port)
    }
    
    // Dispatch a command
    @discardableResult
    public func dispatchCommand(sender: CommandSender, command: String, showError: Bool = true) -> Bool {
        // Log
        log("\(sender.getName()) executed command /\(command)")
        
        // Get args
        var args = command.split(separator: " ").map {
            String($0)
        }
        if args.count > 0 {
            // Get command name
            let name = args.removeFirst().lowercased()
            
            // Check if command exists
            if let command = commands[name] {
                // Execute
                command.execute(server: self, sender: sender, args: args)
                return true
            } else if showError {
                // Command not found
                sender.sendMessage(message: ChatColor.red + "Command /\(name) not found")
            }
        }
        return false
    }
    
    @discardableResult
    public func dispatchCommand(command: String, showError: Bool = true) -> Bool {
        dispatchCommand(sender: self, command: command, showError: showError)
    }
    
}
