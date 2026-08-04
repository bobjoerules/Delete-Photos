import Foundation
import Security

enum KeychainError: Error {
    case invalidPasscodeFormat
    case unexpectedStatus(OSStatus)
    case passcodeNotSet
}

final class PasscodeManager {
    static let shared = PasscodeManager()
    
    private let service = "com.example.PasscodeService"
    private let account = "userPasscode"
    
    private init() {}
    
    // Check if passcode exists in Keychain
    func hasPasscode() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // Validate passcode format and store it securely
    func setPasscode(_ passcode: String) throws {
        // Validate passcode: 4-8 digits only
        let passcodeRegex = "^[0-9]{4,8}$"
        guard let _ = passcode.range(of: passcodeRegex, options: .regularExpression) else {
            throw KeychainError.invalidPasscodeFormat
        }
        
        let passcodeData = Data(passcode.utf8)
        
        if hasPasscode() {
            // Update existing item
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: passcodeData
            ]
            
            let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            guard status == errSecSuccess else {
                throw KeychainError.unexpectedStatus(status)
            }
        } else {
            // Add new item
            let newItem: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecValueData as String: passcodeData,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
            ]
            
            let status = SecItemAdd(newItem as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw KeychainError.unexpectedStatus(status)
            }
        }
    }
    
    // Validate input passcode against stored passcode
    func validatePasscode(_ passcode: String) -> Bool {
        guard hasPasscode() else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let storedPasscode = String(data: data, encoding: .utf8)
        else {
            return false
        }
        
        return storedPasscode == passcode
    }
    
    // Remove passcode from Keychain
    func clearPasscode() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
