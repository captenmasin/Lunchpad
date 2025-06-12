import SwiftUI
import AppKit

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
