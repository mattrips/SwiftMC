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

class Prot {
    
    // Register protocols
    static let HANDSHAKE = Prot(name: "HANDSHAKE") { to_server, to_client in
        to_server.registerPacket(packetClass: Handshake.self, mappings: [
            ProtocolMapping(protocolVersion: ProtocolConstants.minecraft_1_8, packetID: 0x00)
        ])
    }
    static let STATUS = Prot(name: "STATUS") { to_server, to_client in
        
        to_client.registerPacket(packetClass: PingPacket.self, mappings: [
            ProtocolMapping(protocolVersion: ProtocolConstants.minecraft_1_8, packetID: 0x01)
        ])
        
        to_server.registerPacket(packetClass: PingPacket.self, mappings: [
            ProtocolMapping(protocolVersion: ProtocolConstants.minecraft_1_8, packetID: 0x01)
        ])
    }
    
    // Variables
    static let max_packet_id: Int32 = 0xFF
    var name: String
    var to_server: DirectionData!
    var to_client: DirectionData!
    
    // Initializer
    init(name: String, completionHandler: @escaping (DirectionData, DirectionData) -> ()) {
        self.name = name
        self.to_server = DirectionData(prot: self, direction: .to_server)
        self.to_client = DirectionData(prot: self, direction: .to_client)
        completionHandler(to_server, to_client)
    }
    
}
