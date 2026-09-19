import SwiftUI

/// Divvy style region picker: drag across the grid to set where a layout puts
/// the window. Keyboard users get the percentage fields next to it, which edit
/// the same values.
struct GridPicker: View {
    @Binding var frame: FrameSpec
    let grid: GridSize

    private var columns: Int { grid.columns }
    private var rows: Int { grid.rows }
    private let spacing: CGFloat = 3

    @State private var anchor: Cell?
    @State private var focus: Cell?

    private struct Cell: Equatable {
        var column: Int
        var row: Int
    }

    var body: some View {
        GeometryReader { geometry in
            let size = cellSize(in: geometry.size)
            ZStack(alignment: .topLeading) {
                grid(size: size)
                selection(size: size)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(size: size))
        }
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        .frame(minHeight: 150)
        .accessibilityElement()
        .accessibilityLabel("Window region")
        .accessibilityValue(regionDescription)
        .accessibilityHint("Drag across the grid to choose a region, or use the percentage fields below.")
    }

    private func cellSize(in size: CGSize) -> CGSize {
        CGSize(
            width: (size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns),
            height: (size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows)
        )
    }

    private func grid(size: CGSize) -> some View {
        ForEach(0 ..< rows, id: \.self) { row in
            ForEach(0 ..< columns, id: \.self) { column in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: size.width, height: size.height)
                    .offset(
                        x: (size.width + spacing) * CGFloat(column),
                        y: (size.height + spacing) * CGFloat(row)
                    )
            }
        }
    }

    private func selection(size: CGSize) -> some View {
        let rect = pixelRect(size: size)
        return RoundedRectangle(cornerRadius: 5)
            .fill(Color.accentColor.opacity(0.75))
            .frame(width: max(rect.width, 0), height: max(rect.height, 0))
            .offset(x: rect.minX, y: rect.minY)
            .animation(.easeOut(duration: 0.08), value: frame)
    }

    /// Converts the stored fractions back into the grid's pixel space.
    private func pixelRect(size: CGSize) -> CGRect {
        let totalWidth = size.width * CGFloat(columns) + spacing * CGFloat(columns - 1)
        let totalHeight = size.height * CGFloat(rows) + spacing * CGFloat(rows - 1)
        return CGRect(
            x: totalWidth * frame.x,
            y: totalHeight * frame.y,
            width: totalWidth * frame.width,
            height: totalHeight * frame.height
        )
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = anchor ?? cell(at: value.startLocation, size: size)
                anchor = start
                focus = cell(at: value.location, size: size)
                apply(from: start, to: focus ?? start)
            }
            .onEnded { _ in
                anchor = nil
                focus = nil
            }
    }

    private func cell(at point: CGPoint, size: CGSize) -> Cell {
        let column = Int(point.x / (size.width + spacing))
        let row = Int(point.y / (size.height + spacing))
        return Cell(
            column: min(max(column, 0), columns - 1),
            row: min(max(row, 0), rows - 1)
        )
    }

    private func apply(from start: Cell, to end: Cell) {
        let minColumn = min(start.column, end.column)
        let maxColumn = max(start.column, end.column)
        let minRow = min(start.row, end.row)
        let maxRow = max(start.row, end.row)

        frame = FrameSpec(
            x: Double(minColumn) / Double(columns),
            y: Double(minRow) / Double(rows),
            width: Double(maxColumn - minColumn + 1) / Double(columns),
            height: Double(maxRow - minRow + 1) / Double(rows)
        )
    }

    private var regionDescription: String {
        let percent = { (value: Double) in Int((value * 100).rounded()) }
        return "\(percent(frame.width)) percent wide, \(percent(frame.height)) percent tall, "
            + "\(percent(frame.x)) percent from the left, \(percent(frame.y)) percent from the top"
    }
}
