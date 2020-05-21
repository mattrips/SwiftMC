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

public class NBTCompound: NBTTag {
    
    public var name: String?
    public var values: [NBTTag]
    
    public required init() {
        values = []
    }
    
    public init(values: [NBTTag]) {
        self.values = values
    }
    
    public func readTag(from buffer: inout ByteBuffer) {
        repeat {
            values.append(NBTRegistry.readTag(in: &buffer))
        } while !(values.last is NBTEnd)
        values.removeLast()
    }
    
    public func writeTag(to buffer: inout ByteBuffer) {
        for value in values {
            NBTRegistry.writeTag(tag: value, to: &buffer)
        }
        NBTRegistry.writeTag(tag: NBTEnd(), to: &buffer)
    }
    
    public func toString() -> String {
        return "NBTCompound(name: \(name ?? "NONE"), values:\n\(values.map({ $0.toString() }).joined(separator: "\n").indent())\n)"
    }
    
    public subscript(name: String) -> NBTTag? {
        return values.filter({ $0.name == name }).first
    }
    
}