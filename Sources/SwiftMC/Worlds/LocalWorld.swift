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

class LocalWorld: WorldProtocol {
    
    func connect(client: ChannelWrapper) {
        // Send login packet (game starts)
        client.send(packet: Login(entityId: 1, gameMode: 1, dimension: 0, seed: 0, difficulty: 0, maxPlayers: 1, levelType: "default", viewDistance: 16, reducedDebugInfo: false, normalRespawn: true))
        //client.send(packet: Position(x: 15, y: 100, z: 15, teleportId: 1))
    }
    
    func disconnect(client: ChannelWrapper) {
        
    }
    
    func handle(packet: Packet, for client: ChannelWrapper) {
        
    }
    
}
