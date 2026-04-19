import Testing
@testable import GridMove

@MainActor
@Test func aboutVersionFormattingUsesCompactReleasePattern() async throws {
    #expect(
        AboutSettingsViewController.formattedVersionString(
            displayVersion: "1.2.2(ab123)",
            shortVersion: "1.2.2",
            buildVersion: "168"
        ) == "1.2.2(ab123)"
    )
}

@MainActor
@Test func aboutVersionFormattingFallsBackWhenOneSideIsMissing() async throws {
    #expect(
        AboutSettingsViewController.formattedVersionString(
            displayVersion: nil,
            shortVersion: "1.2.2",
            buildVersion: nil
        ) == "1.2.2"
    )
    #expect(
        AboutSettingsViewController.formattedVersionString(
            displayVersion: nil,
            shortVersion: nil,
            buildVersion: "168"
        ) == "168"
    )
    #expect(
        AboutSettingsViewController.formattedVersionString(
            displayVersion: nil,
            shortVersion: nil,
            buildVersion: nil
        ) == "Development build"
    )
}

@MainActor
@Test func aboutVersionFormattingUsesReleaseDisplayVersionWithoutSuffix() async throws {
    #expect(
        AboutSettingsViewController.formattedVersionString(
            displayVersion: "1.2.3",
            shortVersion: "1.2.3",
            buildVersion: "168"
        ) == "1.2.3"
    )
}
