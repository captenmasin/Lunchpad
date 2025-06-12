import SwiftUI
import AppKit

struct InstalledApp: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let path: String
    var icon: NSImage {
        let image = NSWorkspace.shared.icon(forFile: path)
        image.size = NSSize(width: 64, height: 64)
        return image
    }
}

struct FolderDragPayload: Codable {
    let app: InstalledApp
    let folderID: UUID
}

struct AppFolder: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var apps: [InstalledApp]
}

enum AppItem: Identifiable, Hashable, Codable {
    case app(InstalledApp)
    case folder(AppFolder)

    var id: UUID {
        switch self {
        case .app(let app): return app.id
        case .folder(let folder): return folder.id
        }
    }

    enum CodingKeys: String, CodingKey {
        case app, folder
    }

    enum CodingError: Error {
        case decodingError
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let app = try container.decodeIfPresent(InstalledApp.self, forKey: .app) {
            self = .app(app)
        } else if let folder = try container.decodeIfPresent(AppFolder.self, forKey: .folder) {
            self = .folder(folder)
        } else {
            throw CodingError.decodingError
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .app(let app): try container.encode(app, forKey: .app)
        case .folder(let folder): try container.encode(folder, forKey: .folder)
        }
    }

    var isFolder: Bool {
        if case .folder = self { return true }
        return false
    }

    func asApp() -> InstalledApp? {
        if case .app(let app) = self { return app }
        return nil
    }
}
