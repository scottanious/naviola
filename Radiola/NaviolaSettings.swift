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

    // TODO: Switch to Keychain (NavidromeAuth) for signed release builds.
    // Using UserDefaults for dev to avoid Keychain "Always Allow" prompts
    // that unsigned apps can't persist.
    private let passwordKey = "NavidromePassword"

    var password: String? {
        get { data.string(forKey: passwordKey) }
        set { data.set(newValue, forKey: passwordKey) }
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
