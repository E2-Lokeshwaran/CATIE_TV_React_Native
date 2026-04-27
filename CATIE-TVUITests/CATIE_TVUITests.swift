//
//  CATIE_TVUITests.swift
//  CATIE-TVUITests
//
//  Created by Admin on 24/04/19.
//  Copyright © 2019 statusSolutions. All rights reserved.
//

@testable import CATIE_TV
import XCTest

class CATIE_TVUITests: XCTestCase {
    static var launchIfNeeded = false

    var app = XCUIApplication()

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.

        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        // if(!CATIE_TVUITests.launchIfNeeded){
        app.launch()
//            CATIE_TVUITests.launchIfNeeded = true
//        }

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    // MARK: -  Header Section

    func testTodayWeatherLocation() {
        let todayWeatherLocation = app.staticTexts["Today Weather Location"]
        XCTAssert(todayWeatherLocation.exists)
        XCTAssertNotNil(todayWeatherLocation.label)
    }

    func testTodayWeatherIcon() {
        let todayWeatherIcon = app.images["Today Weather Icon"]
        XCTAssert(todayWeatherIcon.exists)
        XCTAssertNotNil(todayWeatherIcon.images)
    }

    func testTodayWeatherTemp() {
        let todayWeatherTemp = app.staticTexts["Today Weathertemp"]
        XCTAssert(todayWeatherTemp.exists)
        XCTAssertNotNil(todayWeatherTemp.label)
    }

    func testNetworkDown() {
        let networkDown = app.staticTexts["Network Down Indication"]
        XCTAssert(networkDown.exists)
        XCTAssertNotNil(networkDown.label)
    }

    func testStatusSolutionIcon() {
        let statusSolutionIcon = app.images["StatusSolutionIcon"]
        XCTAssert(statusSolutionIcon.exists)
        XCTAssertNotNil(statusSolutionIcon.images)
    }

    func testTodayDate() {
        let todayDate = app.staticTexts["Today Date"]
        XCTAssert(todayDate.exists)
        XCTAssertNotNil(todayDate.label)
    }

    func testTodayTime() {
        let todayTime = app.staticTexts["Today Time"]
        XCTAssert(todayTime.exists)
        XCTAssertNotNil(todayTime.label)
    }

    func testHeaderSiteLogo() {
        let headerSiteLogo = app.images["Header Site Logo"]
        XCTAssert(headerSiteLogo.exists)
        XCTAssertNotNil(headerSiteLogo.images)
    }

    // MARK: - Center Content View

    func testCarousalView() {
        let carousalView = app.images["Carousal View"]
        XCTAssert(carousalView.exists)
        XCTAssertNotNil(carousalView.images)
    }

    func testFourDayWeatherTable() {
        let fourDayWeatherTable = app.tables["FourDay Weather Table"]
        let forecastWeather = app.staticTexts["Forecast Weather"]
        XCTAssert(forecastWeather.exists)
        XCTAssert(fourDayWeatherTable.exists)
        XCTAssertEqual(forecastWeather.label, "Forecast Weather")
        XCTAssertEqual(fourDayWeatherTable.cells.count, 4)
    }

    func testFourDayWeatherTableCell() {
        let fourDayWeatherTable = app.tables["FourDay Weather Table"]

        for i in 0 ..< fourDayWeatherTable.cells.count {
            let cell = fourDayWeatherTable.cells["FourDayWeatherTableCell-\(i)"]
            XCTAssert(cell.exists)
            let fourDayWeatherDay = cell.staticTexts["Four Day Weather Day"]
            let fourDayWeatherIcon = cell.images["Four Day Weather Icon"]
            let fourDayWeatherTemp = cell.staticTexts["Four Day Weather Temp"]
            let fourDayWeatherDesc = cell.staticTexts["Four Day Weather Desc"]

            XCTAssert(fourDayWeatherDay.exists)
            XCTAssert(fourDayWeatherIcon.exists)
            XCTAssert(fourDayWeatherTemp.exists)
            XCTAssert(fourDayWeatherDesc.exists)

            XCTAssertNotNil(fourDayWeatherDay.label)
            XCTAssertNotNil(fourDayWeatherIcon.images)
            XCTAssertNotNil(fourDayWeatherTemp.label)
            XCTAssertNotNil(fourDayWeatherDesc.label)
        }
    }

    func testDetailedWeatherTable() {
        let detailedWeatherTable = app.tables["Detailed Weather Table"]
        let detailedWeather = app.staticTexts["Detailed Weather"]
        XCTAssert(detailedWeatherTable.exists)
        XCTAssert(detailedWeather.exists)
        XCTAssertEqual(detailedWeather.label, "Detailed Weather")
        XCTAssertEqual(detailedWeatherTable.cells.count, 8)
    }

    func testDetailedWeatherTableCell() {
        let detailedWeatherTable = app.tables["Detailed Weather Table"]

        for i in 0 ..< detailedWeatherTable.cells.count {
            let cell = detailedWeatherTable.cells["Detailed Weather Table-\(i)"]
            XCTAssert(cell.exists)
            let detailedWeatherTemp = cell.staticTexts["Detailed Weaether Temp"]
            let detailedWeatherDesc = cell.staticTexts["Detailed Weather Desc"]

            XCTAssert(detailedWeatherTemp.exists)
            XCTAssert(detailedWeatherDesc.exists)

            XCTAssertNotNil(detailedWeatherTemp.label)

            XCTAssertNotNil(detailedWeatherDesc.label)
        }
    }

    func testStatusIndicatior() {
        let statusIndicatior = app.staticTexts["Status Indicatior"]
        let statusIndicatorCollectionView = app.collectionViews["Status Indicator Collection"]
        XCTAssert(statusIndicatior.exists)
        XCTAssert(statusIndicatorCollectionView.exists)
        XCTAssertEqual(statusIndicatior.label, "Status Indicator")
        XCTAssertNotEqual(statusIndicatorCollectionView.cells.count, 0)
    }

    func testStatusIndicatorDetails() {
        let statusIndicatorCollectionView = app.collectionViews["Status Indicator Collection"]

        for i in 0 ..< statusIndicatorCollectionView.cells.count {
            let cell = statusIndicatorCollectionView.cells["Status Indicator Collection - \(i)"]
            XCTAssert(cell.exists)

            let statusTitle = cell.staticTexts["Status Title"]
            let statusIcon = cell.images["Status Icon"]
            let statusDescription = cell.staticTexts["Status Description"]

            XCTAssert(statusTitle.exists)
            XCTAssert(statusIcon.exists)
            XCTAssert(statusDescription.exists)

            XCTAssertNotNil(statusTitle.label)
            XCTAssertNotNil(statusIcon.images)
            XCTAssertNotNil(statusDescription.label)
        }
    }

    func testCustomHomePage() {
        let labelForTime = app.staticTexts["Label For Time"]
        let labelForDateAndDay = app.staticTexts["Label For Date and Day"]

        XCTAssert(labelForTime.exists)
        XCTAssert(labelForDateAndDay.exists)

        XCTAssertNotNil(labelForTime.label)
        XCTAssertNotNil(labelForDateAndDay.label)
    }

    func testEventTable() {
        let eventListTable = app.tables["Event List Table"]
        let activities = app.staticTexts["Activities"]
        XCTAssert(activities.exists)
        XCTAssert(eventListTable.exists)
        XCTAssertEqual(activities.label, "Activities")
        XCTAssertNotEqual(eventListTable.cells.count, 0)
    }

    func testSingleCalendarEventCell() {
        let eventListTable = app.tables["Event List Table"]

        for i in 0 ..< eventListTable.cells.count {
            let cell = eventListTable.cells["SingleCalendarEventCell - \(i)"]

            XCTAssert(cell.exists)

            let eventName = cell.staticTexts["Event Name"]
            let eventDescription = cell.staticTexts["Event Description"]
            let eventStartTime = cell.staticTexts["Event Start Time"]

            XCTAssert(eventName.exists)
            XCTAssert(eventDescription.exists)
            XCTAssert(eventStartTime.exists)

            XCTAssertNotNil(eventName.label)
            XCTAssertNotNil(eventDescription.label)
            XCTAssertNotNil(eventStartTime.label)
        }
    }

    func testMultipleCalendarEventCell() {
        let eventListTable = app.tables["Event List Table"]

        for i in 0 ..< eventListTable.cells.count {
            let cell = eventListTable.cells["MultipleCalendarEventCell - \(i)"]

            XCTAssert(cell.exists)

            let eventName = cell.staticTexts["Event Name m"]
            let eventDescription = cell.staticTexts["Event Description"]
            let eventStartTime = cell.staticTexts["Event Start Time"]
            let eventCalendar = cell.staticTexts["Event Calendar"]

            XCTAssert(eventName.exists)
            XCTAssert(eventDescription.exists)
            XCTAssert(eventStartTime.exists)
            XCTAssert(eventCalendar.exists)

            XCTAssertNil(eventName.label)
            XCTAssertNil(eventDescription.label)
            XCTAssertNil(eventStartTime.label)
            XCTAssertNil(eventCalendar.label)
        }
    }

    func testScrollableText() {
        let scrollableText = app.scrollViews["Scrollable Text"]

        XCTAssert(scrollableText.exists)

        XCTAssertNotNil(scrollableText.scrollViews)
    }

    func testRadioPlayingIcon() {
        let radioPlayingIcon = app.images["Radio Playing Icon"]

        XCTAssert(radioPlayingIcon.exists)
        XCTAssertNotNil(radioPlayingIcon.images)
    }

    func testClockSection() {
        let labelForMessage = app.staticTexts["Label for Message"]
        let clockView = app.staticTexts["Clock View"]
        XCTAssert(labelForMessage.exists)
        XCTAssert(clockView.exists)
        XCTAssertNotNil(clockView.textViews)
        XCTAssertNotNil(labelForMessage.label)
    }

    func testSaraAlertHeaderView() {
        let saraAlertHeaderView = app.staticTexts["Sara Alert Header View"]
        XCTAssert(saraAlertHeaderView.exists)
    }

    func testSaraAlertBodyView() {
        let saraAlertBodyView = app.staticTexts["Sara Alert Body View"]
        XCTAssert(saraAlertBodyView.exists)
    }

    func testSaraAlertFooterView() {
        let saraAlertFooterView = app.staticTexts["Sara Alert Footer View"]
        XCTAssert(saraAlertFooterView.exists)
    }
}
