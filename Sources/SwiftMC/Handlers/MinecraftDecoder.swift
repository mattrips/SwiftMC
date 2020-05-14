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

class MinecraftDecoder: ByteToMessageDecoder {
    
    // Output alias
    typealias InboundOut = Packet
    
    // Configuration for decoding
    var channel: ChannelWrapper?
    var server: Bool
    
    // Initializer
    init(server: Bool) {
        self.server = server
    }
    
    // Decode wrapper
    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        if channel?.prot.name == "HANDSHAKE" {
            // Legacy decoder
            try legacyDecoder(context: context, buffer: &buffer)
        }
        
        // Frame decoder
        let readerIndex = buffer.readerIndex
        guard buffer.readableBytes > 0, let size = buffer.readVarInt(), buffer.readableBytes >= size else {
            buffer.moveReaderIndex(to: readerIndex)
            return .needMoreData
        }
        
        // Create a buffer with specified size
        var limitedBuffer = ByteBufferAllocator().buffer(capacity: 64*1024*1024)
        limitedBuffer.writeBytes(buffer.readBytes(length: Int(size)) ?? [])
        
        // Decompress if needed
        if let threshold = channel?.threshold, threshold != -1 {
            // Move buffer
            var newBuffer = ByteBufferAllocator().buffer(capacity: 64*1024*1024)
            
            // Handle
            try thresholdDecoder(oldBuffer: &limitedBuffer, newBuffer: &newBuffer)
            
            // And decode packet
            try packetDecoder(context: context, buffer: &newBuffer)
        } else {
            // Classic packet decoder
            try packetDecoder(context: context, buffer: &limitedBuffer)
        }
        
        // Move index
        return .continue
    }
    
    // Legacy decoder
    func legacyDecoder(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws {
        // Save reader index
        let readerIndex = buffer.readerIndex
        
        // Read packet id
        if let packetID = buffer.readBytes(length: 1)?.first {
            // Check packet type
            if packetID == 0xFE {
                // Legacy ping
                context.fireChannelRead(wrapInboundOut(LegacyPing(v1_5: buffer.readableBytes > 0 && buffer.readInteger(as: UInt8.self) ?? 0 == 0x01)))
            } else if packetID == 0x02 && buffer.readableBytes > 0 {
                // Legacy handshake
                buffer.moveReaderIndex(forwardBy: buffer.readableBytes)
                context.fireChannelRead(wrapInboundOut(LegacyHandshake()))
            }
        }
        
        // Else, reset
        buffer.moveReaderIndex(to: readerIndex)
    }
    
    // Threshold
    func thresholdDecoder(oldBuffer: inout ByteBuffer, newBuffer: inout ByteBuffer) throws {
        // Read size
        let size = oldBuffer.readVarInt()
        if size == 0 {
            var slice = oldBuffer.slice()
            newBuffer.writeBuffer(&slice)
            oldBuffer.moveReaderIndex(forwardBy: oldBuffer.readableBytes)
        } else {
            try oldBuffer.decompress(to: &newBuffer, with: .deflate)
        }
    }
    
    // Packet decoder
    func packetDecoder(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws {
        // Get direction
        if let channel = channel, let direction = server ? channel.prot.to_server : channel.prot.to_client {
            // Read the packet id
            if let packetID = buffer.readVarInt() {
                // Create the packet corresponding to this id
                let packet = direction.createPacket(id: packetID, version: channel.protocolVersion)
                
                // If packet if unknown
                if let unknown = packet as? UnknownPacket {
                    // Set packet id
                    unknown.packetId = packetID
                }
                
                // Read packet
                packet.readPacket(from: &buffer, direction: direction, protocolVersion: channel.protocolVersion)
                context.fireChannelRead(wrapInboundOut(packet))
            }
        }
    }
    
}
