import SwiftUI
import AppKit

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
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: 0), count: columnCount)
        
        if let screen = NSScreen.main,
           let wallpaperURL = NSWorkspace.shared.desktopImageURL(for: screen),
           let nsImage = NSImage(contentsOf: wallpaperURL) {
        }
    

        ZStack {
            if let screen = NSScreen.main,
               let wallpaperURL = NSWorkspace.shared.desktopImageURL(for: screen),
               let nsImage = NSImage(contentsOf: wallpaperURL) {
                
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    HStack {
                        TextField(
                            "Search",
                            text: $viewModel.searchText
                        )
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Reset") { viewModel.resetLayout()
                        }
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

// MARK: - Helpers

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
                .frame(width: 80, height: 80)
                .cornerRadius(12)
            Text(app.name)
                .font(.subheadline)
                .lineLimit(1)
        case .folder(let folder):
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.15))
                Image(systemName: "folder.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
                    .foregroundColor(.accentColor)
                    }
                    .frame(width: 64, height: 64)
                    Text(folder.name)
                    .font(.subheadline)
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
                NSApplication.shared.windows.first?.miniaturize(nil)
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
        var newIndex = current + offset

        if offset == 1 || offset == -1 {
            // Allow horizontal wrap
            newIndex = (newIndex + count) % count
        } else {
            // Vertical navigation: clamp
            newIndex = min(max(newIndex, 0), count - 1)
        }
        
        if(current == 0 && newIndex == (count - 1)){
            newIndex = 0
        }
        
        if(current == (count - 1) && newIndex == 0){
            newIndex = (count - 1)
        }

        selectedIndex = newIndex
        let item = filteredItems()[newIndex]
        withAnimation {
            proxy.scrollTo(item.id, anchor: .center)
        }
    }

        func calculateCurrentColumns(for width: CGFloat) -> Int {
            let itemWidth: CGFloat = 120
            return max(Int(width / itemWidth), 1)
        }
    }


#Preview{
ContentView()
}
