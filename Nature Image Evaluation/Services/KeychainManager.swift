//
//  KeychainManager.swift
//  Nature Image Evaluation
//
//  Created by Claude Code on 10/27/25.
//

import Foundation
import Security

/// Manages secure storage of API keys in macOS Keychain
final class KeychainManager {

    static let shared = KeychainManager()

    private init() {}

    // MARK: - API Key Management

    /// Save an API key to the keychain
    /// - Parameters:
    ///   - key: The API key to save
    ///   - provider: The API provider (Anthropic or OpenAI)
    func saveAPIKey(_ key: String, for provider: Constants.APIProvider) throws {
        let account = accountName(for: provider)
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.invalidKeyData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.keychainServiceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status)
        }
    }

    /// Retrieve an API key from the keychain
    /// - Parameter provider: The API provider
    /// - Returns: The API key if found
    func getAPIKey(for provider: Constants.APIProvider) throws -> String? {
        let account = accountName(for: provider)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.keychainServiceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        switch status {
        case errSecSuccess:
            if let data = dataTypeRef as? Data,
               let key = String(data: data, encoding: .utf8) {
                return key
            }
            return nil
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandledError(status)
        }
    }

    /// Delete an API key from the keychain
    /// - Parameter provider: The API provider
    func deleteAPIKey(for provider: Constants.APIProvider) throws {
        let account = accountName(for: provider)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.keychainServiceName,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status)
        }
    }

    /// Check if an API key exists
    /// - Parameter provider: The API provider
    /// - Returns: true if key exists
    func hasAPIKey(for provider: Constants.APIProvider) -> Bool {
        do {
            return try getAPIKey(for: provider) != nil
        } catch {
            return false
        }
    }

    // MARK: - Helper Methods

    private func accountName(for provider: Constants.APIProvider) -> String {
        switch provider {
        case .anthropic:
            return Constants.keychainAnthropicAPIKeyAccount
        case .openai:
            return Constants.keychainOpenAIAPIKeyAccount
        }
    }
}

// MARK: - Keychain Error

enum KeychainError: LocalizedError {
    case unhandledError(OSStatus)
    case invalidKeyData

    var errorDescription: String? {
        switch self {
        case .unhandledError(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return "Keychain error: \(message)"
            }
            return "Unknown keychain error (code: \(status))"
        case .invalidKeyData:
            return "Invalid API key data - could not convert to UTF-8"
        }
    }
}