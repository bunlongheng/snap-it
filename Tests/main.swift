import CoreGraphics
import Foundation

let run = TestRun()

// MARK: - KeyCombo

run.suite("KeyCombo")

let leftHalf = try KeyCombo(parsing: "cmd+alt+left")
run.equal(leftHalf.stringValue, "cmd+alt+left", "parses the documented example")
run.equal(leftHalf.keyCode, 123, "maps left arrow to its virtual key code")
run.expect(leftHalf.modifiers == [.command, .option], "keeps both modifiers")

run.equal(try KeyCombo(parsing: "CMD + Alt + \u{2190}").stringValue, "cmd+alt+left", "accepts glyphs and spacing")
run.equal(try KeyCombo(parsing: "option+ctrl+2").stringValue, "ctrl+alt+2", "normalises modifier order")
run.equal(try KeyCombo(parsing: "cmd+alt+enter").stringValue, "cmd+alt+return", "resolves key aliases")
run.equal(try KeyCombo(parsing: "cmd+shift+alt+k").displayValue, "\u{2325}\u{21E7}\u{2318}K", "renders glyphs")

run.throwsError("rejects a shortcut with no modifier") { _ = try KeyCombo(parsing: "left") }
run.throwsError("rejects shift only") { _ = try KeyCombo(parsing: "shift+left") }
run.throwsError("rejects an unknown key") { _ = try KeyCombo(parsing: "cmd+alt+nope") }
run.throwsError("rejects two keys") { _ = try KeyCombo(parsing: "cmd+a+b") }
run.throwsError("rejects an empty string") { _ = try KeyCombo(parsing: "") }
run.throwsError("rejects a repeated modifier") { _ = try KeyCombo(parsing: "cmd+cmd+a") }

let roundTripped = try JSONDecoder().decode(
    KeyCombo.self,
    from: JSONEncoder().encode(try KeyCombo(parsing: "ctrl+shift+f1"))
)
run.equal(roundTripped.stringValue, "ctrl+shift+f1", "survives a JSON round trip")

// MARK: - FrameSpec

run.suite("FrameSpec")

run.expect(
    (try? FrameSpec(x: 0, y: 0, width: 0.5, height: 1).validate(layoutName: "Left")) != nil,
    "accepts a left half"
)
run.throwsError("rejects a negative origin") {
    try FrameSpec(x: -0.1, y: 0, width: 0.5, height: 1).validate(layoutName: "Bad")
}
run.throwsError("rejects a window wider than the screen") {
    try FrameSpec(x: 0.6, y: 0, width: 0.5, height: 1).validate(layoutName: "Bad")
}
run.throwsError("rejects a sliver") {
    try FrameSpec(x: 0, y: 0, width: 0.01, height: 1).validate(layoutName: "Bad")
}
run.throwsError("rejects a value that is not a number") {
    try FrameSpec(x: .nan, y: 0, width: 0.5, height: 1).validate(layoutName: "Bad")
}

// MARK: - Placement

run.suite("Placement")

let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)

let half = Placement.rect(for: FrameSpec(x: 0, y: 0, width: 0.5, height: 1), in: screen, gap: 0)
run.equal(half, CGRect(x: 0, y: 25, width: 720, height: 875), "left half fills half the usable area")

let right = Placement.rect(for: FrameSpec(x: 0.5, y: 0, width: 0.5, height: 1), in: screen, gap: 0)
run.equal(right, CGRect(x: 720, y: 25, width: 720, height: 875), "right half starts at the midpoint")

let secondScreen = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
let onSecond = Placement.rect(for: FrameSpec(x: 0, y: 0, width: 0.5, height: 1), in: secondScreen, gap: 0)
run.equal(onSecond, CGRect(x: 1440, y: 0, width: 960, height: 1080), "fractions follow the display")

let gapped = Placement.rect(for: FrameSpec(x: 0, y: 0, width: 0.5, height: 1), in: screen, gap: 10)
let gappedRight = Placement.rect(for: FrameSpec(x: 0.5, y: 0, width: 0.5, height: 1), in: screen, gap: 10)
run.equal(gapped.minX, 10, "a gap insets from the screen edge")
run.equal(gappedRight.maxX, 1430, "and from the opposite edge")
run.equal(gappedRight.minX - gapped.maxX, 10, "neighbours end up one gap apart")

let full = Placement.rect(for: FrameSpec(x: 0, y: 0, width: 1, height: 1), in: screen, gap: 0)
run.equal(full, screen, "maximize uses the whole usable area")

let clamped = Placement.rect(for: FrameSpec(x: 0, y: 0, width: 1, height: 1), in: screen, gap: 9_999)
run.equal(clamped.width, screen.width - 2 * Placement.maximumGap, "an absurd gap is clamped")

// MARK: - Config

run.suite("Config")

run.expect((try? Config.standard.validate()) != nil, "the shipped defaults are valid")
run.equal(Config.standard.layouts.count, 10, "ships 10 layouts")
run.equal(
    Config.standard.layouts.first { $0.id == "left-half" }?.shortcut?.stringValue,
    "cmd+alt+left",
    "left half is on the documented shortcut"
)

run.equal(
    Config.standard.layouts.first { $0.id == "maximize" }?.shortcut?.stringValue,
    "cmd+alt+up",
    "maximize keeps its documented binding"
)
run.equal(
    Set(Config.standard.layouts.compactMap { $0.shortcut?.stringValue }).count,
    Config.standard.layouts.count,
    "every default layout has its own shortcut"
)

run.throwsError("rejects two layouts sharing a shortcut") {
    try Config(layouts: [
        .make("a", "A", 0, 0, 0.5, 1, "cmd+alt+left"),
        .make("b", "B", 0.5, 0, 0.5, 1, "cmd+alt+left"),
    ]).validate()
}
run.throwsError("rejects duplicate ids") {
    try Config(layouts: [
        .make("a", "A", 0, 0, 0.5, 1, nil),
        .make("a", "B", 0.5, 0, 0.5, 1, nil),
    ]).validate()
}
run.throwsError("rejects a blank name") {
    try Config(layouts: [.make("a", "  ", 0, 0, 0.5, 1, nil)]).validate()
}
run.throwsError("rejects a gap outside the allowed range") {
    try Config(gap: 500, layouts: Config.standard.layouts).validate()
}

run.throwsError("rejects an impossible grid") {
    try Config(grid: GridSize(columns: 0, rows: 6), layouts: Config.standard.layouts).validate()
}
run.equal(Config.standard.grid, GridSize(columns: 6, rows: 6), "defaults to a 6 by 6 grid")

let decoded = try JSONDecoder().decode(Config.self, from: Data("""
{"layouts":[{"id":"a","name":"A","frame":{"x":0,"y":0,"width":1,"height":0.5},"shortcut":"cmd+ctrl+up"}]}
""".utf8))
run.equal(decoded.gap, 0, "a missing gap defaults to zero")
run.equal(decoded.grid, GridSize.standard, "a missing grid defaults to 6 by 6")
run.equal(decoded.layouts.first?.shortcut?.stringValue, "cmd+ctrl+up", "reads a shortcut string")

run.throwsError("refuses a config file with a broken shortcut") {
    _ = try JSONDecoder().decode(Config.self, from: Data("""
    {"layouts":[{"id":"a","name":"A","frame":{"x":0,"y":0,"width":1,"height":1},"shortcut":"banana"}]}
    """.utf8))
}

// MARK: - ConfigStore

run.suite("ConfigStore")

let directory = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("snap-it-tests-\(UUID().uuidString)")
let store = ConfigStore(url: directory.appendingPathComponent("config.json"))

run.equal(try store.load().layouts.count, 10, "falls back to the defaults when nothing is saved")

let created = try store.loadOrCreate()
run.expect(FileManager.default.fileExists(atPath: store.url.path), "a first run writes the file")
run.equal(created, Config.standard, "and it holds the defaults")

var edited = created
edited.gap = 12
edited.layouts[0].name = "Left Side"
try store.save(edited)
run.equal(try store.load(), edited, "saves and reloads without drift")

try Data("not json".utf8).write(to: store.url)
run.throwsError("reports a corrupt file instead of guessing") { _ = try store.load() }
run.expect(
    (try? String(contentsOf: store.url, encoding: .utf8)) == "not json",
    "and leaves the broken file alone"
)

run.throwsError("refuses to save an invalid config") {
    try store.save(Config(gap: -1, layouts: Config.standard.layouts))
}

try? FileManager.default.removeItem(at: directory)

exit(run.finish())
