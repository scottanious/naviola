//
//  NavidromeCoverArt.swift
//  Radiola
//
//  Naviola — Async cover art loading with in-memory cache.
//

import Cocoa

class NavidromeCoverArtCache {
    static let shared = NavidromeCoverArtCache()

    private let cache = NSCache<NSString, NSImage>()
    private var inFlight = Set<String>()

    init() {
        cache.countLimit = 200
    }

    /// Get cached image or nil. If not cached, starts async fetch and calls completion on main thread.
    func image(forCoverArtId id: String?, size: Int = 80, completion: @escaping (NSImage?) -> Void) {
        guard let id = id, !id.isEmpty else {
            completion(nil)
            return
        }

        let key = "\(id)_\(size)" as NSString

        if let cached = cache.object(forKey: key) {
            completion(cached)
            return
        }

        // Avoid duplicate fetches
        guard !inFlight.contains(key as String) else { return }
        inFlight.insert(key as String)

        guard let client = NaviolaSettings.shared.makeClient() else {
            inFlight.remove(key as String)
            completion(nil)
            return
        }

        let url = client.coverArtURL(id: id, size: size)

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let image = NSImage(data: data)
                await MainActor.run {
                    if let image = image {
                        self.cache.setObject(image, forKey: key)
                    }
                    self.inFlight.remove(key as String)
                    completion(image)
                }
            } catch {
                await MainActor.run {
                    self.inFlight.remove(key as String)
                    completion(nil)
                }
            }
        }
    }
}
