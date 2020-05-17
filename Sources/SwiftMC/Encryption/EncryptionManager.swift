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
import CommonCrypto

class EncryptionManager {
    
    // ASN.1 identifiers
    static let bitStringIdentifier: UInt8 = 0x03
    static let sequenceIdentifier: UInt8 = 0x30
    
    // ASN.1 AlgorithmIdentfier for RSA encryption: OID 1 2 840 113549 1 1 1 and NULL
    static let algorithmIdentifierForRSAEncryption: [UInt8] = [0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00]
    
    // Store keys
    static var keys: (publicKey: SecKey, privateKey: SecKey)? = {
        let parameters: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 1024
        ]

        var publicKey, privateKey: SecKey?

        SecKeyGeneratePair(parameters as CFDictionary, &publicKey, &privateKey)
        
        if let publicKey = publicKey, let privateKey = privateKey {
            return (publicKey, privateKey)
        }
        return nil
    }()
    
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
        if let rawKey = keys?.publicKey, let attributes = getAttributes(of: rawKey) {
            // Add key info
            publicKey.append(contentsOf: [UInt8](attributes))
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
    static func getAttributes(of key: SecKey) -> Data? {
        if let pubAttributes = SecKeyCopyAttributes(key) as? [String: Any] {
            return pubAttributes[kSecValueData as String] as? Data
        }
        return nil
    }
    
    @available(iOS 10.0, tvOS 10.0, macOS 10.12, watchOS 3.0, *)
    static func getSecret(response: EncryptionResponse, request: EncryptionRequest) -> [UInt8]? {
        if let privateKey = keys?.privateKey, let decrypted = decrypt(privateKey: privateKey, content: Data(response.verifyToken) as CFData, usingAlgorithm: .rsaEncryptionPKCS1) as Data?, [UInt8](decrypted) == request.verifyToken, let secret = decrypt(privateKey: privateKey, content: Data(response.sharedSecret) as CFData, usingAlgorithm: .rsaEncryptionPKCS1) as Data? {
            return [UInt8](secret)
        }
        return nil
    }
    
    // Get bytes for a key
    static func getData(for key: SecKey) -> Data? {
        let query = [
            kSecValueRef as String: key,
            kSecReturnData as String: true
        ] as [String : Any]
        var out: AnyObject?
        guard errSecSuccess == SecItemCopyMatching(query as CFDictionary, &out) else {
            return nil
        }
        return out as? Data
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
    
    static func randomGenerateBytes(count: Int) -> Data? {
        let bytes = UnsafeMutableRawPointer.allocate(byteCount: count, alignment: 1)
        defer { bytes.deallocate() }
        let status = CCRandomGenerateBytes(bytes, count)
        guard status == kCCSuccess else { return nil }
        return Data(bytes: bytes, count: count)
    }
    
    // AES encryption
    static func AESEncrypt(data: Data, keyData: Data) -> Data? {
        let keyLength = keyData.count
        let validKeyLengths = [kCCKeySizeAES128, kCCKeySizeAES192, kCCKeySizeAES256]
        if (validKeyLengths.contains(keyLength) == false) {
            return nil
        }

        let ivSize = kCCBlockSizeAES128;
        let cryptLength = size_t(ivSize + data.count + kCCBlockSizeAES128)
        var cryptData = Data(count:cryptLength)

        let status = cryptData.withUnsafeMutableBytes { ivBytes in
            SecRandomCopyBytes(kSecRandomDefault, kCCBlockSizeAES128, ivBytes)
        }
        if (status != 0) {
            return nil
        }

        var numBytesEncrypted: size_t = 0
        let options = CCOptions(kCCModeCFB8)

        let cryptStatus = cryptData.withUnsafeMutableBytes { cryptBytes in
            data.withUnsafeBytes { dataBytes in
                keyData.withUnsafeBytes { keyBytes in
                    CCCrypt(CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            options,
                            keyBytes, keyLength,
                            cryptBytes,
                            dataBytes, data.count,
                            cryptBytes+kCCBlockSizeAES128, cryptLength,
                            &numBytesEncrypted)
                }
            }
        }

        if UInt32(cryptStatus) == UInt32(kCCSuccess) {
            cryptData.count = numBytesEncrypted + ivSize
        } else {
            return nil
        }

        return cryptData
    }
    
    // AES decrypt
    static func AESDecrypt(data:Data, keyData:Data) -> Data? {
        let keyLength = keyData.count
        let validKeyLengths = [kCCKeySizeAES128, kCCKeySizeAES192, kCCKeySizeAES256]
        if (validKeyLengths.contains(keyLength) == false) {
            return nil
        }

        let ivSize = kCCBlockSizeAES128;
        let clearLength = size_t(data.count - ivSize)
        var clearData = Data(count:clearLength)

        var numBytesDecrypted: size_t = 0
        let options = CCOptions(kCCModeCFB8)

        let cryptStatus = clearData.withUnsafeMutableBytes { cryptBytes in
            data.withUnsafeBytes { dataBytes in
                keyData.withUnsafeBytes { keyBytes in
                    CCCrypt(CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES128),
                            options,
                            keyBytes, keyLength,
                            dataBytes,
                            dataBytes+kCCBlockSizeAES128, clearLength,
                            cryptBytes, clearLength,
                            &numBytesDecrypted)
                }
            }
        }

        if UInt32(cryptStatus) == UInt32(kCCSuccess) {
            clearData.count = numBytesDecrypted
        } else {
            return nil
        }
        
        return clearData
    }
    
}
