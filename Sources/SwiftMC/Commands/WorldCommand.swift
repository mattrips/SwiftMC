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

public class WorldCommand: Command {
    
    public func execute(server: SwiftMC, sender: CommandSender, args: [String]) {
        if let player = sender as? Player {
            if args.count == 1 {
                // Get world index
                if let index = Int(args[0]) {
                    // Get world
                    if index < server.worlds.count {
                        // Connect to the world
                        player.setWorld(world: server.worlds[index])
                    } else {
                        // Error message
                        sender.sendMessage(message: ChatMessage(text: "Index is too big!").with(color: .red))
                    }
                } else {
                    // Error message
                    sender.sendMessage(message: ChatMessage(text: "\"\(args[0])\" is not a number!").with(color: .red))
                }
            } else {
                // Error message
                sender.sendMessage(message: ChatMessage(text: "Usage: $world <id>").with(color: .red))
            }
        } else {
            // Error message
            sender.sendMessage(message: ChatMessage(text: "Only players can use this command!"))
        }
    }
    
    public func description() -> String {
        return "Switch world"
    }
    
}
