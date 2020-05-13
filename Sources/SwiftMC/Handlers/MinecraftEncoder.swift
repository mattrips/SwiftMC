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
import CompressNIO

class MinecraftEncoder: MessageToByteEncoder {
    
    // Input alias
    typealias OutboundIn = Packet
    
    // Configuration for encoding
    var channel: ChannelWrapper?
    var server: Bool
    
    // Initializer
    init(server: Bool) {
        self.server = server
    }
    
    func encode(data: Packet, out: inout ByteBuffer) throws {
        // Init a temporary buffer
        var buffer1 = ByteBuffer(ByteBufferView())
        var buffer2 = ByteBuffer(ByteBufferView())
        
        // Packet encoder
        try packetEncoder(data: data, out: &buffer1)
        
        // Check for compression
        if let threshold = channel?.threshold, threshold != -1 {
            try thresholdEncoder(threshold: threshold, from: &buffer1, out: &buffer2)
        } else {
            buffer2.writeBuffer(&buffer1)
        }
        
        // Frame encoder
        try frameEncoder(from: &buffer2, out: &out)
    }
    
    // Threshold
    func thresholdEncoder(threshold: Int32, from: inout ByteBuffer, out: inout ByteBuffer) throws {
        // Check for size
        let fromSize = Int32(from.readableBytes)
        if fromSize < threshold {
            out.writeVarInt(value: 0)
            out.writeBuffer(&from)
        } else {
            out.writeVarInt(value: fromSize)
            try from.compress(to: &out, with: .deflate)
        }
    }
    
    // Frame encoder
    func frameEncoder(from: inout ByteBuffer, out: inout ByteBuffer) throws {
        out.writeVarInt(value: Int32(from.readableBytes))
        out.writeBuffer(&from)
    }
    
    // Packet encoder
    func packetEncoder(data: Packet, out: inout ByteBuffer) throws {
        // Get direction
        if let channel = channel, let direction = server ? channel.prot.to_client : channel.prot.to_server, let id = direction.getId(for: type(of: data), version: channel.protocolVersion) {
            // Write packet id
            out.writeVarInt(value: id)
            
            // And write packet content
            data.writePacket(to: &out, direction: direction, protocolVersion: channel.protocolVersion)
        }
    }
    
}
