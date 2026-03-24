//
//  NavidromeAuth.swift
//  Radiola
//
//  Naviola — Keychain credential storage and Subsonic auth parameter generation.
//

import CryptoKit
import Foundation
import Security

// MARK: - NavidromeAuth

class NavidromeAuth {
    static let shared = NavidromeAuth()
    private let keychainService = "com.naviola.navidrome"

    // MARK: - Keychain Operations

    func savePassword(_ password: String, forUsername username: String) -> Bool {
        deletePassword(forUsername: username)

        guard let data = password.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: username,
            kSecValueData as String: data,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func loadPassword(forUsername username: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: username,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func deletePassword(forUsername username: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: username,
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Subsonic Auth Parameters

    /// Generate the Subsonic authentication query items for a single request.
    /// Uses salted MD5 token auth: `t = md5(password + salt)`, `s = salt`.
    func authQueryItems(username: String, password: String, salt: String? = nil) -> [URLQueryItem] {
        let salt = salt ?? randomSalt()
        let token = md5Hash(password + salt)

        return [
            URLQueryItem(name: "u", value: username),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: salt),
            URLQueryItem(name: "v", value: "1.16.1"),
            URLQueryItem(name: "c", value: "Naviola"),
            URLQueryItem(name: "f", value: "json"),
        ]
    }

    // MARK: - Helpers

    func randomSalt(length: Int = 16) -> String {
        let bytes = (0 ..< length).map { _ in UInt8.random(in: 0 ... 255) }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    func md5Hash(_ string: String) -> String {
        let data = Data(string.utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
