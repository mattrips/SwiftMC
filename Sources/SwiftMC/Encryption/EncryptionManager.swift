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
import Security
import SwCrypt
import CommonCrypto

class EncryptionManager {
    
    // Store keys
    static var keys: (publicKey: SecKey, privateKey: SecKey)? = {
        // Generation of RSA private and public keys
        let parameters: [String:Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits as String: 1024]
        var publicKey, privateKey: SecKey?
        SecKeyGeneratePair(parameters as CFDictionary, &publicKey, &privateKey)
        
        // Get keys
        if let publicKey = publicKey, let privateKey = privateKey {
            return (publicKey, privateKey)
        }
        return nil
    }()
    
    // Get attributes for a key
    static func getEncoded(key: SecKey) -> Data? {
        if #available(iOS 10.0, tvOS 10.0, macOS 10.12, watchOS 3.0, *), let pubAttributes = SecKeyCopyAttributes(key) as? [String: Any] {
            return pubAttributes[kSecValueData as String] as? Data
        }
        return nil
    }
    
    // Check if encryption is supported
    static func supportsEncryption() -> Bool {
        return keys != nil
    }
    
    // Generate an encryption request
    @available(iOS 10.0, tvOS 10.0, macOS 10.12, watchOS 3.0, *)
    static func generateRequest() -> EncryptionRequest {
        // Server hash
        let hash = String(Int64.random(in: 1000000000000000 ..< 9999999999999999))
        
        // Public key
        var publicKey = [UInt8]()
        if let key = keys?.publicKey, let encoded = getEncoded(key: key) {
            // Add key info
            publicKey.append(contentsOf: [UInt8](encoded))
        }
        
        // Verify token
        var verify = [UInt8]()
        for _ in 0 ..< 4 {
            verify.append(UInt8.random(in: 0 ..< 255))
        }
        
        // Wrap everything
        return EncryptionRequest(serverId: hash, publicKey: publicKey, verifyToken: verify)
    }
    
    @available(iOS 10.0, tvOS 10.0, macOS 10.12, watchOS 3.0, *)
    static func getSecret(response: EncryptionResponse, request: EncryptionRequest) -> [UInt8]? {
        if let privateKey = keys?.privateKey, let decrypted = decrypt(privateKey: privateKey, content: Data(response.verifyToken) as CFData, usingAlgorithm: .rsaEncryptionPKCS1) as Data?, [UInt8](decrypted) == request.verifyToken, let secret = decrypt(privateKey: privateKey, content: Data(response.sharedSecret) as CFData, usingAlgorithm: .rsaEncryptionPKCS1) as Data? {
            return [UInt8](secret)
        }
        return nil
    }
    
    @available(iOS 10.0, tvOS 10.0, macOS 10.12, watchOS 3.0, *)
    static func getSecKey(for data: Data) -> SecKey? {
        return SecKeyCreateFromData([kSecAttrKeyType as String: kSecAttrKeyTypeAES] as CFDictionary, data as CFData, nil)
    }
    
    @available(iOS 10.0, tvOS 10.0, macOS 10.12, watchOS 3.0, *)
    static func encrypt(content: CFData, publicKey: SecKey, usingAlgorithm: SecKeyAlgorithm) -> CFData? {
        var status = Unmanaged<CFError>?.init(nilLiteral: ())
            
        let data = SecKeyCreateEncryptedData(publicKey, usingAlgorithm, content, &status)
            
        if let stat = status?.takeRetainedValue(), stat.localizedDescription.isEmpty {
            return nil
        }
            
        return data
    }
    
    @available(iOS 10.0, tvOS 10.0, macOS 10.12, watchOS 3.0, *)
    static func decrypt(privateKey: SecKey, content: CFData, usingAlgorithm: SecKeyAlgorithm) -> CFData? {
        // Decrypt the entrypted string with the private key
        var status = Unmanaged<CFError>?.init(nilLiteral: ())
        
        let decrypted = SecKeyCreateDecryptedData(privateKey, usingAlgorithm, content, &status)
            
        if let stat = status?.takeRetainedValue(), stat.localizedDescription.isEmpty {
            return nil
        }
                    
        return decrypted
    }
    
}
