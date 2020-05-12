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

struct Handshake: Packet {
    
    var protocolVersion: Int32?
    var host: String?
    var port: Int16?
    var requestedProtocol: Int32?
    
    mutating func readPacket(from buffer: inout ByteBuffer) {
        protocolVersion = buffer.readInteger(as: Int32.self)
        host = buffer.readString(length: Int(buffer.readInteger(as: Int32.self) ?? 0))
        port = buffer.readInteger(as: Int16.self)
        requestedProtocol = buffer.readInteger(as: Int32.self)
    }
    
    func writePacket(to buffer: inout ByteBuffer) {
        buffer.writeInteger(protocolVersion ?? 0)
        buffer.writeInteger(Int32((host ?? "").count))
        buffer.writeString(host ?? "")
        buffer.writeInteger(requestedProtocol ?? 0)
    }
    
    func toString() -> String {
        return "Handshake(protocolVersion: \(protocolVersion ?? 0), host: \(host ?? ""), port: \(port ?? 0), requestedProtocol: \(requestedProtocol ?? 0))"
    }
    
}
