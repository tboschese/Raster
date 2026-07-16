import Foundation

enum RasterError: Error, LocalizedError {
    case fileReadFailed(URL)
    case fileWriteFailed(URL)
    case folderAccessDenied
    case bookmarkResolutionFailed
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileReadFailed(let url):
            return String(format: String(localized: "Couldn't read %@."), url.lastPathComponent)
        case .fileWriteFailed(let url):
            return String(format: String(localized: "Couldn't save %@."), url.lastPathComponent)
        case .folderAccessDenied:
            return String(localized: "Raster doesn't have permission to access this folder.")
        case .bookmarkResolutionFailed:
            return String(localized: "This file or folder can no longer be located.")
        case .exportFailed(let reason):
            return String(format: String(localized: "Export failed: %@"), reason)
        }
    }
}
