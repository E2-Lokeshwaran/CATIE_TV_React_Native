// Disabling isEmpty, it is interfering with XCTest syntax
// swiftformat:disable isEmpty

//
//  PortraitViewUITests.swift
//  CATIE-TVUITests
//
//  Created by Harish on 05/05/25.
//  Copyright © 2025 statusSolutions. All rights reserved.
//

@testable import CATIE_TV
import XCTest

final class PortraitViewUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        // Stop immediately when a failure occurs
        continueAfterFailure = false

        // Launch the app
        app.launch()

        // Wait for app to fully load
        let rootElements = app.otherElements.matching(identifier: "portraitViewRoot")
        let exists = rootElements.firstMatch.waitForExistence(timeout: 10.0)
        if !exists {
            // If we can't find any root elements, print the UI hierarchy to help debug
            print("DEBUG - UI HIERARCHY: \(app.debugDescription)")
            XCTFail("Could not find any portraitViewRoot elements - app may not have loaded properly")
        }
    }

    override func tearDownWithError() throws {
        // Clean up after each test
    }

    // MARK: - Helper Methods

    /// Takes a screenshot and attaches it to the test results
    func takeScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Basic UI Tests

    func testBasicUIElements() throws {
        takeScreenshot(name: "Initial-UI")

        // Check for various portaitViewRoot elements
        XCTAssertTrue(app.images.matching(identifier: "portraitViewRoot").count > 0,
                      "At least one image with portraitViewRoot identifier should exist")

        // Check for text elements
        XCTAssertTrue(app.staticTexts.matching(identifier: "portraitViewRoot").count > 0,
                      "At least one text element with portraitViewRoot identifier should exist")

        // Check for scrollView - from logs we can see this exists
        XCTAssertTrue(app.scrollViews.matching(identifier: "portraitViewRoot").count > 0,
                      "Scroll view with portraitViewRoot identifier should exist")
    }

    // MARK: - Performance Tests

    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
