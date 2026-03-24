//
//  NavidromeProvider.swift
//  Radiola
//
//  Naviola — Lens-based provider for browsing Navidrome content.
//  Parallel to RadioBrowserProvider.swift.
//

import Foundation

// MARK: - NavidromeProvider

class NavidromeProvider: ObservableObject {
    let lensType: LensType
    @Published var searchText: String = ""

    enum LensType {
        case recentlyAdded
        case search
        // Future: .artists, .genres, .random, .mostPlayed
    }

    init(_ lensType: LensType) {
        self.lensType = lensType
    }

    func canFetch() -> Bool {
        switch lensType {
        case .recentlyAdded:
            return NaviolaSettings.shared.isConfigured
        case .search:
            return NaviolaSettings.shared.isConfigured && !searchText.isEmpty
        }
    }

    func fetch() async throws -> [SubsonicAlbumID3] {
        guard let client = NaviolaSettings.shared.makeClient() else { return [] }

        switch lensType {
        case .recentlyAdded:
            return try await client.getAlbumList2(type: "newest", size: 50)
        case .search:
            // Search will be implemented in Phase 6
            return []
        }
    }
}
