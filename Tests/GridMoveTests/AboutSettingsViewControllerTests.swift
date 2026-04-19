import Testing
@testable import GridMove

@MainActor
@Test func aboutVersionFormattingUsesCompactReleasePattern() async throws {
    #expect(
        AboutSettingsViewController.formattedVersionString(
            shortVersion: "1.2.2",
            buildVersion: "168"
        ) == "1.2.2(168)"
    )
}

@MainActor
@Test func aboutVersionFormattingFallsBackWhenOneSideIsMissing() async throws {
    #expect(
        AboutSettingsViewController.formattedVersionString(
            shortVersion: "1.2.2",
            buildVersion: nil
        ) == "1.2.2"
    )
    #expect(
        AboutSettingsViewController.formattedVersionString(
            shortVersion: nil,
            buildVersion: "168"
        ) == "168"
    )
    #expect(
        AboutSettingsViewController.formattedVersionString(
            shortVersion: nil,
            buildVersion: nil
        ) == "Development build"
    )
}
