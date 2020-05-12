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

public final class ClientHandler: ChannelInboundHandler {
    
    // Requirements
    public typealias InboundIn = PackerWrapper
    public typealias OutboundOut = PackerWrapper
    
    // Variables
    let protocolVersion: Int32
    var handler: PacketHandler
    
    // Initializer
    init(protocolVersion: Int32) {
        self.protocolVersion = protocolVersion
        self.handler = InitialHandler()
    }
    
    // This method handles new connections
    public func channelActive(context: ChannelHandlerContext) {
        // Logging
        print("[+] Client connecting: \(context.channel.remoteAddress?.description ?? "-")")
        handler.connected(channel: context.channel)
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        // Read wrapper
        let wrapper = unwrapInboundIn(data)
        print(wrapper.packet?.toString() ?? "Unknown packet")
        
        // Handle packet
        handler.handle(wrapper: wrapper)
    }
    
    // This method is called if the socket is closed in a clean way.
    public func channelInactive(context: ChannelHandlerContext) {
        print("[+] Channel closed.")
    }
    
    // Called if an error happens. Log and close the socket.
    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("[!] ERROR: \(error)")
        context.close(promise: nil)
    }
    
}
