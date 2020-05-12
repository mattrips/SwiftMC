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

class Handshake: Packet {
    
    var protocolVersion: Int32
    var host: String
    var port: Int16
    var requestedProtocol: Int32
    
    required init() {
        protocolVersion = -1
        host = ""
        port = -1
        requestedProtocol = -1
    }
    
    func readPacket(from buffer: inout ByteBuffer, direction: DirectionData, protocolVersion: Int32) {
        self.protocolVersion = buffer.readVarInt() ?? self.protocolVersion
        self.host = buffer.readVarString() ?? self.host
        self.port = buffer.readInteger(as: Int16.self) ?? self.port
        self.requestedProtocol = buffer.readVarInt() ?? self.requestedProtocol
    }
    
    func writePacket(to buffer: inout ByteBuffer) {
        buffer.writeVarInt(value: protocolVersion)
        buffer.writeVarString(string: host)
        buffer.writeInteger(port)
        buffer.writeVarInt(value: requestedProtocol)
    }
    
    func toString() -> String {
        return "Handshake(protocolVersion: \(protocolVersion), host: \(host), port: \(port), requestedProtocol: \(requestedProtocol))"
    }
    
}
