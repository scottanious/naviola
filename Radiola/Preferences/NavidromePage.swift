//
//  NavidromePage.swift
//  Naviola
//
//  Naviola — Preferences page for Navidrome server configuration.
//

import Cocoa

class NavidromePage: NSViewController {
    private let naviolaSettings = NaviolaSettings.shared

    private let serverLabel = Label(text: NSLocalizedString("Server URL:", tableName: "Settings", comment: "Navidrome settings label"))
    private let serverEdit = TextEdit()

    private let usernameLabel = Label(text: NSLocalizedString("Username:", tableName: "Settings", comment: "Navidrome settings label"))
    private let usernameEdit = TextEdit()

    private let passwordLabel = Label(text: NSLocalizedString("Password:", tableName: "Settings", comment: "Navidrome settings label"))
    private let passwordEdit = NSSecureTextField()

    private let testButton = NSButton(title: NSLocalizedString("Test Connection", tableName: "Settings", comment: "Navidrome settings button"), target: nil, action: nil)
    private let clearSessionButton = NSButton(title: NSLocalizedString("Clear Session", tableName: "Settings", comment: "Navidrome settings button"), target: nil, action: nil)
    private let statusLabel = Label()

    // MARK: - Init

    init() {
        super.init(nibName: nil, bundle: nil)
        title = NSLocalizedString("Navidrome", tableName: "Settings", comment: "Settings page title")
        view = createView()

        serverEdit.placeholderString = "http://10.0.0.2:4533"
        serverEdit.stringValue = naviolaSettings.serverURL ?? ""
        serverEdit.target = self
        serverEdit.action = #selector(serverChanged)

        usernameEdit.placeholderString = "username"
        usernameEdit.stringValue = naviolaSettings.username ?? ""
        usernameEdit.target = self
        usernameEdit.action = #selector(usernameChanged)

        passwordEdit.placeholderString = "password"
        passwordEdit.stringValue = naviolaSettings.password ?? ""
        passwordEdit.target = self
        passwordEdit.action = #selector(passwordChanged)

        testButton.bezelStyle = .rounded
        testButton.target = self
        testButton.action = #selector(testConnection)

        clearSessionButton.bezelStyle = .rounded
        clearSessionButton.target = self
        clearSessionButton.action = #selector(clearSession)

        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = ""
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Layout

    private func createView() -> NSView {
        let res = NSView()
        res.autoresizingMask = [.maxXMargin, .minYMargin]

        // Server URL
        res.addSubview(serverLabel)
        serverLabel.alignment = .right
        serverLabel.translatesAutoresizingMaskIntoConstraints = false
        serverLabel.topAnchor.constraint(equalToSystemSpacingBelow: res.topAnchor, multiplier: 1).isActive = true
        serverLabel.leadingAnchor.constraint(equalTo: res.leadingAnchor, constant: 16).isActive = true
        serverLabel.widthAnchor.constraint(equalToConstant: 100).isActive = true

        res.addSubview(serverEdit)
        serverEdit.translatesAutoresizingMaskIntoConstraints = false
        serverEdit.centerYAnchor.constraint(equalTo: serverLabel.centerYAnchor).isActive = true
        serverEdit.leadingAnchor.constraint(equalToSystemSpacingAfter: serverLabel.trailingAnchor, multiplier: 1).isActive = true
        res.trailingAnchor.constraint(equalToSystemSpacingAfter: serverEdit.trailingAnchor, multiplier: 1).isActive = true

        // Username
        res.addSubview(usernameLabel)
        usernameLabel.alignment = .right
        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        usernameLabel.topAnchor.constraint(equalToSystemSpacingBelow: serverLabel.bottomAnchor, multiplier: 1).isActive = true
        usernameLabel.leadingAnchor.constraint(equalTo: serverLabel.leadingAnchor).isActive = true
        usernameLabel.widthAnchor.constraint(equalTo: serverLabel.widthAnchor).isActive = true

        res.addSubview(usernameEdit)
        usernameEdit.translatesAutoresizingMaskIntoConstraints = false
        usernameEdit.centerYAnchor.constraint(equalTo: usernameLabel.centerYAnchor).isActive = true
        usernameEdit.leadingAnchor.constraint(equalTo: serverEdit.leadingAnchor).isActive = true
        usernameEdit.trailingAnchor.constraint(equalTo: serverEdit.trailingAnchor).isActive = true

        // Password
        res.addSubview(passwordLabel)
        passwordLabel.alignment = .right
        passwordLabel.translatesAutoresizingMaskIntoConstraints = false
        passwordLabel.topAnchor.constraint(equalToSystemSpacingBelow: usernameLabel.bottomAnchor, multiplier: 1).isActive = true
        passwordLabel.leadingAnchor.constraint(equalTo: serverLabel.leadingAnchor).isActive = true
        passwordLabel.widthAnchor.constraint(equalTo: serverLabel.widthAnchor).isActive = true

        res.addSubview(passwordEdit)
        passwordEdit.translatesAutoresizingMaskIntoConstraints = false
        passwordEdit.centerYAnchor.constraint(equalTo: passwordLabel.centerYAnchor).isActive = true
        passwordEdit.leadingAnchor.constraint(equalTo: serverEdit.leadingAnchor).isActive = true
        passwordEdit.trailingAnchor.constraint(equalTo: serverEdit.trailingAnchor).isActive = true

        // Separator
        let separator = Separator()
        res.addSubview(separator)
        separator.topAnchor.constraint(equalTo: passwordLabel.bottomAnchor, constant: 24).isActive = true
        separator.leadingAnchor.constraint(equalTo: res.leadingAnchor, constant: 20).isActive = true
        separator.trailingAnchor.constraint(equalTo: res.trailingAnchor, constant: -20).isActive = true

        // Test Connection + Clear Session buttons + status
        res.addSubview(testButton)
        testButton.translatesAutoresizingMaskIntoConstraints = false
        testButton.topAnchor.constraint(equalToSystemSpacingBelow: separator.bottomAnchor, multiplier: 1).isActive = true
        testButton.leadingAnchor.constraint(equalTo: serverEdit.leadingAnchor).isActive = true

        res.addSubview(clearSessionButton)
        clearSessionButton.translatesAutoresizingMaskIntoConstraints = false
        clearSessionButton.centerYAnchor.constraint(equalTo: testButton.centerYAnchor).isActive = true
        clearSessionButton.leadingAnchor.constraint(equalToSystemSpacingAfter: testButton.trailingAnchor, multiplier: 1).isActive = true

        res.addSubview(statusLabel)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.centerYAnchor.constraint(equalTo: testButton.centerYAnchor).isActive = true
        statusLabel.leadingAnchor.constraint(equalToSystemSpacingAfter: clearSessionButton.trailingAnchor, multiplier: 1).isActive = true

        res.bottomAnchor.constraint(equalTo: testButton.bottomAnchor, constant: 32).isActive = true

        return res
    }

    // MARK: - Actions

    @objc private func serverChanged(_ sender: NSTextField) {
        naviolaSettings.serverURL = sender.stringValue.isEmpty ? nil : sender.stringValue
    }

    @objc private func usernameChanged(_ sender: NSTextField) {
        naviolaSettings.username = sender.stringValue.isEmpty ? nil : sender.stringValue
    }

    @objc private func passwordChanged(_ sender: NSTextField) {
        naviolaSettings.password = sender.stringValue.isEmpty ? nil : sender.stringValue
    }

    @objc private func clearSession() {
        // Clear all cookies for the Navidrome server
        if let url = URL(string: naviolaSettings.serverURL ?? ""),
           let host = url.host {
            let storage = HTTPCookieStorage.shared
            for cookie in storage.cookies ?? [] {
                if cookie.domain.contains(host) {
                    storage.deleteCookie(cookie)
                }
            }
        }

        // Also reset URLSession caches
        URLSession.shared.reset {}

        statusLabel.textColor = .systemGreen
        statusLabel.stringValue = NSLocalizedString("Session cleared", tableName: "Settings", comment: "Navidrome status")
    }

    @objc private func testConnection() {
        // Flush current field values (NSSecureTextField doesn't fire action on every keystroke)
        naviolaSettings.serverURL = serverEdit.stringValue.isEmpty ? nil : serverEdit.stringValue
        naviolaSettings.username = usernameEdit.stringValue.isEmpty ? nil : usernameEdit.stringValue
        naviolaSettings.password = passwordEdit.stringValue.isEmpty ? nil : passwordEdit.stringValue

        guard let client = naviolaSettings.makeClient() else {
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = NSLocalizedString("Please fill in all fields", tableName: "Settings", comment: "Navidrome test status")
            return
        }

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = NSLocalizedString("Connecting...", tableName: "Settings", comment: "Navidrome test status")
        testButton.isEnabled = false

        Task {
            do {
                let ok = try await client.ping()
                await MainActor.run {
                    testButton.isEnabled = true
                    if ok {
                        statusLabel.textColor = .systemGreen
                        statusLabel.stringValue = NSLocalizedString("Connected", tableName: "Settings", comment: "Navidrome test status")
                    } else {
                        statusLabel.textColor = .systemRed
                        statusLabel.stringValue = NSLocalizedString("Connection failed", tableName: "Settings", comment: "Navidrome test status")
                    }
                }
            } catch {
                await MainActor.run {
                    testButton.isEnabled = true
                    statusLabel.textColor = .systemRed
                    statusLabel.stringValue = error.localizedDescription
                }
            }
        }
    }
}
