import Foundation

enum SidebarEdge: String, Codable, CaseIterable, Identifiable {
    case left
    case right

    var id: Self { self }
}
