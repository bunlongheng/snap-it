import Foundation

// Prints the shipped defaults as JSON. The README table and the landing page
// are generated from this, so the layout list is defined once in Config.swift
// and never copied by hand. See scripts/sync-defaults.py.
struct Row: Encodable {
    let id: String
    let name: String
    let shortcut: String?
    let display: String?
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

let rows = Config.standard.layouts.map {
    Row(
        id: $0.id,
        name: $0.name,
        shortcut: $0.shortcut?.stringValue,
        display: $0.shortcut?.displayValue,
        x: $0.frame.x,
        y: $0.frame.y,
        width: $0.frame.width,
        height: $0.frame.height
    )
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
FileHandle.standardOutput.write(try encoder.encode(rows))
