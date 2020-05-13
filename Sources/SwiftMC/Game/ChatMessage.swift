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

public class ChatMessage: Codable {
    
    // MARK: - JSON Encoding/Decoding
    
    static func decode(from json: String) -> ChatMessage? {
        if let data = json.data(using: .utf8), let object = try? JSONDecoder().decode(ChatMessage.self, from: data) {
            return object
        }
        return nil
    }
    
    func toJSON() -> String? {
        if let json = try? JSONEncoder().encode(self), let string = String(bytes: json, encoding: .utf8) {
            return string
        }
        return nil
    }
    
    func toString() -> String {
        if let extra = extra {
            return extra.map { $0.toString() }.joined()
        }
        return text
    }
    
    // MARK: - Chat message content
    
    public var extra: [ChatMessage]?
    public var text: String
    public var color: String?
    
    public init(text: String) {
        self.text = text
    }
    
    public init(extra: [ChatMessage]) {
        self.extra = extra
        self.text = ""
    }
    
    public func with(color: ChatColor) -> ChatMessage {
        self.color = color.id
        return self
    }
    
}
