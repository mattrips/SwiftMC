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
import CommonCrypto

extension String {

    public func md5() -> String? {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: length)

        if let d = self.data(using: .utf8) {
            _ = d.withUnsafeBytes { body -> String in
                CC_MD5(body.baseAddress, CC_LONG(d.count), &digest)
                return ""
            }
        }

        return (0 ..< length).reduce("") {
            $0 + String(format: "%02x", digest[$1])
        }
    }

    public func hex2bin() -> [UInt8] {
        var hex = self
        var array = [UInt8]()
        while hex.count >= 2 {
            let chars = String([hex.removeFirst(), hex.removeFirst()])
            array.append(UInt8(chars, radix: 16) ?? 0)
        }
        return array
    }

    public func getUUID() -> String? {
        if let hash = "OfflinePlayer:\(self)".md5() {
            var bytes = hash.hex2bin()
            bytes[6] = bytes[6] & 0x0F | 0x30
            bytes[8] = bytes[8] & 0x3F | 0x80
            return Data(bytes).bin2hex().addSeparatorUUID()
        }
        return nil
    }
    
    public func addSeparatorUUID() -> String {
        var components = [String]()
        components.append(String(self[startIndex ..< index(startIndex, offsetBy: 8)]))
        components.append(String(self[index(startIndex, offsetBy: 8) ..< index(startIndex, offsetBy: 12)]))
        components.append(String(self[index(startIndex, offsetBy: 12) ..< index(startIndex, offsetBy: 16)]))
        components.append(String(self[index(startIndex, offsetBy: 16) ..< index(startIndex, offsetBy: 20)]))
        components.append(String(self[index(startIndex, offsetBy: 20) ..< endIndex]))
        return components.joined(separator: "-")
    }
    
    public func indent() -> String {
        split(separator: "\n").map({ "\t" + $0 }).joined(separator: "\n")
    }
    
    public static func + (lhs: String, rhs: ChatColor) -> String {
        return lhs + rhs.description
    }
    
    public static func + (lhs: ChatColor, rhs: String) -> String {
        return lhs.description + rhs
    }
    
    public static func += (lhs: inout String, rhs: ChatColor) {
        lhs += rhs.description
    }

}
