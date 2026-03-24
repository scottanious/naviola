//
//  NaviolaSettings.swift
//  Radiola
//
//  Naviola — Settings for Navidrome server configuration.
//  Separate from upstream Settings.swift to avoid merge conflicts.
//

import Foundation

class NaviolaSettings {
    static let shared = NaviolaSettings()
    private let data = UserDefaults.standard

    private let serverURLKey = "NavidromeServerURL"
    private let usernameKey = "NavidromeUsername"

    var serverURL: String? {
        get { data.string(forKey: serverURLKey) }
        set { data.set(newValue, forKey: serverURLKey) }
    }

    var username: String? {
        get { data.string(forKey: usernameKey) }
        set { data.set(newValue, forKey: usernameKey) }
    }

    /// Password is stored in Keychain via NavidromeAuth, not UserDefaults.
    var password: String? {
        get {
            guard let username = username, !username.isEmpty else { return nil }
            return NavidromeAuth.shared.loadPassword(forUsername: username)
        }
        set {
            guard let username = username, !username.isEmpty else { return }
            if let newValue = newValue, !newValue.isEmpty {
                NavidromeAuth.shared.savePassword(newValue, forUsername: username)
            } else {
                NavidromeAuth.shared.deletePassword(forUsername: username)
            }
        }
    }

    var isConfigured: Bool {
        guard let url = serverURL, !url.isEmpty,
              let user = username, !user.isEmpty,
              let pass = password, !pass.isEmpty else {
            return false
        }
        return true
    }

    /// Build a NavidromeClient from current settings, or nil if not configured.
    func makeClient() -> NavidromeClient? {
        guard let urlString = serverURL, !urlString.isEmpty,
              let user = username, !user.isEmpty,
              let pass = password, !pass.isEmpty,
              let url = URL(string: urlString) else {
            return nil
        }
        return NavidromeClient(baseURL: url, username: user, password: pass)
    }
}
