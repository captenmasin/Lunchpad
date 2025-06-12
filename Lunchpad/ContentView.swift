import SwiftUI
import AppKit

// MARK: - Models

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
}

extension AppItem {
    var isFolder: Bool {
        if case .folder = self { return true }
        return false
    }

    func asApp() -> InstalledApp? {
        if case .app(let app) = self { return app }
        return nil
    }
}

// MARK: - ViewModel

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


// MARK: - KeyCaptureView (Keyboard Input Bridge)

struct KeyCaptureView: NSViewRepresentable {
    var onKeyDown: (NSEvent) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class KeyView: NSView {
        var onKeyDown: ((NSEvent) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }

        override func keyDown(with event: NSEvent) {
            onKeyDown?(event)
        }
    }
}

// MARK: - ContentView (Main UI)

struct ContentView: View {
    @State private var activeFolder: AppFolder? = nil
    @StateObject var viewModel = AppViewModel()
    @State private var selectedIndex: Int? = nil
    @State private var isKeyboardNavigating = false
    @State private var draggedItem: AppItem?
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let itemWidth: CGFloat = 120
            let columnCount = max(Int(availableWidth / itemWidth), 1)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 20), count: columnCount)
            
            ZStack {
                ScrollViewReader { proxy in
                    VStack(spacing: 0) {
                        HStack {
                            TextField("Search", text: $viewModel.searchText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Button("Reset") { viewModel.resetLayout() }
                        }
                        .padding()
                        
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(filteredItems(), id: \.id) { item in
                                    appIcon(for: item)
                                        .id(item.id)
                                        .onDrag {
                                            self.draggedItem = item
                                            return NSItemProvider(object: item.id.uuidString as NSString)
                                        }
                                        .onDrop(of: [.text], delegate: DropViewDelegate(targetItem: item, draggedItem: $draggedItem, viewModel: viewModel))
                                }
                            }
                            .padding()
                        }
                        .frame(height: geometry.size.height - 55)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    KeyCaptureView { event in
                        handleKey(event, proxy: proxy, availableWidth: geometry.size.width)
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .sheet(item: $activeFolder, onDismiss: { activeFolder = nil }) { folder in
            FolderView(folderID: folder.id, viewModel: viewModel)
        }
    }
    
    // MARK: - Logic Helpers
    
    func filteredItems() -> [AppItem] {
        if viewModel.searchText.isEmpty {
            return viewModel.appItems
        } else {
            return viewModel.appItems.filter { item in
                switch item {
                case .app(let app): return app.name.localizedCaseInsensitiveContains(viewModel.searchText)
                case .folder(let folder): return folder.name.localizedCaseInsensitiveContains(viewModel.searchText)
                }
            }
        }
    }
    
    @ViewBuilder
    func appIcon(for item: AppItem) -> some View {
        VStack {
            switch item {
            case .app(let app):
                Image(nsImage: app.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .cornerRadius(12)
                Text(app.name)
                    .font(.caption)
                    .lineLimit(1)
                
            case .folder(let folder):
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.15))
                    Image(systemName: "folder.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)
                }
                .frame(width: 64, height: 64)
                Text(folder.name)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .onTapGesture {
            switch item {
            case .app(let app): NSWorkspace.shared.open(URL(fileURLWithPath: app.path))
            case .folder(let folder): activeFolder = folder
            }
        }
        .padding(4)
        .background(selectedIndexMatch(for: item) ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    func selectedIndexMatch(for item: AppItem) -> Bool {
        guard let index = selectedIndex else { return false }
        let items = filteredItems()
        guard index >= 0 && index < items.count else { return false }
        return items[index].id == item.id
    }
    
    // MARK: - Keyboard Navigation Logic

    func handleKey(_ event: NSEvent, proxy: ScrollViewProxy, availableWidth: CGFloat) {
        switch event.keyCode {
        case 123:
            isKeyboardNavigating = true
            moveSelection(offset: -1, proxy: proxy)
        case 124:
            isKeyboardNavigating = true
            moveSelection(offset: 1, proxy: proxy)
        case 125:
            isKeyboardNavigating = true
            let columns = calculateCurrentColumns(for: availableWidth)
            moveSelection(offset: columns, proxy: proxy)
        case 126:
            isKeyboardNavigating = true
            let columns = calculateCurrentColumns(for: availableWidth)
            moveSelection(offset: -columns, proxy: proxy)
        case 36:
            if let selected = selectedIndex {
                let item = filteredItems()[selected]
                switch item {
                case .app(let app): NSWorkspace.shared.open(URL(fileURLWithPath: app.path))
                case .folder(let folder): activeFolder = folder
                }
            }
        case 53:
            viewModel.searchText = ""
        case 51, 117:
            if !viewModel.searchText.isEmpty {
                viewModel.searchText.removeLast()
            }
        default:
            if let chars = event.charactersIgnoringModifiers, chars.count == 1 {
                viewModel.searchText.append(chars)
            }
        }
    }

    func moveSelection(offset: Int, proxy: ScrollViewProxy) {
        guard !filteredItems().isEmpty else { return }
        let count = filteredItems().count
        let current = selectedIndex ?? 0
        selectedIndex = (current + offset + count) % count
        let item = filteredItems()[selectedIndex!]
        withAnimation {
            proxy.scrollTo(item.id, anchor: .center)
        }
    }

    func calculateCurrentColumns(for width: CGFloat) -> Int {
        let itemWidth: CGFloat = 120
        return max(Int(width / itemWidth), 1)
    }
}

// MARK: - DropViewDelegate (handles drag/drop folder logic)

struct DropViewDelegate: DropDelegate {
    let targetItem: AppItem
    @Binding var draggedItem: AppItem?
    let viewModel: AppViewModel

    func performDrop(info: DropInfo) -> Bool {
        guard let dragged = draggedItem, dragged != targetItem else { return false }

        if dragged.isFolder || (targetItem.isFolder && dragged.isFolder) {
            return false
        }

        var items = viewModel.appItems

        guard let draggedIndex = items.firstIndex(where: { $0.id == dragged.id }),
              let targetIndex = items.firstIndex(where: { $0.id == targetItem.id }) else {
            return false
        }

        items.remove(at: draggedIndex)

        switch targetItem {
        case .app(let targetApp):
            if let secondTargetIndex = items.firstIndex(where: { $0.id == targetItem.id }) {
                items.remove(at: secondTargetIndex)
            }

            let appsToMerge: [InstalledApp] = [
                dragged.asApp(), targetApp
            ].compactMap { $0 }

            let folder = AppFolder(id: UUID(), name: "New Folder", apps: appsToMerge)
            let newFolderItem = AppItem.folder(folder)
            items.insert(newFolderItem, at: targetIndex)

        case .folder(var folder):
            if let newApp = dragged.asApp() {
                folder.apps.append(newApp)
                let updatedFolderItem = AppItem.folder(folder)
                items[targetIndex] = updatedFolderItem
            }
        }

        DispatchQueue.main.async {
            viewModel.appItems = items
            viewModel.saveLayout()
        }

        return true
    }
}

// MARK: - FolderView (handles opening and renaming folders)

struct FolderView: View {
    let folderID: UUID
    @ObservedObject var viewModel: AppViewModel
    let columns = [GridItem(.adaptive(minimum: 80), spacing: 20)]
    @Environment(\.presentationMode) var presentationMode

    var folder: AppFolder {
        guard let item = viewModel.appItems.first(where: {
            if case .folder(let f) = $0 { return f.id == folderID }
            return false
        }),
        case .folder(let liveFolder) = item else {
            fatalError("Folder not found")
        }
        return liveFolder
    }

    var body: some View {
        VStack {
            TextField("Folder Name", text: Binding(
                get: { folder.name },
                set: { newName in
                    viewModel.renameFolder(folderID: folder.id, newName: newName)
                }
            ))
            .font(.largeTitle)
            .padding()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(folder.apps) { app in
                        folderAppIcon(for: app)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    @ViewBuilder
    func folderAppIcon(for app: InstalledApp) -> some View {
        VStack {
            Image(nsImage: app.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .cornerRadius(12)
            Text(app.name)
                .font(.caption)
                .lineLimit(1)
        }
        .onTapGesture {
            NSWorkspace.shared.open(URL(fileURLWithPath: app.path))
        }
        .onDrag {
            let encoder = JSONEncoder()
            guard let encodedData = try? encoder.encode(FolderDragPayload(app: app, folderID: folder.id)) else {
                return NSItemProvider()
            }
            let base64String = encodedData.base64EncodedString()
            return NSItemProvider(object: NSString(string: base64String))
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
    }
}

#Preview {
    ContentView()
}

