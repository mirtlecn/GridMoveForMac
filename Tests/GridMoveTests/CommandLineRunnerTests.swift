import Foundation
import Testing
@testable import GridMove

private struct RemoteCommandRelayStub: RemoteCommandRelaying {
    var reply: RemoteCommandReply?
    var receivedCommands: Locked<[RemoteCommand]> = Locked([])

    func send(command: RemoteCommand, timeout: TimeInterval) -> RemoteCommandReply? {
        _ = timeout
        receivedCommands.withLock { commands in
            commands.append(command)
        }
        return reply
    }
}

private final class Locked<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withLock<T>(_ body: (inout Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

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
@Test func commandLineRunnerResolvesLayoutByGroupIndexOrName() async throws {
    let layouts = AppConfiguration.defaultValue.layouts

    #expect(try LayoutIdentifierResolver.resolveLayout(identifier: "4", in: layouts).id == "layout-4")
    #expect(try LayoutIdentifierResolver.resolveLayout(identifier: "Center", in: layouts).id == "layout-4")
    #expect(try LayoutIdentifierResolver.resolveLayout(identifier: "fill all screen", in: layouts).id == "layout-10")
    #expect(throws: CommandLineLayoutResolutionError.unknownLayout("unknown")) {
        try LayoutIdentifierResolver.resolveLayout(identifier: "unknown", in: layouts)
    }
    #expect(throws: CommandLineLayoutResolutionError.invalidLayoutIndex("12")) {
        try LayoutIdentifierResolver.resolveLayout(identifier: "12", in: layouts)
    }
    #expect(throws: CommandLineLayoutResolutionError.unknownLayout("layout-4")) {
        try LayoutIdentifierResolver.resolveLayout(identifier: "layout-4", in: layouts)
    }
}

@MainActor
@Test func commandLineRunnerRejectsAmbiguousLayoutNames() async throws {
    let layouts = [
        LayoutPreset(
            id: "layout-a",
            name: "Center",
            gridColumns: 12,
            gridRows: 6,
            windowSelection: GridSelection(x: 0, y: 0, w: 6, h: 6),
            triggerRegion: .screen(GridSelection(x: 0, y: 0, w: 2, h: 2)),
            includeInLayoutIndex: true
        ),
        LayoutPreset(
            id: "layout-b",
            name: "Center",
            gridColumns: 12,
            gridRows: 6,
            windowSelection: GridSelection(x: 6, y: 0, w: 6, h: 6),
            triggerRegion: .screen(GridSelection(x: 10, y: 0, w: 2, h: 2)),
            includeInLayoutIndex: true
        ),
    ]

    #expect(
        throws: CommandLineLayoutResolutionError.ambiguousLayoutName(
            "Center",
            matches: [
                LayoutNameMatch(name: "Center", layoutIndex: 1),
                LayoutNameMatch(name: "Center", layoutIndex: 2),
            ]
        )
    ) {
        try LayoutIdentifierResolver.resolveLayout(identifier: "Center", in: layouts)
    }
}

@MainActor
@Test func commandLineRunnerResolvesNumericIdentifierInsideActiveGroup() async throws {
    var configuration = AppConfiguration.defaultValue
    configuration.general.activeLayoutGroup = "fullscreen"

    #expect(try LayoutIdentifierResolver.resolveLayout(identifier: "1", in: configuration).layout.name == "Fullscreen main")
    #expect(try LayoutIdentifierResolver.resolveLayout(identifier: "4", in: configuration).layout.name == "Fullscreen other")
    #expect(throws: CommandLineLayoutResolutionError.invalidLayoutIndex("5")) {
        try LayoutIdentifierResolver.resolveLayout(identifier: "5", in: configuration)
    }
    #expect(throws: CommandLineLayoutResolutionError.unknownLayout("layout_4")) {
        try LayoutIdentifierResolver.resolveLayout(identifier: "layout_4", in: configuration)
    }
}

@MainActor
@Test func commandLineRunnerReportsDuplicateNamesWithGroupIndexes() async throws {
    var configuration = AppConfiguration.defaultValue
    configuration.general.activeLayoutGroup = "work"
    configuration.layoutGroups = [
        LayoutGroup(
            name: "work",
            sets: [
                LayoutSet(
                    monitor: .main,
                    layouts: [
                        LayoutPreset(
                            id: "layout-1",
                            name: "Center",
                            gridColumns: 12,
                            gridRows: 6,
                            windowSelection: GridSelection(x: 0, y: 0, w: 6, h: 6),
                            triggerRegion: .screen(GridSelection(x: 0, y: 0, w: 2, h: 2)),
                            includeInLayoutIndex: true
                        ),
                        LayoutPreset(
                            id: "layout-2",
                            name: "Center",
                            gridColumns: 12,
                            gridRows: 6,
                            windowSelection: GridSelection(x: 6, y: 0, w: 6, h: 6),
                            triggerRegion: nil,
                            includeInLayoutIndex: false
                        ),
                        LayoutPreset(
                            id: "layout-3",
                            name: "Center",
                            gridColumns: 12,
                            gridRows: 6,
                            windowSelection: GridSelection(x: 3, y: 1, w: 6, h: 4),
                            triggerRegion: .screen(GridSelection(x: 5, y: 2, w: 2, h: 2)),
                            includeInLayoutIndex: true
                        ),
                    ]
                )
            ]
        )
    ]

    #expect(throws: CommandLineLayoutResolutionError.ambiguousLayoutName(
        "Center",
        matches: [
            LayoutNameMatch(name: "Center", layoutIndex: 1),
            LayoutNameMatch(name: "Center", layoutIndex: nil),
            LayoutNameMatch(name: "Center", layoutIndex: 2),
        ]
    )) {
        try LayoutIdentifierResolver.resolveLayout(identifier: "Center", in: configuration)
    }

    let error = try #require(
        throws: CommandLineLayoutResolutionError.self,
        performing: {
            try LayoutIdentifierResolver.resolveLayout(identifier: "Center", in: configuration)
        }
    )
    #expect(error.message.contains("[index 1]"))
    #expect(error.message.contains("[index 2]"))
    #expect(error.message.contains("[no layout index]"))
}

@MainActor
@Test func commandLineRunnerFailsWhenAppIsNotRunning() async throws {
    let relay = RemoteCommandRelayStub(reply: nil)
    let runner = CommandLineRunner(commandRelay: relay)

    #expect(runner.run(invocation: CommandLineInvocation(action: .cycleNext, targetWindowID: nil)) == EXIT_FAILURE)
    #expect(relay.receivedCommands.withLock { $0.count } == 1)
}

@MainActor
@Test func commandLineRunnerSendsCommandToRunningApp() async throws {
    let relay = RemoteCommandRelayStub(reply: RemoteCommandReply(success: true, message: nil))
    let runner = CommandLineRunner(commandRelay: relay)

    #expect(runner.run(invocation: CommandLineInvocation(action: .cycleNext, targetWindowID: 42)) == EXIT_SUCCESS)
    let commands = relay.receivedCommands.withLock { $0 }
    #expect(commands.count == 1)
    #expect(commands.first?.action == .cycleNext)
    #expect(commands.first?.targetWindowID == 42)
}

@MainActor
@Test func commandLineRunnerSurfacesRemoteFailureMessage() async throws {
    let relay = RemoteCommandRelayStub(reply: RemoteCommandReply(success: false, message: "No focused target window found."))
    let runner = CommandLineRunner(commandRelay: relay)

    #expect(runner.run(invocation: CommandLineInvocation(action: .cycleNext, targetWindowID: nil)) == EXIT_FAILURE)
}
