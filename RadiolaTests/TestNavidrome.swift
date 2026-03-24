//
//  TestNavidrome.swift
//  RadiolaTests
//
//  Naviola — Tests for NavidromeModels, NavidromeAuth, and NavidromeClient URL construction.
//

@testable import Radiola
import XCTest

final class TestNavidrome: XCTestCase {
    private func loadFixture(_ name: String) throws -> Data {
        let url = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("data")
            .appendingPathComponent("testNavidrome")
            .appendingPathComponent(name)
        return try Data(contentsOf: url)
    }

    // MARK: - NavidromeModels Tests

    func testDecodePingOk() throws {
        let data = try loadFixture("ping_ok.json")
        let response = try JSONDecoder().decode(SubsonicPingResponse.self, from: data)

        XCTAssertTrue(response.response.isOk)
        XCTAssertEqual(response.response.status, "ok")
        XCTAssertEqual(response.response.version, "1.16.1")
        XCTAssertNil(response.response.error)
    }

    func testDecodePingError() throws {
        let data = try loadFixture("ping_error.json")
        let response = try JSONDecoder().decode(SubsonicPingResponse.self, from: data)

        XCTAssertFalse(response.response.isOk)
        XCTAssertEqual(response.response.status, "failed")
        XCTAssertNotNil(response.response.error)
        XCTAssertEqual(response.response.error?.code, 40)
        XCTAssertEqual(response.response.error?.message, "Wrong username or password")
    }

    func testDecodeAlbumList2() throws {
        let data = try loadFixture("albumList2.json")
        let response = try JSONDecoder().decode(SubsonicAlbumList2Response.self, from: data)

        XCTAssertTrue(response.response.isOk)
        let albums = response.response.albumList2?.album ?? []
        XCTAssertEqual(albums.count, 2)

        XCTAssertEqual(albums[0].id, "album-001")
        XCTAssertEqual(albums[0].name, "Where the Joy Is")
        XCTAssertEqual(albums[0].artist, "We Are Messengers")
        XCTAssertEqual(albums[0].year, 2024)
        XCTAssertEqual(albums[0].songCount, 10)
        XCTAssertEqual(albums[0].coverArt, "al-album-001_cover")

        XCTAssertEqual(albums[1].id, "album-002")
        XCTAssertEqual(albums[1].name, "Counting My Blessings")
        XCTAssertEqual(albums[1].artist, "Seph Schlueter")
    }

    func testDecodeGetAlbum() throws {
        let data = try loadFixture("getAlbum.json")
        let response = try JSONDecoder().decode(SubsonicGetAlbumResponse.self, from: data)

        XCTAssertTrue(response.response.isOk)
        let album = response.response.album
        XCTAssertNotNil(album)
        XCTAssertEqual(album?.id, "album-001")
        XCTAssertEqual(album?.name, "Where the Joy Is")

        let songs = album?.song ?? []
        XCTAssertEqual(songs.count, 3)

        XCTAssertEqual(songs[0].id, "song-001")
        XCTAssertEqual(songs[0].title, "Keep Your Head Up")
        XCTAssertEqual(songs[0].track, 1)
        XCTAssertEqual(songs[0].duration, 166)
        XCTAssertEqual(songs[0].bitRate, 320)

        XCTAssertEqual(songs[1].id, "song-002")
        XCTAssertEqual(songs[1].title, "Come What May")
        XCTAssertEqual(songs[1].track, 2)

        XCTAssertEqual(songs[2].id, "song-003")
        XCTAssertEqual(songs[2].title, "God You Are")
    }

    func testDecodeSearch3() throws {
        let data = try loadFixture("search3.json")
        let response = try JSONDecoder().decode(SubsonicSearch3Response.self, from: data)

        XCTAssertTrue(response.response.isOk)
        let albums = response.response.searchResult3?.album ?? []
        XCTAssertEqual(albums.count, 1)
        XCTAssertEqual(albums[0].id, "album-search-001")
        XCTAssertEqual(albums[0].name, "By Surprise")
        XCTAssertEqual(albums[0].artist, "Joy Williams")
    }

    // MARK: - NavidromeAuth Tests

    func testMd5Hash() {
        let auth = NavidromeAuth.shared
        // Known MD5: md5("password") = 5f4dcc3b5aa765d61d8327deb882cf99
        XCTAssertEqual(auth.md5Hash("password"), "5f4dcc3b5aa765d61d8327deb882cf99")
    }

    func testAuthQueryItems() {
        let auth = NavidromeAuth.shared
        let items = auth.authQueryItems(username: "testuser", password: "testpass", salt: "abcd1234")

        let dict = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(dict["u"], "testuser")
        XCTAssertEqual(dict["s"], "abcd1234")
        XCTAssertEqual(dict["v"], "1.16.1")
        XCTAssertEqual(dict["c"], "Naviola")
        XCTAssertEqual(dict["f"], "json")

        // t = md5("testpass" + "abcd1234")
        let expectedToken = auth.md5Hash("testpass" + "abcd1234")
        XCTAssertEqual(dict["t"], expectedToken)
    }

    func testAuthQueryItemsRandomSalt() {
        let auth = NavidromeAuth.shared
        let items1 = auth.authQueryItems(username: "user", password: "pass")
        let items2 = auth.authQueryItems(username: "user", password: "pass")

        let salt1 = items1.first { $0.name == "s" }?.value
        let salt2 = items2.first { $0.name == "s" }?.value

        XCTAssertNotNil(salt1)
        XCTAssertNotNil(salt2)
        XCTAssertNotEqual(salt1, salt2, "Each call should generate a unique random salt")
    }

    // MARK: - NavidromeClient URL Construction Tests

    func testStreamURL() {
        let client = NavidromeClient(
            baseURL: URL(string: "http://music.example.com:4533")!,
            username: "user",
            password: "pass"
        )

        let url = client.streamURL(songId: "song-123")
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!

        XCTAssertEqual(components.scheme, "http")
        XCTAssertEqual(components.host, "music.example.com")
        XCTAssertEqual(components.port, 4533)
        XCTAssertEqual(components.path, "/rest/stream.view")

        let queryDict = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(queryDict["id"], "song-123")
        XCTAssertEqual(queryDict["u"], "user")
        XCTAssertEqual(queryDict["c"], "Naviola")
        XCTAssertEqual(queryDict["f"], "json")
    }

    func testCoverArtURL() {
        let client = NavidromeClient(
            baseURL: URL(string: "https://music.example.com")!,
            username: "user",
            password: "pass"
        )

        let url = client.coverArtURL(id: "al-123", size: 150)
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.path, "/rest/getCoverArt.view")

        let queryDict = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(queryDict["id"], "al-123")
        XCTAssertEqual(queryDict["size"], "150")
        XCTAssertEqual(queryDict["u"], "user")
    }
}
