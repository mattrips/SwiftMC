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
            server.loadWorld(world: server.createLocalWorld(name: "world"))
            
            // And start it
            server.start()
        }
    }
    
}

Server.main()
