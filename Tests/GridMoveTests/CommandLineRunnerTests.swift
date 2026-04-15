import Testing
@testable import GridMove

@Test func commandLineActionParserAcceptsSupportedArguments() async throws {
    #expect(try CommandLineAction.parse(arguments: []) == nil)
    #expect(try CommandLineAction.parse(arguments: ["-help"]) == .help)
    #expect(try CommandLineAction.parse(arguments: ["--help"]) == .help)
    #expect(try CommandLineAction.parse(arguments: ["-next"]) == .cycleNext)
    #expect(try CommandLineAction.parse(arguments: ["-pre"]) == .cyclePrevious)
    #expect(try CommandLineAction.parse(arguments: ["-prev"]) == .cyclePrevious)
    #expect(try CommandLineAction.parse(arguments: ["-layout", "Center"]) == .applyLayout(identifier: "Center"))
    #expect(try CommandLineAction.parse(arguments: ["-psn_0_12345"]) == nil)
}

@Test func commandLineActionParserRejectsInvalidArguments() async throws {
    #expect(throws: CommandLineActionError.unknownArgument("-oops")) {
        try CommandLineAction.parse(arguments: ["-oops"])
    }
    #expect(throws: CommandLineActionError.missingLayoutIdentifier) {
        try CommandLineAction.parse(arguments: ["-layout"])
    }
    #expect(throws: CommandLineActionError.unexpectedArguments(["extra"])) {
        try CommandLineAction.parse(arguments: ["-next", "extra"])
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
