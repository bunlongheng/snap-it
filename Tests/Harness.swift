import Foundation

/// A 40 line test harness, because the Command Line Tools ship no XCTest and
/// Snap It is not worth a dependency.
final class TestRun {
    private var currentSuite = ""
    private var failures: [String] = []
    private var assertions = 0

    func suite(_ name: String) {
        currentSuite = name
        FileHandle.standardOutput.write(Data("\n\(name)\n".utf8))
    }

    func expect(_ condition: Bool, _ what: String, line: UInt = #line) {
        assertions += 1
        if condition {
            report("  ok   \(what)")
        } else {
            let message = "  FAIL \(what) (\(currentSuite):\(line))"
            failures.append(message)
            report(message)
        }
    }

    func equal<T: Equatable>(_ actual: T, _ expected: T, _ what: String, line: UInt = #line) {
        assertions += 1
        if actual == expected {
            report("  ok   \(what)")
        } else {
            let message = """
              FAIL \(what) (\(currentSuite):\(line))
                   expected \(expected)
                   got      \(actual)
            """
            failures.append(message)
            report(message)
        }
    }

    func throwsError(_ what: String, line: UInt = #line, _ body: () throws -> Void) {
        assertions += 1
        do {
            try body()
            let message = "  FAIL \(what): expected an error (\(currentSuite):\(line))"
            failures.append(message)
            report(message)
        } catch {
            report("  ok   \(what)")
        }
    }

    func finish() -> Int32 {
        let summary = failures.isEmpty
            ? "\n\(assertions) assertions, all passing\n"
            : "\n\(failures.count) of \(assertions) assertions failed\n"
        report(summary)
        return failures.isEmpty ? 0 : 1
    }

    private func report(_ line: String) {
        FileHandle.standardOutput.write(Data((line + "\n").utf8))
    }
}
