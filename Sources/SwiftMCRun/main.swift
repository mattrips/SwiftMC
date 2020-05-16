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
    
    @Option(help: "Number of slots on the server")
    var slots: Int?
    
    @Option(help: "The MOTD of the server")
    var motd: String?
    
    @Option(help: "Main world (in format type:name)")
    var world: String?
    
    func run() throws {
        // Get the latest version
        if let version = ProtocolConstants.supported_versions_ids.last {
            // Initialize a server
            let server = SwiftMC(configuration:
                Configuration(protocolVersion: version, port: port ?? 25565)
                    .with(slots: slots ?? 42)
                    .with(motd: motd ?? "A SwiftMC Server")
            )
            
            // Add a default world
            if let parts = world?.split(separator: ":").map({ String($0) }), parts.count >= 2 {
                if parts[0] == "local" && parts.count == 2 {
                    server.loadWorld(world: server.createLocalWorld(name: parts[1]))
                } else if parts[0] == "remote" && parts.count <= 3 {
                    if parts.count == 3, let port = Int(parts[2]) {
                        server.loadWorld(world: server.createRemoteWorld(host: parts[1], port: port))
                    } else {
                        server.loadWorld(world: server.createRemoteWorld(host: parts[1], port: 25565))
                    }
                } else {
                    server.loadWorld(world: server.createLocalWorld(name: "world"))
                }
            } else {
                server.loadWorld(world: server.createLocalWorld(name: "world"))
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
