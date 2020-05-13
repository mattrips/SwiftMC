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

class MinecraftDecoder: ByteToMessageDecoder {
    
    // Output alias
    typealias InboundOut = PackerWrapper
    
    // Configuration for decoding
    var prot: Prot
    var server: Bool
    var protocolVersion: Int32
    
    // Initializer
    init(prot: Prot, server: Bool, protocolVersion: Int32) {
        self.prot = prot
        self.server = server
        self.protocolVersion = protocolVersion
    }
    
    // Decode wrapper
    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        // Legacy decoder
        try legacyDecoder(context: context, buffer: &buffer)
        
        // Frame decoder
        if let result = try frameDecoder(context: context, buffer: &buffer) {
            return result
        }
        
        // Packet decoder
        if let result = try packetDecoder(context: context, buffer: &buffer) {
            return result
        }
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
                context.fireChannelRead(wrapInboundOut(PackerWrapper(packetId: Int32(packetID), packet: LegacyPing(v1_5: buffer.readableBytes > 0 && buffer.readInteger(as: UInt8.self) ?? 0 == 0x01))))
            } else if packetID == 0x02 && buffer.readableBytes > 0 {
                // Legacy handshake
                buffer.moveReaderIndex(forwardBy: buffer.readableBytes)
                context.fireChannelRead(wrapInboundOut(PackerWrapper(packetId: Int32(packetID), packet: LegacyHandshake(), buffer: nil)))
            }
        }
        
        // Else, reset
        buffer.moveReaderIndex(to: readerIndex)
    }
    
    // Frame decoder
    func frameDecoder(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState? {
        // Save reader index
        let readerIndex = buffer.readerIndex
        var buf: [UInt8] = [0, 0, 0]
        for i in 0 ..< buf.count {
            // Check readability
            if buffer.readableBytes == 0 {
                buffer.moveReaderIndex(to: readerIndex)
                return .needMoreData
            }
            
            // Read byte
            buf[i] = buffer.readBytes(length: 1)?.first ?? 0
            if buf[i] >= 0 {
                var temp = ByteBuffer(ByteBufferView(buf))
                let length = temp.readInteger(as: Int32.self) ?? 0
                if length == 0 {
                    return nil
                }
                if buffer.readableBytes < Int(length) {
                    buffer.moveReaderIndex(to: readerIndex)
                } else {
                    buffer.moveReaderIndex(forwardBy: Int(length))
                }
            }
        }
        return nil
    }
    
    // Packet decoder
    func packetDecoder(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState? {
        // Get direction
        if let direction = server ? prot.to_server : prot.to_client {
            // Read the packet id
            if let packetID = buffer.readVarInt() {
                // Create the packet corresponding to this id
                if let packet = direction.createPacket(id: packetID, version: protocolVersion) {
                    // Read packet
                    packet.readPacket(from: &buffer, direction: direction, protocolVersion: protocolVersion)
                    context.fireChannelRead(wrapInboundOut(PackerWrapper(packetId: packetID, packet: packet, buffer: buffer)))
                } else {
                    // Skip
                    buffer.moveReaderIndex(forwardBy: buffer.readableBytes)
                    context.fireChannelRead(wrapInboundOut(PackerWrapper(packetId: packetID, packet: nil, buffer: buffer)))
                }
            }
        }
        return .continue
    }
    
}
