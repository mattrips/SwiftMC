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

public class ChatColor {
    
    public static let black = ChatColor("0", id: "black")
    public static let dark_blue = ChatColor("1", id: "dark_blue")
    public static let dark_green = ChatColor("2", id: "dark_green")
    public static let dark_aqua = ChatColor("3", id: "dark_aqua")
    public static let dark_red = ChatColor("4", id: "dark_red")
    public static let dark_purple = ChatColor("5", id: "dark_purple")
    public static let gold = ChatColor("6", id: "gold")
    public static let gray = ChatColor("7", id: "gray")
    public static let dark_gray = ChatColor("8", id: "dark_gray")
    public static let blue = ChatColor("9", id: "blue")
    public static let green = ChatColor("a", id: "green")
    public static let aqua = ChatColor("b", id: "aqua")
    public static let red = ChatColor("c", id: "red")
    public static let light_purple = ChatColor("d", id: "light_purple")
    public static let yellow = ChatColor("e", id: "yellow")
    public static let white = ChatColor("f", id: "white")
    
    var char: Character
    var id: String
    
    init(_ char: Character, id: String) {
        self.char = char
        self.id = id
    }
    
}
