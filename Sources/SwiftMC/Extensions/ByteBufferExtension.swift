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

extension ByteBuffer {
    
    mutating func readVarString() -> String? {
        let len = readVarInt() ?? 0
        return readString(length: Int(len))
    }
    
    mutating func writeVarString(string: String) {
        writeVarInt(value: Int32(string.count))
        writeString(string)
    }
    
    mutating func readVarInt(maxBytes: Int = 5) -> Int32? {
        var out: Int32 = 0
        var bytes = 0
        while true {
            if let i = readBytes(length: 1)?.first {
                out |= (Int32(i) & 0x7F) << (bytes * 7)
                bytes += 1
                if bytes > maxBytes {
                    return nil
                }
                if (i & 0x80) != 0x80 {
                    break
                }
            } else {
                return nil
            }
        }
        return out
    }
    
    mutating func writeVarInt(value: Int32) {
        var part: Int32
        var value = value
        while true {
            part = value & 0x7F
            value = value >> 7
            if value != 0 {
                part |= 0x80
            }
            writeInteger(UInt8(part), as: UInt8.self)
            if value == 0 {
                break
            }
        }
    }
    
}
