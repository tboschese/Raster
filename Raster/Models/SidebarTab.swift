import Foundation

enum SidebarTab: String, CaseIterable, Identifiable {
    case files
    case outline

    var id: String { rawValue }
}
