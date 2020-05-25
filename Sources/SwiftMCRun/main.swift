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
import ArgumentParser
import SwiftMC

struct Server: ParsableCommand {
    
    @Option(help: "Port of the server")
    var port: Int?
    
    @Option(help: "Authentification mode (online, offline, auto)")
    var mode: String?
    
    @Option(help: "Number of slots on the server")
    var slots: Int?
    
    @Option(help: "The MOTD of the server")
    var motd: String?
    
    @Option(help: "Main world (in format type:name)")
    var world: String?
    
    @Option(help: "View distance (in chunks)")
    var viewDistance: Int?
    
    @Option(help: "Enable debug")
    var debug: Bool?
    
    func run() throws {
        // Get the latest version
        if let version = ProtocolConstants.supported_versions_ids.last {
            // Initialize a server
            let server = SwiftMC(configuration:
                Configuration(protocolVersion: version, port: port ?? 25565)
                    .with(mode: mode == "auto" ? .auto : mode == "offline" ? .offline : .online)
                    .with(slots: slots ?? 42)
                    .with(motd: motd ?? "A SwiftMC Server")
                    .with(viewDistance: Int32(viewDistance ?? 16))
                    .enable(debug: debug ?? false)
            )
            
            // Add worlds
            for world in world?.split(separator: ";") ?? [] {
                let parts = world.split(separator: ":").map({ String($0) })
                if parts.count >= 2 {
                    if parts[0] == "local" && parts.count == 2 {
                        server.registerLocalWorld(name: parts[1])
                    } else if parts[0] == "remote" && parts.count <= 3 {
                        if parts.count == 3, let port = Int(parts[2]) {
                            server.registerRemoteWorld(host: parts[1], port: port)
                        } else {
                            server.registerRemoteWorld(host: parts[1], port: 25565)
                        }
                    } else {
                        server.registerLocalWorld(name: "world")
                    }
                }
            }
            
            // Load default world if empty
            if server.worlds.isEmpty {
                server.registerLocalWorld(name: "world")
            }
            
            // And start it
            DispatchQueue.global().async {
                server.start()
            }
            
            // Read commands from console
            while let input = readLine(strippingNewline: true) {
                server.dispatchCommand(command: input)
            }
        }
    }
    
}

Server.main()
