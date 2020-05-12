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

class MinecraftEncoder: MessageToByteEncoder {
    
    // Input alias
    typealias OutboundIn = Packet
    
    // Configuration for encoding
    var prot: Prot
    var server: Bool
    var protocolVersion: Int32
    
    // Initializer
    init(prot: Prot, server: Bool, protocolVersion: Int32) {
        self.prot = prot
        self.server = server
        self.protocolVersion = protocolVersion
    }
    
    func encode(data: Packet, out: inout ByteBuffer) throws {
        // Packet encoder
        try packetEncoder(data: data, out: &out)
        
        // Frame encoder
        try frameEncoder(data: data, out: &out)
    }
    
    // Frame encoder
    func frameEncoder(data: Packet, out: inout ByteBuffer) throws {
        let bodyLen = Int32(out.readableBytes)
        
        out.writeVarInt(value: bodyLen)
        out.writeBytes(out.readBytes(length: out.readableBytes) ?? [])
    }
    
    // Packet encoder
    func packetEncoder(data: Packet, out: inout ByteBuffer) throws {
        // Get direction
        if let direction = server ? prot.to_client : prot.to_server, let id = direction.getId(for: type(of: data), version: protocolVersion) {
            // Write packet id
            out.writeVarInt(value: id)
            
            // And write packet content
            data.writePacket(to: &out)
            
            print("S -> C", data.toString())
        }
    }
    
}
