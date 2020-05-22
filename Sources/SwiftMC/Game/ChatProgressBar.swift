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

public class ChatProgressBar: ChatMessage {
    
    private let total: Int
    private let width: Int
    private var count: Int
    private var first: Bool
    
    public init(total: Int, width: Int) {
        self.total = total
        self.width = width
        self.count = 0
        self.first = true
        super.init(text: "")
    }
    
    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
    
    @discardableResult
    public func increment() -> ChatProgressBar {
        if count < total {
            count += 1
        }
        return self
    }
    
    public override func toString(useAnsi: Bool = false) -> String {
        // Init string
        var string = ""
        
        // Replace last line
        if !first {
            string += "\u{001B}[2K\u{001B}[A"
        }
        self.first = false
        
        // Create bar
        let n = (count * width) / total
        let bar = "[\(String(repeating: "#", count: n))\(String(repeating: " ", count: width - n))]"
        let p = " \((count * 100) / total)% "
        let s = (bar.count / 2) - p.count + 1
        string += bar.replacingCharacters(in: bar.index(bar.startIndex, offsetBy: s) ..< bar.index(bar.startIndex, offsetBy: s + p.count), with: p)
        
        // Add rest of the string
        string += super.toString(useAnsi: useAnsi)
        
        // Return the result
        return string
    }
    
    public func getFirstAndSet() -> Bool {
        let old = first
        self.first = false
        return old
    }
    
}
