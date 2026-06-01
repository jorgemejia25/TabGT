import SwiftUI

struct FolderTreeRow: View {
    var row: VisibleTreeRow
    var onOpen: (() -> Void)?
    var onChangeDirectory: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: row.isDirectory ? "folder" : "doc")
                .font(.system(size: 11))
                .foregroundStyle(row.isDirectory ? AppTheme.selectionBlue : AppTheme.textSecondary)
                .frame(width: 14)

            Text(row.name)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            guard row.isDirectory, let onOpen else { return }
            onOpen()
        }
        .contextMenu {
            if row.isDirectory, let onChangeDirectory {
                Button("CD") {
                    onChangeDirectory()
                }
            }
        }
    }
}
