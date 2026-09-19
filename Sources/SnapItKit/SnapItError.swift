import Foundation

/// Every user facing failure Snap It can report.
enum SnapItError: Error, Equatable, LocalizedError {
    case invalidShortcut(String, reason: String)
    case invalidFrame(layout: String, reason: String)
    case duplicateShortcut(String, layouts: [String])
    case duplicateIdentifier(String)
    case emptyName(id: String)
    case invalidGap(Double)
    case invalidGrid(columns: Int, rows: Int)
    case configUnreadable(path: String, reason: String)

    var errorDescription: String? {
        switch self {
        case let .invalidShortcut(value, reason):
            return "Shortcut \"\(value)\" is not valid because \(reason)."
        case let .invalidFrame(layout, reason):
            return "Layout \"\(layout)\" has an invalid frame because \(reason)."
        case let .duplicateShortcut(shortcut, layouts):
            return "Shortcut \"\(shortcut)\" is claimed by more than one layout: \(layouts.joined(separator: ", "))."
        case let .duplicateIdentifier(id):
            return "Layout id \"\(id)\" is used more than once."
        case let .emptyName(id):
            return "Layout \"\(id)\" needs a name."
        case let .invalidGap(value):
            return "Gap must be between 0 and 64 points, got \(value)."
        case let .invalidGrid(columns, rows):
            return "The grid must be between 1 and 12 in each direction, got \(columns) by \(rows)."
        case let .configUnreadable(path, reason):
            return "Could not read \(path): \(reason)"
        }
    }
}
