import Foundation

/// The grid the preferences picker snaps to.
/// Saved layouts are fractions, so changing the grid never moves an existing
/// layout, it only changes what the picker can select.
struct GridSize: Codable, Hashable {
    var columns: Int
    var rows: Int

    static let standard = GridSize(columns: 6, rows: 6)
    static let range = 1 ... 12

    func validate() throws {
        guard GridSize.range.contains(columns), GridSize.range.contains(rows) else {
            throw SnapItError.invalidGrid(columns: columns, rows: rows)
        }
    }
}
