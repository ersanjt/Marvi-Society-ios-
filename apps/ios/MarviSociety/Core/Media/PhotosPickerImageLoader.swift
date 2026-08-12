import CoreTransferable
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Reliable image bytes from `PhotosPickerItem`.
/// `loadTransferable(type: Data.self)` often returns nil/hangs for HEIC + iCloud photos.
enum PhotosPickerImageLoader {
    private struct ImportedImageData: Transferable {
        let data: Data

        static var transferRepresentation: some TransferRepresentation {
            DataRepresentation(importedContentType: .image) { data in
                ImportedImageData(data: data)
            }
            DataRepresentation(importedContentType: .jpeg) { data in
                ImportedImageData(data: data)
            }
            DataRepresentation(importedContentType: .png) { data in
                ImportedImageData(data: data)
            }
            DataRepresentation(importedContentType: UTType("public.heic") ?? .image) { data in
                ImportedImageData(data: data)
            }
        }
    }

    /// Loads image bytes with a hard timeout so the UI spinner cannot stick forever.
    static func loadData(from item: PhotosPickerItem, timeoutSeconds: TimeInterval = 25) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                if let imported = try await item.loadTransferable(type: ImportedImageData.self),
                   !imported.data.isEmpty {
                    return imported.data
                }
                if let data = try await item.loadTransferable(type: Data.self), !data.isEmpty {
                    return data
                }
                throw MarviAPIError.server(message: "Could not read the selected photo.")
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                throw MarviAPIError.server(message: "Photo loading timed out. Try a smaller photo from the Camera Roll.")
            }
            let data = try await group.next()!
            group.cancelAll()
            return data
        }
    }
}
