import Foundation
import Testing
@testable import GridMove

@Test func commandLineActionParserAcceptsSupportedArguments() async throws {
    #expect(try CommandLineInvocation.parse(arguments: []) == nil)
    #expect(try CommandLineInvocation.parse(arguments: ["-help"]) == CommandLineInvocation(action: .help, targetWindowID: nil))
    #expect(try CommandLineInvocation.parse(arguments: ["--help"]) == CommandLineInvocation(action: .help, targetWindowID: nil))
    #expect(try CommandLineInvocation.parse(arguments: ["-next"]) == CommandLineInvocation(action: .cycleNext, targetWindowID: nil))
    #expect(try CommandLineInvocation.parse(arguments: ["-pre"]) == CommandLineInvocation(action: .cyclePrevious, targetWindowID: nil))
    #expect(try CommandLineInvocation.parse(arguments: ["-prev"]) == CommandLineInvocation(action: .cyclePrevious, targetWindowID: nil))
    #expect(try CommandLineInvocation.parse(arguments: ["-layout", "Center"]) == CommandLineInvocation(action: .applyLayout(identifier: "Center"), targetWindowID: nil))
    #expect(try CommandLineInvocation.parse(arguments: ["-layout", "Center", "-window-id", "123"]) == CommandLineInvocation(action: .applyLayout(identifier: "Center"), targetWindowID: 123))
    #expect(try CommandLineInvocation.parse(arguments: ["-psn_0_12345"]) == nil)
}

@Test func commandLineActionParserRejectsInvalidArguments() async throws {
    #expect(throws: CommandLineActionError.unknownArgument("-oops")) {
        try CommandLineInvocation.parse(arguments: ["-oops"])
    }
    #expect(throws: CommandLineActionError.missingLayoutIdentifier) {
        try CommandLineInvocation.parse(arguments: ["-layout"])
    }
    #expect(throws: CommandLineActionError.missingWindowIdentifier) {
        try CommandLineInvocation.parse(arguments: ["-next", "-window-id"])
    }
    #expect(throws: CommandLineActionError.invalidWindowIdentifier("oops")) {
        try CommandLineInvocation.parse(arguments: ["-next", "-window-id", "oops"])
    }
    #expect(throws: CommandLineActionError.unexpectedArguments(["extra"])) {
        try CommandLineInvocation.parse(arguments: ["-next", "extra"])
    }
}

@MainActor
@Test func commandLineRunnerResolvesLayoutByNameOrIdentifier() async throws {
    let runner = CommandLineRunner()
    let layouts = AppConfiguration.defaultValue.layouts

    #expect(try runner.resolveLayout(identifier: "layout-4", in: layouts).id == "layout-4")
    #expect(try runner.resolveLayout(identifier: "Center", in: layouts).id == "layout-4")
    #expect(try runner.resolveLayout(identifier: "fill all screen", in: layouts).id == "layout-10")
    #expect(throws: CommandLineLayoutResolutionError.unknownLayout("unknown")) {
        try runner.resolveLayout(identifier: "unknown", in: layouts)
    }
}

@MainActor
@Test func commandLineRunnerRejectsAmbiguousLayoutNames() async throws {
    let runner = CommandLineRunner()
    let layouts = [
        LayoutPreset(
            id: "layout-a",
            name: "Center",
            gridColumns: 12,
            gridRows: 6,
            windowSelection: GridSelection(x: 0, y: 0, w: 6, h: 6),
            triggerRegion: .screen(GridSelection(x: 0, y: 0, w: 2, h: 2)),
            includeInCycle: true
        ),
        LayoutPreset(
            id: "layout-b",
            name: "Center",
            gridColumns: 12,
            gridRows: 6,
            windowSelection: GridSelection(x: 6, y: 0, w: 6, h: 6),
            triggerRegion: .screen(GridSelection(x: 10, y: 0, w: 2, h: 2)),
            includeInCycle: true
        ),
    ]

    #expect(throws: CommandLineLayoutResolutionError.ambiguousLayoutName("Center", matches: layouts)) {
        try runner.resolveLayout(identifier: "Center", in: layouts)
    }
}

@MainActor
@Test func commandLineRunnerRejectsActionsWhenDisabled() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-cli-tests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var configuration = AppConfiguration.defaultValue
    configuration.general.isEnabled = false
    try store.save(configuration)

    let runner = CommandLineRunner(configurationStore: store)

    #expect(runner.run(invocation: CommandLineInvocation(action: .cycleNext, targetWindowID: nil)) == EXIT_FAILURE)
}
