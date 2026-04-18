import XCTest

final class ScreenshotTests: XCTestCase {

    private var saveDir = ""

    // MARK: - Helpers

    private func launchApp(skipPremium: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasSeenGuide", "YES", "-sosVisible", "YES", "-hasSeenSOSWarning", "YES"]
        if skipPremium {
            app.launchArguments.append("-UITEST_SKIP_PREMIUM")
        }
        app.launch()
        return app
    }

    private func save(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let url = URL(fileURLWithPath: saveDir).appendingPathComponent(name)
        try! FileManager.default.createDirectory(atPath: saveDir, withIntermediateDirectories: true)
        try! screenshot.pngRepresentation.write(to: url)
    }

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private func tapTab(_ label: String, in app: XCUIApplication) {
        let tabBarButton = app.tabBars.buttons[label]
        if tabBarButton.exists {
            tabBarButton.tap()
        } else {
            app.buttons[label].firstMatch.tap()
        }
    }

    /// 6画面を順番に撮影
    private func captureAllScreens(prefix: String) {
        // 1. ホーム画面
        var app = launchApp()
        sleep(3)
        save("\(prefix)_1_home.png")

        // 2. 元気タップ後（花びらアニメーション）
        let moodButtons = app.buttons.matching(identifier: "moodButton_good")
        if moodButtons.count > 0 {
            moodButtons.firstMatch.tap()
        } else {
            // accessibilityIdentifierがない場合、「元気」テキストを探す
            let genki = app.staticTexts["元気"]
            if genki.exists {
                genki.tap()
            }
        }
        sleep(1)
        save("\(prefix)_2_tapped.png")

        // 3. 履歴画面
        tapTab("履歴", in: app)
        sleep(1)
        save("\(prefix)_3_history.png")

        // 4. 連絡先画面
        tapTab("連絡先", in: app)
        sleep(1)
        save("\(prefix)_4_contacts.png")

        // 5. 設定画面
        tapTab("設定", in: app)
        sleep(1)
        save("\(prefix)_5_settings.png")

        // 6. 購入画面（PremiumView）
        app = launchApp(skipPremium: false)
        sleep(3)
        save("\(prefix)_6_premium.png")
    }

    // MARK: - iPhone

    func testIPhoneScreenshots() throws {
        try XCTSkipIf(isIPad, "iPhone only")
        saveDir = "/Users/sa-taki/Desktop/AppStoreScreenshots/iphone_67"
        captureAllScreens(prefix: "iphone")
    }

    // MARK: - iPad

    func testIPadScreenshots() throws {
        try XCTSkipIf(!isIPad, "iPad only")

        // 縦画面
        XCUIDevice.shared.orientation = .portrait
        sleep(1)
        saveDir = "/Users/sa-taki/Desktop/AppStoreScreenshots/ipad_13_portrait"
        captureAllScreens(prefix: "ipad_p")

        // 横画面
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        saveDir = "/Users/sa-taki/Desktop/AppStoreScreenshots/ipad_13_landscape"
        captureAllScreens(prefix: "ipad_l")

        XCUIDevice.shared.orientation = .portrait
    }
}
