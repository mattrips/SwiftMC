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

class InitialHandler: PacketHandler {
    
    var channel: ChannelWrapper?
    
    func connected(channel: ChannelWrapper) {
        self.channel = channel
    }
    
    func disconnected(channel: ChannelWrapper) {
        self.channel = nil
    }
    
    func shouldHandle(wrapper: PackerWrapper) -> Bool {
        return !(channel?.closing ?? true)
    }
    
    func handle(wrapper: PackerWrapper) {
        // Check packet type
        if let handshake = wrapper.packet as? Handshake {
            self.handle(handshake: handshake)
        }
        if let statusRequest = wrapper.packet as? StatusRequest {
            self.handle(statusRequest: statusRequest)
        }
    }
    
    func handle(handshake: Handshake) {
        // Save
        channel?.setVersion(version: handshake.protocolVersion)
        
        // Remove FML from host
        if handshake.host.contains("\0") {
            let split = handshake.host.split(separator: "\0", maxSplits: 2, omittingEmptySubsequences: true)
            handshake.host = String(split[0])
        }
        
        // Remove . at the end (dns record)
        if handshake.host.count > 0 && handshake.host.last == "." {
            let _ = handshake.host.removeLast()
        }
        
        // Check request protocol
        switch handshake.requestedProtocol {
            
        case 1:
            // Ping
            channel?.setProtocol(prot: .STATUS)
        default:
            return
            
        }
    }
    
    func handle(statusRequest: StatusRequest) {
        // Create response
        let response: [String: Any] = [
            "version": [
                "name": "1.12.2",
                "protocol": 340
            ],
            "players": [
                "max": 42,
                "online": 0,
                "sample": []
            ],
            "description": [
                "text": "SwiftMC Server"
            ]
        ]
        
        // Send packet
        if let json = try? JSONSerialization.data(withJSONObject: response, options: []), let string = String(bytes: json, encoding: .utf8) {
            channel?.send(packet: StatusResponse(response: string))
        }
    }
    
}
