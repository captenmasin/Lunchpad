import SwiftUI

class AppViewModel: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var appItems: [AppItem] = []
    @Published var searchText: String = ""

    init() {
        loadLayout()
        if appItems.isEmpty {
            loadApplications()
        }
    }

    func resetLayout() {
        let url = getSaveURL()
        try? FileManager.default.removeItem(at: url)
        loadApplications()
    }

    func renameFolder(folderID: UUID, newName: String) {
        guard let folderIndex = appItems.firstIndex(where: {
            if case .folder(let f) = $0 { return f.id == folderID }
            return false
        }) else { return }

        if case .folder(var folderToUpdate) = appItems[folderIndex] {
            folderToUpdate.name = newName
            appItems[folderIndex] = .folder(folderToUpdate)
            saveLayout()
        }
    }

    func moveAppOutOfFolder(app: InstalledApp, folderID: UUID) {
        guard let folderIndex = appItems.firstIndex(where: {
            if case .folder(let f) = $0 { return f.id == folderID }
            return false
        }) else { return }

        if case .folder(var folderToUpdate) = appItems[folderIndex] {
            folderToUpdate.apps.removeAll { $0.id == app.id }

            if folderToUpdate.apps.count == 1 {
                let remainingApp = folderToUpdate.apps[0]
                appItems[folderIndex] = .app(remainingApp)
            } else {
                appItems[folderIndex] = .folder(folderToUpdate)
            }

            appItems.insert(.app(app), at: 0)
            saveLayout()
        }
    }

    func loadApplications() {
        let fileManager = FileManager.default
        let applicationDirectories = [
            "/Applications",
            "/System/Applications",
            "\(NSHomeDirectory())/Applications"
        ]

        var foundApps: [InstalledApp] = []

        for directory in applicationDirectories {
            if let appPaths = try? fileManager.contentsOfDirectory(atPath: directory) {
                for appName in appPaths where appName.hasSuffix(".app") {
                    let fullPath = "\(directory)/\(appName)"
                    let name = appName.replacingOccurrences(of: ".app", with: "")
                    foundApps.append(InstalledApp(id: UUID(), name: name, path: fullPath))
                }
            }
        }

        DispatchQueue.main.async {
            self.apps = foundApps.sorted { $0.name.lowercased() < $1.name.lowercased() }
            self.appItems = self.apps.map { AppItem.app($0) }
            self.saveLayout()
        }
    }

    func saveLayout() {
        do {
            let data = try JSONEncoder().encode(appItems)
            let url = getSaveURL()
            try data.write(to: url)
        } catch {
            print("❌ Failed to save layout: \(error)")
        }
    }

    func loadLayout() {
        do {
            let url = getSaveURL()
            let data = try Data(contentsOf: url)
            self.appItems = try JSONDecoder().decode([AppItem].self, from: data)
        } catch {
            print("❌ Failed to load layout: \(error)")
        }
    }

    private func getSaveURL() -> URL {
        let fm = FileManager.default
        let folder = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = folder.appendingPathComponent("LaunchpadClone", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("layout.json")
    }
}
