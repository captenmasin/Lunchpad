import SwiftUI

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
