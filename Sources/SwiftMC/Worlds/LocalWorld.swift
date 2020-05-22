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

class LocalWorld: WorldProtocol {
    
    // Configuration
    public let server: SwiftMC
    public let name: String
    public let path: URL
    public let config: WorldConfiguration
    
    // World map
    private var regions: [WorldRegion]
    private var chunks: [WorldChunk]
    
    // Connected clients
    var clients: [ChannelWrapper]
    
    // Initialize a remote world
    init(server: SwiftMC, name: String) {
        self.server = server
        self.name = name
        self.path = server.serverRoot.appendingPathComponent(name, isDirectory: true)
        self.config = WorldConfiguration()
        self.regions = []
        self.chunks = []
        self.clients = []
    }
    
    func connect(client: ChannelWrapper) {
        // Add to clients
        clients.append(client)
        
        // Login player
        let login = Login(entityId: 1, gameMode: 1, dimension: 0, seed: 0, difficulty: 0, maxPlayers: 1, levelType: "default", viewDistance: 16, reducedDebugInfo: false, normalRespawn: true)
        
        // Check if a login was already handled
        if !client.receivedLogin {
            // Just send login
            client.send(packet: login)
        } else {
            // Send an immediate respawn if required
            if client.protocolVersion >= ProtocolConstants.minecraft_1_15 {
                client.send(packet: GameState(reason: GameState.immediate_respawn, value: login.normalRespawn ? 0 : 1))
            }
            
            // Convert to respawn packet
            if client.lastDimmension == login.dimension {
                client.send(packet: Respawn(dimension: login.dimension >= 0 ? -1 : 0, hashedSeed: login.seed, difficulty: login.difficulty, gameMode: login.gameMode, levelType: login.levelType))
            }
            client.send(packet: Respawn(dimension: login.dimension, hashedSeed: login.seed, difficulty: login.difficulty, gameMode: login.gameMode, levelType: login.levelType))
        }
        
        // Save current dimension
        client.lastDimmension = login.dimension
        
        // Get spawn location for player
        let location = Location(world: self, x: Double(config.spawnX), y: Double(config.spawnY), z: Double(config.spawnZ), yaw: 0, pitch: 0)
        
        // Send chunks
        for x in -3 ..< 4 {
            for z in -3 ..< 4 {
                let chunkX = Int32(Int(location.x) >> 4 + x)
                let chunkZ = Int32(Int(location.z) >> 4 + z)
                client.send(packet: getChunk(x: chunkX, z: chunkZ).toMapChunkPacket())
            }
        }
        
        // Send position
        client.send(packet: location.toPositionServerPacket())
        
        // Fire PlayerJoinEvent
        let event = PlayerJoinEvent(player: client, message: "\(ChatColor.green)[+] \(ChatColor.yellow)\(client.getName())")
        client.server.fireListeners(for: event)
        broadcast(packet: Chat(message: ChatMessage(text: event.message)))
        
        // Send PlayerInfo
        for player in clients {
            // Create the packet
            let packet = PlayerInfo(action: .add_player, items: [PlayerInfo.Item(uuid: player.uuid, username: player.name, properties: player.properties?.map({ properties in
                properties.map({ property in
                    property.value as? String ?? ""
                })
            }), gamemode: 0, ping: 0, displayname: nil)])
            
            // Send it
            player.getUUID() == client.getUUID() ? broadcast(packet: packet) : client.send(packet: packet)
        }
    }
    
    func disconnect(client: ChannelWrapper) {
        // Fire PlayerQuitEvent
        let event = PlayerQuitEvent(player: client, message: "\(ChatColor.red)[-] \(ChatColor.yellow)\(client.getName())")
        client.server.fireListeners(for: event)
        broadcast(packet: Chat(message: ChatMessage(text: event.message)))
        
        // Send PlayerInfo
        for player in clients {
            // Create the packet
            let packet = PlayerInfo(action: .remove_player, items: [PlayerInfo.Item(uuid: player.uuid)])
            
            // Send it
            player.getUUID() == client.getUUID() ? broadcast(packet: packet) : client.send(packet: packet)
        }
        
        // Remove client from current clients
        clients.removeAll(where: { current in
            current.session == client.session
        })
    }
    
    func handle(packet: Packet, for client: ChannelWrapper) {
        // Check packet type
        if let chat = packet as? Chat {
            handle(chat: chat, for: client)
        }
    }
    
    func handle(chat: Chat, for client: ChannelWrapper) {
        // Fire PlayerChatEvent
        let event = PlayerChatEvent(player: client, message: chat.message, format: "\(ChatColor.aqua)[%@] \(ChatColor.reset)%@")
        client.server.fireListeners(for: event)
        broadcast(packet: Chat(message: ChatMessage(text: String(format: event.format, client.getName(), event.message))))
    }
    
    func pingWorld(from client: ChannelWrapper, completionHandler: @escaping (ServerInfo?) -> ()) {
        completionHandler(nil)
    }
    
    func getName() -> String {
        return name
    }
    
    func getType() -> WorldType {
        return .local
    }
    
    func getPlayers() -> [Player] {
        return clients
    }
    
    func load() {
        // Start loading the world
        server.log("Start loading local world: \(name)")
        
        do {
            // Check if the world folder exists
            if !FileManager.default.fileExists(atPath: path.path) {
                // Create a folder
                server.log("Creating a new folder... (\(path.path))")
                try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Read the configuration from the disk
            let level_dat = path.appendingPathComponent("level.dat")
            try config.read(from: level_dat)
            
            // Load main chunks
            let width = 7
            let spawn = Location(world: self, x: Double(config.spawnX), y: Double(config.spawnY), z: Double(config.spawnZ), yaw: 0, pitch: 0)
            let progressBar = ChatProgressBar(total: width * width, width: 50)
            for x in 0 ..< width {
                for z in 0 ..< width {
                    let chunkX = Int32(Int(spawn.x) >> 4 + x - width/2)
                    let chunkZ = Int32(Int(spawn.z) >> 4 + z - width/2)
                    let _ = getChunk(x: chunkX, z: chunkZ)
                    server.log(progressBar.increment())
                }
            }
        } catch {
            // An error occurred loading the world
            server.logError("An error occurred loading local world: \(name)")
        }
    }
    
    func save() {
        // Start saving the world
        server.log("Saving local world: \(name)")
        
        do {
            // Save the level.dat file
            try config.save(to: path.appendingPathComponent("level.dat"))
            
            // Save loaded regions
            // ...
        } catch {
            // An error occurred saving the world
            server.logError("An error occurred saving local world: \(name)")
        }
    }
    
    func getRegion(x: Int32, z: Int32) -> WorldRegion {
        // Return existing region if exists
        if let region = regions.first(where: { $0.x == x && $0.z == z }) {
            return region
        }
        
        // Init a new region
        let region = WorldRegion(world: self, x: x, z: z)
        regions.append(region)
        return region
    }
    
    func getChunk(x: Int32, z: Int32) -> WorldChunk {
        // Return existing chunk if exists
        if let chunk = chunks.first(where: { $0.x == x && $0.z == z }) {
            return chunk
        }
        
        // Retrieve from a region
        let chunk = getRegion(x: x >> 5, z: z >> 5).getChunk(x: x & (WorldRegion.region_size - 1), z: z & (WorldRegion.region_size - 1))
        chunks.append(chunk)
        return chunk
    }
    
    func broadcast(packet: Packet) {
        // Send to all players
        clients.forEach { client in
            client.send(packet: packet)
        }
        
        // Check for a chat message to log it
        if let chat = packet as? Chat, let message = ChatMessage.decode(from: chat.message) {
            server.sendMessage(message: "[WORLD: \(getName())] \(message.toString())")
        }
    }
    
}

struct WorldError: Error {}
