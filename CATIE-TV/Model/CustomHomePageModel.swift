//
//  CustomHomePageModel.swift
//  CATIE-TV
//
//  Created by Karthick on 27/07/22.
//  Copyright © 2022 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import CoreData
import Foundation
import UIKit

// MARK: - CustomHomePageModel

class CustomHomePageModel: NSObject {
    // MARK: Lifecycle

    deinit {
        DDLogDebug("CustomHomePageModel: deinit - cleaning up resources")

        // Cancel any running data task to prevent memory leaks
        if let task = CustomHomePageDataTask {
            if task.state == .running {
                task.cancel()
                DDLogDebug("CustomHomePageModel: cancelled running CustomHomePageDataTask")
            }
        }

        // Invalidate URLSession to break delegate retain cycle
        urlSession?.invalidateAndCancel()
        urlSession = nil

        // Clean up all resources
        reset()

        DDLogDebug("CustomHomePageModel: deinit - all resources cleaned up")
    }

    // MARK: Internal

    weak var mainViewdelegate: MainScreenDelegate?
    weak var tempMainViewDelegate: MainScreenDelegate?

    var CustomHomePageData: Data!
    var CustomHomePageDataTask: URLSessionDataTask?
    var urlSession: URLSession?
    var managedObjectContext: NSManagedObjectContext?
    var appDel: AppDelegate?
    var customHomePage: CustomHomePage?

    func getCustomHomePageData() {
        SwiftTryCatch.try {
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                if appDel == nil {
                    appDel = UIApplication.shared.delegate as? AppDelegate
                }

                managedObjectContext = appDel?.persistentContainer.newBackgroundContext()
            }

            tempMainViewDelegate = mainViewdelegate

            DDLogDebug("CustomHomePageModel : Get Custom HomePage Details from the Server")

            let CustomHomePageAPI = URL(string: API.networkAPI().customHomePageURL.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "")

            let request = URLRequest(url: CustomHomePageAPI!)
            var canMakeNewClockRequest = false

            if CustomHomePageDataTask != nil {
                switch CustomHomePageDataTask!.state {
                case .running:
                    DDLogDebug("CustomHomePageModel : CustomHomePageDataTask state is running ")
                    canMakeNewClockRequest = false

                case .suspended:
                    DDLogDebug("CustomHomePageModel : CustomHomePageDataTask state is suspended ")
                    canMakeNewClockRequest = true

                case .canceling:
                    DDLogDebug("CustomHomePageModel : CustomHomePageDataTask state is canceling ")
                    canMakeNewClockRequest = true

                case .completed:
                    DDLogDebug("CustomHomePageModel : CustomHomePageDataTask state is completed ")
                    canMakeNewClockRequest = true

                default:
                    DDLogDebug("CustomHomePageModel :CustomHomePageDataTask state is default")
                    canMakeNewClockRequest = true
                }
            } else {
                canMakeNewClockRequest = true
            }

            if canMakeNewClockRequest {
                CustomHomePageDataTask = nil
                CustomHomePageData = Data()

                DDLogDebug("CustomHomePageModel : Calling Custom HomePage message API with url \(String(describing: CustomHomePageAPI))")

                // Invalidate previous session to prevent accumulation
                urlSession?.invalidateAndCancel()
                urlSession = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)

                CustomHomePageDataTask = urlSession?.dataTask(with: request)
                CustomHomePageDataTask?.resume()

            } else {
                DDLogDebug("CustomHomePageModel : Already scheduled Custom HomePage data task is in-progress ignoring new coming task...")
            }
        } catch: { exception in
            DDLogDebug("CustomHomePageModel : Exception in getCustomHomePageData - \(String(describing: exception))")
        }
    }

    func reset() {
        urlSession?.invalidateAndCancel()
        urlSession = nil
        appDel = nil
        customHomePage = nil
        CustomHomePageDataTask = nil
        managedObjectContext = nil
        tempMainViewDelegate = nil
        CustomHomePageData = Data()
    }
}

// MARK: URLSessionDelegate, URLSessionDataDelegate

extension CustomHomePageModel: URLSessionDelegate, URLSessionDataDelegate {
    func urlSession(_: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        SwiftTryCatch.try {
            completionHandler(
                URLSession.AuthChallengeDisposition.useCredential,
                URLCredential(trust:
                    challenge.protectionSpace.serverTrust!)
            )
            DDLogDebug("CustomHomePageModel : URLAuthentication Challenge")
        } catch: { exception in
            DDLogDebug("CustomHomePageModel : Exception in URLAuthenticationChallenge - \(String(describing: exception))")
        }
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        SwiftTryCatch.try {
            if mainViewdelegate == nil {
                mainViewdelegate = tempMainViewDelegate
            }

            if managedObjectContext == nil {
                if appDel == nil {
                    DispatchQueue.main.async { [weak self] in
                        guard let self else {
                            return
                        }

                        appDel = UIApplication.shared.delegate as? AppDelegate
                        managedObjectContext = appDel?.persistentContainer.newBackgroundContext()
                    }
                } else {
                    managedObjectContext = appDel?.persistentContainer.newBackgroundContext()
                }
            }
            DDLogDebug("CustomHomePageModel : MainViewDelegate - \(String(describing: mainViewdelegate))")

            let response = task.response as? HTTPURLResponse

            let safeDict = StatusCodeDict.shared
            safeDict.setObject(key: "statusCodeForCustomHomePage", value: response?.statusCode ?? 0)

            DDLogDebug("CustomHomePageModel : Response status - \(String(describing: response?.statusCode))")

            if error != nil {
                DDLogDebug("CustomHomePageModel : NSURLSession connection error at ClockModel \(String(describing: error?.localizedDescription))")
                reset()
                if tvStatus == 1 {
                    self.mainViewdelegate?.customHomePageFailureResponse(message: (error?.localizedDescription)!, isNetworkError: true)
                } else {
                    DDLogDebug("CustomHomePageModel : No room is registered")
                }

            } else {
                if tvStatus == 1 {
                    if OngoingAPICallDict.shared.getValue(key: "CustomPage") == false {
                        DDLogDebug("CustomHomePageModel : Process CustomPage Data")
                        OngoingAPICallDict.shared.setObject(key: "CustomPage", value: true)
                        processCustomHomePageResponseData()
                    } else {
                        DDLogDebug("CustomHomePageModel : Ongoing CustomPage process available")
                        PendingAPICallRequestDict.shared.setObject(key: "CustomPage", value: true)
                    }
                } else {
                    DDLogDebug("CustomHomePageModel : No room is registered so not saving customHomePage response")
                    OngoingAPICallDict.shared.setObject(key: "CustomPage", value: false)
                    reset()
                    self.mainViewdelegate?.customHomePageFailureResponse(message: "No CustomHomePage details available")
                }
            }

        } catch: { exception in
            DDLogDebug("CustomHomePageModel : Exception in didCompleteWithError - \(String(describing: exception))")
            reset()
        }
    }

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
        SwiftTryCatch.try {
            if !data.isEmpty {
//                let data1 = "{\"data\":{\"catieTvFontColor\":\"#3773b3\",\"catieTvFontSize\":\"65\",\"catieTvType\":2,\"catieTvFontType\":\"Arial Hebrew\"},\"status\":\"success\"}".data(using: .utf8)!
                CustomHomePageData.append(data)
                DDLogDebug("CustomHomePageModel : Received Data Successfully")
            } else {
                DDLogDebug("CustomHomePageModel : Received empty value on didReceive data at CustomHomePage")
            }
        } catch: { exception in
            DDLogDebug("CustomHomePageModel : Exception in didReceive - \(String(describing: exception))")
        }
    }

    func processCustomHomePageResponseData() {
        SwiftTryCatch.try {
            if managedObjectContext == nil {
                DDLogDebug("CustomHomePageModel: Error at processCustomHomePageResponseData managedObjectContext is nil")
                if appDel == nil {
                    DispatchQueue.main.async { [weak self] in
                        guard let self else {
                            return
                        }

                        appDel = UIApplication.shared.delegate as? AppDelegate
                        managedObjectContext = appDel?.persistentContainer.newBackgroundContext()
                    }
                } else {
                    managedObjectContext = appDel?.persistentContainer.newBackgroundContext()
                }
            }
            if !CustomHomePageData.isEmpty {
                let jsonData = String(decoding: CustomHomePageData, as: UTF8.self)
                DDLogDebug("CustomHomePageModel : Data - \(jsonData)")
                do {
                    DDLogDebug("CustomHomePageModel : Parsing Json data from server")
                    let decoder = JSONDecoder()
                    let customHomePageResponse = try decoder.decode(customHomePageResponseModel.self, from: CustomHomePageData)

                    DDLogDebug("CustomHomePageModel : CustomHomePage Json Data - \(customHomePageResponse)")

                    if let data = customHomePageResponse.data, !data.isEmpty, customHomePageResponse.status == "success" {
                        tvStatus = customHomePageResponse.data?.tvStatus ?? 1

                        DataHandler().deleteRecords("CustomHomePage", managedObjectContext)

                        managedObjectContext?.performAndWait {
                            customHomePage = NSEntityDescription.insertNewObject(forEntityName: "CustomHomePage", into: managedObjectContext!) as? CustomHomePage

                            customHomePage?.status = customHomePageResponse.status
                            customHomePage?.catieTvType = Int16(customHomePageResponse.data?.catieTvType ?? 1)
                            customHomePage?.catieTvFontSize = customHomePageResponse.data?.catieTvFontSize ?? "50"
                            customHomePage?.catieTvFontType = customHomePageResponse.data?.catieTvFontType ?? "Avenir Next"
                            customHomePage?.catieTvFontColor = customHomePageResponse.data?.catieTvFontColor ?? "#3773b3"
                            customHomePage?.tvStatus = Int16(customHomePageResponse.data?.tvStatus ?? 1)
                            customHomePage?.tvRadioFlag = Int16(customHomePageResponse.data?.tvRadioFlag ?? 1)

                            do {
                                try managedObjectContext?.save()
                                DDLogDebug("CustomHomePageModel : Saved CustomHomePageModel response in coredata")
                            } catch {
                                DDLogDebug("CustomHomePageModel : Unable to save CustomHomePageModel response in coredata")
                            }
                            DDLogDebug("CustomHomePageModel : customHomePage Data - \(String(describing: customHomePage))")
                            DDLogDebug("CustomHomePageModel : CustomHomePageModel response was successful")
                        }

                        reset()
                        viewUpdateHandlerConnection.dataForCustomHomePage(callFromAPI: true)

                        // Sync data for all modules after the UI type has been updated
                        if callForDailyDataSync {
                            socketConnection.checkAndSyncDataForModule()
                            callForDailyDataSync = false
                        } else {
                            socketConnection.syncDataForAllModules()
                        }
                    } else {
                        reset()
                        DDLogDebug("CustomHomePageModel : CustomHomePageModel response was unsuccessful")
                        self.mainViewdelegate?.customHomePageFailureResponse(message: "No CustomHomePage details available")
                    }

                } catch {
                    reset()
                    DDLogDebug("CustomHomePageModel : Parsing error at url session of CustomHomePage model \(error)")
                    self.mainViewdelegate?.customHomePageFailureResponse(message: error.localizedDescription)
                }
            } else {
                reset()
                self.mainViewdelegate?.customHomePageFailureResponse(message: "No CustomHomePage details available")
                DDLogDebug("CustomHomePageModel : Received empty value on didCompleteWithError  at CustomHomePageModel")
            }
        } catch: { exception in
            DDLogDebug("CustomHomePageModel : Exception in processCustomHomePageResponseData - \(String(describing: exception))")
        }
    }
}

// MARK: - customHomePageResponseModel

// {
//  "data": {
//    "catieTvFontColor": "#3773b3",
//    "catieTvFontSize": "24",
//    "catieTvType": 1,
//    "catieTvFontType": "Arial Hebrew"
//  },
//  "status": "success"
// }

struct customHomePageResponseModel: Codable {
    var status: String
    var data: customHomePageUI?
}

// MARK: - customHomePageUI

struct customHomePageUI: Codable {
    var catieTvFontColor: String?
    var catieTvFontSize: String?
    var catieTvType: Int?
    var catieTvFontType: String?
    var tvStatus: Int?
    var tvRadioFlag: Int?

    /// Computed property to check if all properties are nil
    var isEmpty: Bool {
        catieTvFontColor == nil &&
            catieTvFontSize == nil &&
            catieTvType == nil &&
            catieTvFontType == nil &&
            tvStatus == nil &&
            tvRadioFlag == nil
    }
}
