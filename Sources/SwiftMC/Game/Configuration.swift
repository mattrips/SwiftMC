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

open class Configuration {
    
    public var serverRoot: String
    public var protocolVersion: Int32
    public var port: Int
    public var mode: AuthentificationMode = .online
    public var motd: String?
    public var favicon: String?
    public var slots: Int = 42
    public var debug: Bool = false
    public var logger: (ChatMessage) -> ()
    
    public init(protocolVersion: Int32, port: Int) {
        self.serverRoot = FileManager.default.currentDirectoryPath
        self.protocolVersion = protocolVersion
        self.port = port
        self.logger = { log in
            print(log.toString(useAnsi: true))
        }
    }
    
    public func with(serverRoot: String) -> Configuration {
        self.serverRoot = serverRoot
        return self
    }
    
    public func with(mode: AuthentificationMode) -> Configuration {
        self.mode = mode
        return self
    }
    
    public func with(motd: String) -> Configuration {
        self.motd = motd
        return self
    }
    
    public func with(favicon: String) -> Configuration {
        self.favicon = favicon
        return self
    }
    
    public func with(slots: Int) -> Configuration {
        self.slots = slots
        return self
    }
    
    public func with(logger: @escaping (ChatMessage) -> ()) -> Configuration {
        self.logger = logger
        return self
    }
    
    public func enable(debug: Bool) -> Configuration {
        self.debug = debug
        return self
    }
    
}
