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
                        player.goTo(world: server.worlds[index])
                    } else {
                        // Error message
                        sender.sendMessage(message: ChatColor.red + "Index is too big!")
                    }
                } else {
                    // Error message
                    sender.sendMessage(message: ChatColor.red + "\"\(args[0])\" is not a number!")
                }
            } else {
                // Error message
                sender.sendMessage(message: ChatColor.red + "Usage: /world <id>")
            }
        } else {
            // Error message
            sender.sendMessage(message: ChatColor.red + "Only players can use this command!")
        }
    }
    
    public func description() -> String {
        return "Switch world"
    }
    
}
