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

    #expect(runner.resolveLayout(identifier: "layout-4", in: layouts)?.id == "layout-4")
    #expect(runner.resolveLayout(identifier: "Center", in: layouts)?.id == "layout-4")
    #expect(runner.resolveLayout(identifier: "fill all screen", in: layouts)?.id == "layout-10")
    #expect(runner.resolveLayout(identifier: "unknown", in: layouts) == nil)
}
