import SwiftUI
import CryptoKit
import Foundation

// Makes avatar URLs absolute, resolving relative ones against the Gerrit host.
func avatarURL(_ string: String, baseURL: String) -> URL? {
    if let url = URL(string: string), url.scheme != nil {
        return url
    }
    return URL(string: string, relativeTo: URL(string: baseURL))?.absoluteURL
}

// Deterministic cache file name for an avatar URL.
func avatarCacheFileName(for url: URL) -> String {
    return SHA256.hash(data: Data(url.absoluteString.utf8))
        .map { String(format: "%02x", $0) }
        .joined()
}

private func avatarCacheURL(for url: URL) -> URL {
    return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("userpics", isDirectory: true)
        .appendingPathComponent(avatarCacheFileName(for: url))
}

struct UserpicView: View {
    let account: AccountInfo?
    var size: CGFloat = 20
    @Environment(Settings.self) var settings: Settings
    @State private var image: UIImage?

    var body: some View {
        if settings.showUserpics,
           let info = account?.avatars?.first,
           let url = avatarURL(info.url, baseURL: settings.gerritUrl) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(uiColor: .tertiarySystemFill)
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .task(id: url) {
                image = await Self.load(url: url)
            }
        }
    }

    // Downloads once per install session and caches on disk by URL hash.
    static func load(url: URL) async -> UIImage? {
        let cached = avatarCacheURL(for: url)
        if let image = UIImage(contentsOfFile: cached.path) {
            return image
        }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let downloaded = UIImage(data: data) else {
            return nil
        }
        try? FileManager.default.createDirectory(
            at: cached.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: cached)
        return downloaded
    }
}
