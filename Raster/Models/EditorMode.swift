import Foundation

enum EditorMode: String, CaseIterable, Identifiable {
    case editor
    case split
    case reading

    var id: String { rawValue }
}
