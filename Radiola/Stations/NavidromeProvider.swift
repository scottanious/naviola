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
        case pinned
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
        case .pinned:
            return NaviolaSettings.shared.isConfigured && !NaviolaPinnedItemStore.shared.items.isEmpty
        }
    }

    func fetch() async throws -> [SubsonicAlbumID3] {
        guard let client = NaviolaSettings.shared.makeClient() else { return [] }

        switch lensType {
        case .recentlyAdded:
            return try await client.getAlbumList2(type: "newest", size: 50)
        case .search:
            guard !searchText.isEmpty else { return [] }
            return try await client.search3(query: searchText, albumCount: 50)
        case .pinned:
            return fetchPinnedAlbums(client: client)
        }
    }

    /// Resolve pinned album items into SubsonicAlbumID3 stubs for display.
    /// We don't re-fetch from server — just convert stored metadata to the display type.
    private func fetchPinnedAlbums(client: NavidromeClient) -> [SubsonicAlbumID3] {
        return NaviolaPinnedItemStore.shared.items
            .filter { $0.type == .album }
            .map { item in
                // Parse artist from "Artist - Album" title format
                let parts = item.title.components(separatedBy: " - ")
                let artist = parts.count > 1 ? parts.first : nil
                let albumName = parts.count > 1 ? parts.dropFirst().joined(separator: " - ") : item.title

                return SubsonicAlbumID3(
                    id: item.subsonicId,
                    name: albumName,
                    artist: artist,
                    artistId: nil,
                    coverArt: item.coverArtId,
                    songCount: nil,
                    duration: nil,
                    created: nil,
                    year: nil,
                    genre: nil
                )
            }
    }
}
