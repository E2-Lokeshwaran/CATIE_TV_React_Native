//
//  ViewUpdateHandler.swift
//  CATIE-TV
//
//  Created by Karthick on 07/07/23.
//  Copyright © 2023 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import CoreData
import Foundation

class ViewUpdateHandler: NSObject {
    // MARK: Internal

    var mainViewdelegate: MainScreenDelegate?
    var managedObjectContext: NSManagedObjectContext?

    func updateUI() {
        DispatchQueue.global().async { [weak self] in
            guard let self else {
                return
            }

            DDLogDebug("ViewUpdateHandler - call for customHomePage")
            dataForCustomHomePage(callFromAPI: false)
        }
    }

    func getUIForModules() {
        DispatchQueue.global().async { [weak self] in
            guard let self else {
                return
            }

            DDLogDebug("ViewUpdateHandler - call for weather")
            mainViewdelegate?.weatherSuccessResponse()
            DDLogDebug("ViewUpdateHandler - call for scrollMessage")
            mainViewdelegate?.scrollingMsgSuccessResponse()

            // Only fetch status indicators for UI types that display them
            if shouldFetchData(for: .statusIndicators) {
                DDLogDebug("ViewUpdateHandler - call for statusIndicator")
                mainViewdelegate?.statusIndicatorSuccessResponse()
            } else {
                DDLogDebug("ViewUpdateHandler - skipping statusIndicator for current UI type")
            }

            // Only fetch radio for UI types that display radio
            if shouldFetchData(for: .radio) {
                DDLogDebug("ViewUpdateHandler - call for radio")
                mainViewdelegate?.radioFeedSuccessResponse()
            } else {
                DDLogDebug("ViewUpdateHandler - skipping radio for current UI type")
            }

            DDLogDebug("ViewUpdateHandler - call for siteLogo")
            mainViewdelegate?.siteLogoSuccessResponse()

            // Only fetch events for UI types that display them
            if shouldFetchData(for: .events) {
                DDLogDebug("ViewUpdateHandler - call for event")
                mainViewdelegate?.eventsSuccessResponse()
            } else {
                DDLogDebug("ViewUpdateHandler - skipping events for current UI type")
            }

            DDLogDebug("ViewUpdateHandler - call for carousal")
            mainViewdelegate?.carousalImagesSuccessResponse()
            DDLogDebug("ViewUpdateHandler - call for saraAlert")
            dataForSaraAlertSuccessResponse()
        }
    }

    func refreshSaraAlertModel() {
        dataForSaraAlertSuccessResponse()
    }

    func dataForCustomHomePage(callFromAPI: Bool) {
        let fetchedData = DataHandler().fetchData("CustomHomePage", managedObjectContext)

        var customHomePageData: [CustomHomePage] = []

        if fetchedData?.count ?? 0 > 0 {
            for i in fetchedData! {
                guard let data = i as? CustomHomePage else {
                    return
                }

                customHomePageData.append(data)
            }
        }

        mainViewdelegate?.customHomePageSuccessResponse(customHomePageData)

        DDLogDebug("ViewUpdateHandler - get data for UI updation")

        if !callFromAPI {
            if !customHomePageData.isEmpty {
                let data = customHomePageData[0]
                managedObjectContext?.performAndWait {
                    if data.tvStatus == 1 {
                        getUIForModules()
                    }
                }
            }
        }
    }

    func dataForSaraAlertSuccessResponse() {
        let fetchedSaraAlertData = DataHandler().fetchData("SaraAlert", managedObjectContext)
        let fetchedSaraAlertHeader = DataHandler().fetchData("SaraHeader", managedObjectContext)
        let fetchedSaraAlertFooter = DataHandler().fetchData("SaraFooter", managedObjectContext)
        let fetchedSaraAlertBody = DataHandler().fetchData("SaraBody", managedObjectContext)
        let fetchedSaraAlertBodyText = DataHandler().fetchData("SaraBodyText", managedObjectContext)
        let fetchedSaraAlertBodyIndividual = DataHandler().fetchData("SaraBodyIndividual", managedObjectContext)

        var saraAlertData: [SaraAlert] = []
        var saraAlertHeader: [SaraHeader] = []
        var saraAlertFooter: [SaraFooter] = []
        var saraAlertBody: [SaraBody] = []
        var saraAlertBodyText: [SaraBodyText] = []
        var saraAlertBodyIndividual: [SaraBodyIndividual] = []

        if fetchedSaraAlertData?.count ?? 0 > 0 {
            for i in fetchedSaraAlertData! {
                guard let data = i as? SaraAlert else {
                    return
                }

                saraAlertData.append(data)
            }
        }
        if fetchedSaraAlertHeader?.count ?? 0 > 0 {
            for i in fetchedSaraAlertHeader! {
                guard let data = i as? SaraHeader else {
                    return
                }

                saraAlertHeader.append(data)
            }
        }
        if fetchedSaraAlertFooter?.count ?? 0 > 0 {
            for i in fetchedSaraAlertFooter! {
                guard let data = i as? SaraFooter else {
                    return
                }

                saraAlertFooter.append(data)
            }
        }
        if fetchedSaraAlertBody?.count ?? 0 > 0 {
            for i in fetchedSaraAlertBody! {
                guard let data = i as? SaraBody else {
                    return
                }

                saraAlertBody.append(data)
            }
        }
        if fetchedSaraAlertBodyText?.count ?? 0 > 0 {
            for i in fetchedSaraAlertBodyText! {
                guard let data = i as? SaraBodyText else {
                    return
                }

                saraAlertBodyText.append(data)
            }
        }
        if fetchedSaraAlertBodyIndividual?.count ?? 0 > 0 {
            for i in fetchedSaraAlertBodyIndividual! {
                guard let data = i as? SaraBodyIndividual else {
                    return
                }

                saraAlertBodyIndividual.append(data)
            }
        }
        mainViewdelegate?.saraAlertSuccessResponse(saraAlertData, saraAlertHeader, saraAlertFooter, saraAlertBody, saraAlertBodyText, saraAlertBodyIndividual)
    }

    // MARK: Private

    // MARK: - UI Type Data Fetching Logic

    /// Determines if data should be fetched using the common utility
    private func shouldFetchData(for dataType: DataFetchingUtility.DataType) -> Bool {
        DataFetchingUtility.shouldFetchData(
            for: dataType,
            mainVC: mainViewdelegate as? MainScreenViewController,
            context: "ViewUpdateHandler"
        )
    }
}
