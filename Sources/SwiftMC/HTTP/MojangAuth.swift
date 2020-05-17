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
import AsyncHTTPClient

class MojangAuth {
    
    let username: String
    let serverId: String
    
    init(username: String, serverId: String) {
        self.username = username
        self.serverId = serverId
    }
    
    func fetch(completionHandler: @escaping ([String: Any]?) -> ()) {
        do {
            let client = HTTPClient(eventLoopGroupProvider: .createNew)
            defer {
                try? client.syncShutdown()
            }
            
            var urlComponents = URLComponents()
            urlComponents.scheme = "https"
            urlComponents.host = "sessionserver.mojang.com"
            urlComponents.path = "/session/minecraft/hasJoined"
            urlComponents.queryItems = [
                URLQueryItem(name: "username", value: username),
                URLQueryItem(name: "serverId", value: serverId)
            ]
            
            guard let url = urlComponents.url else {
                completionHandler(nil)
                return
            }
            
            let request = try HTTPClient.Request(url: url.absoluteString)
            client.execute(request: request).whenComplete { result in
                switch result {
                case.failure(_):
                    completionHandler(nil)
                case .success(let response):
                    if response.status == .ok, var body = response.body, let bytes = body.readBytes(length: body.readableBytes), let json = try? JSONSerialization.jsonObject(with: Data(bytes), options: []) as? [String: Any] {
                        completionHandler(json)
                    } else {
                        completionHandler(nil)
                    }
                }
            }
        } catch {
            completionHandler(nil)
        }
    }
    
}
