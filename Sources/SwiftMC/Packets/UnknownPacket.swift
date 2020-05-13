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

class UnknownPacket: Packet {
    
    var packetId: Int32
    var bytes: [UInt8]
    
    required init() {
        packetId = 0
        bytes = []
    }
    
    func readPacket(from buffer: inout ByteBuffer, direction: DirectionData, protocolVersion: Int32) {
        self.bytes = buffer.readBytes(length: buffer.readableBytes) ?? bytes
    }
    
    func writePacket(to buffer: inout ByteBuffer, direction: DirectionData, protocolVersion: Int32) {
        buffer.writeBytes(bytes)
    }
    
    func toString() -> String {
        return "UnknownPacket(packetId: \(packetId), size: \(bytes.count) bytes)"
    }
    
}
