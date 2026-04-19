import Testing
@testable import GridMove

struct UICopyTests {
    @Test func uiCopySupportsEnglishAndChineseLocalization() async throws {
        let supportedLocalizations = Set(UICopy.supportedLocalizationsForTesting.map { $0.lowercased() })
        #expect(supportedLocalizations.contains("en"))
        #expect(supportedLocalizations.contains("zh-hans"))

        #expect(
            UICopy.localizedStringForTesting(
                key: "settingsMenuTitle",
                defaultValue: "Settings...",
                preferredLanguages: ["en"]
            ) == "Settings..."
        )
        #expect(
            UICopy.localizedStringForTesting(
                key: "settingsMenuTitle",
                defaultValue: "Settings...",
                preferredLanguages: ["zh-Hans"]
            ) == "设置..."
        )
        #expect(
            UICopy.localizedStringForTesting(
                key: "enableMenuTitle",
                defaultValue: "Enable",
                preferredLanguages: ["zh-Hans"]
            ) == "启用"
        )
        #expect(
            UICopy.localizedStringForTesting(
                key: "settingsRemoveDraftConfirmationMessage",
                defaultValue: "This change stays in draft mode until you click Save.",
                preferredLanguages: ["en"]
            ) == "This change stays in draft until you click Save."
        )
        #expect(
            UICopy.localizedStringForTesting(
                key: "settingsRemoveDraftConfirmationMessage",
                defaultValue: "This change stays in draft mode until you click Save.",
                preferredLanguages: ["zh-Hans"]
            ) == "删除后，你需要点击“保存”才能生效。"
        )
        #expect(
            UICopy.localizedStringForTesting(
                key: "settingsRestoreSettingsConfirmationMessage",
                defaultValue: "This restores all settings to the built-in defaults.",
                preferredLanguages: ["en"]
            ) == "This restores all settings to the built-in defaults."
        )
        #expect(
            UICopy.localizedStringForTesting(
                key: "settingsRestoreSettingsConfirmationMessage",
                defaultValue: "This restores all settings to the built-in defaults.",
                preferredLanguages: ["zh-Hans"]
            ) == "这会把所有设置恢复为内置默认值。"
        )
    }
}
