//
//  ClockModel.swift
//  CATIE-TV
//
//  Created by Karthick on 27/07/22.
//  Copyright © 2022 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import CoreData
import Foundation
import UIKit

// MARK: - ClockModel

class ClockModel: NSObject {
    // MARK: Lifecycle

    deinit {
        DDLogDebug("ClockModel: deinit - cleaning up resources")

        // Cancel any running data task to prevent memory leaks
        if let task = clockDataTask {
            if task.state == .running {
                task.cancel()
                DDLogDebug("ClockModel: cancelled running clockDataTask")
            }
        }

        // Invalidate URLSession to break delegate retain cycle
        urlSession?.invalidateAndCancel()
        urlSession = nil

        // Clean up all resources
        reset()

        DDLogDebug("ClockModel: deinit - all resources cleaned up")
    }

    // MARK: Internal

    weak var mainViewdelegate: MainScreenDelegate?
    weak var tempMainViewDelegate: MainScreenDelegate?

    var clockData: Data!
    var clockDataTask: URLSessionDataTask?
    var urlSession: URLSession?
    var managedObjectContext: NSManagedObjectContext?
    var appDel: AppDelegate?
    var clock: Clock?

    func getClockData() {
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

            DDLogDebug("ClockModel : Get Clock Details from the Server")

            let clockAPI = URL(string: API.networkAPI().clockURL.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "")

            let request = URLRequest(url: clockAPI!)
            var canMakeNewClockRequest = false

            if clockDataTask != nil {
                switch clockDataTask!.state {
                case .running:
                    DDLogDebug("ClockModel : clockDataTask state is running ")
                    canMakeNewClockRequest = false

                case .suspended:
                    DDLogDebug("ClockModel : clockDataTask state is suspended ")
                    canMakeNewClockRequest = true

                case .canceling:
                    DDLogDebug("ClockModel : clockDataTask state is canceling ")
                    canMakeNewClockRequest = true

                case .completed:
                    DDLogDebug("ClockModel : clockDataTask state is completed ")
                    canMakeNewClockRequest = true

                default:
                    DDLogDebug("ClockModel :clockDataTask state is default")
                    canMakeNewClockRequest = true
                }
            } else {
                canMakeNewClockRequest = true
            }

            if canMakeNewClockRequest {
                clockDataTask = nil
                clockData = Data()

                DDLogDebug("ClockModel : Calling Clock Model message API with url \(String(describing: clockAPI))")

                // Invalidate previous session to prevent accumulation
                urlSession?.invalidateAndCancel()
                urlSession = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)

                clockDataTask = urlSession?.dataTask(with: request)
                clockDataTask?.resume()

            } else {
                DDLogDebug("ClockModel : Already scheduled Clock Model data task is in-progress ignoring new coming task...")
            }
        } catch: { exception in
            DDLogDebug("ClockModel : Exception in getClockData - \(String(describing: exception))")
        }
    }

    func reset() {
        appDel = nil
        clock = nil
        clockDataTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        managedObjectContext = nil
        tempMainViewDelegate = nil
        clockData = Data()
    }
}

// MARK: URLSessionDelegate, URLSessionDataDelegate

extension ClockModel: URLSessionDelegate, URLSessionDataDelegate {
    func urlSession(_: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        SwiftTryCatch.try {
            completionHandler(
                URLSession.AuthChallengeDisposition.useCredential,
                URLCredential(trust:
                    challenge.protectionSpace.serverTrust!)
            )
            DDLogDebug("ClockModel : URLAuthentication Challenge")
        } catch: { exception in
            DDLogDebug("ClockModel : Exception in URLAuthenticationChallenge - \(String(describing: exception))")
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

            DDLogDebug("ClockModel : MainViewDelegate - \(String(describing: mainViewdelegate))")

            let response = task.response as? HTTPURLResponse

            let safeDict = StatusCodeDict.shared
            safeDict.setObject(key: "statusCodeForClock", value: response?.statusCode ?? 0)

            DDLogDebug("ClockModel : Response status - \(String(describing: response?.statusCode))")

            if error != nil {
                DDLogDebug("ClockModel : NSURLSession connection error at ClockModel \(String(describing: error?.localizedDescription))")
                reset()
                if tvStatus == 1 {
                    self.mainViewdelegate?.clockFailureResponse(message: (error?.localizedDescription)!, isNetworkError: true)
                } else {
                    DDLogDebug("ClockModel : No room is registered")
                }

            } else {
                if tvStatus == 1 {
                    if OngoingAPICallDict.shared.getValue(key: "Clock") == false {
                        DDLogDebug("ClockModel : Process Clock Data")
                        OngoingAPICallDict.shared.setObject(key: "Clock", value: true)
                        processClockResponseData()
                    } else {
                        DDLogDebug("ClockModel : Ongoing Clock process available")
                        PendingAPICallRequestDict.shared.setObject(key: "Clock", value: true)
                    }
                } else {
                    DDLogDebug("ClockModel : No room is registered so not saving Clock response")
                    reset()
                    self.mainViewdelegate?.clockFailureResponse(message: "No room is registered so not saving Clock response")
                }
            }

        } catch: { exception in
            DDLogDebug("ClockModel : Exception in didCompleteWithError - \(String(describing: exception))")
            reset()
        }
    }

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
        SwiftTryCatch.try {
            if !data.isEmpty {
//                let data1 = "{\"data\":[{\"statusId\":4,\"statusName\":\"Clock\",\"statusFlag\":1,\"statusSelectionFlag\":0,\"message\":\"D23 coming soon\",\"startTime\":\"01:47 PM\",\"endTime\":\"01:50 PM\",\"responseMessage\":null}],\"status\":\"success\"}".data(using: .utf8)!
                clockData.append(data)
                DDLogDebug("ClockModel : Received Data Successfully")
            } else {
                DDLogDebug("ClockModel : Received empty value on didReceive data at ClockModel")
            }
        } catch: { exception in
            DDLogDebug("ClockModel : Exception in didReceive - \(String(describing: exception))")
        }
    }

    func processClockResponseData() {
        SwiftTryCatch.try {
            if managedObjectContext == nil {
                DDLogDebug("Carousal: Error at processCarousalResponseData managedObjectContext is nil")
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
            if !clockData.isEmpty {
                let jsonData = String(decoding: clockData, as: UTF8.self)
                DDLogDebug("ClockModel : Data - \(jsonData)")
                do {
                    DDLogDebug("ClockModel : Parsing Json data from server")
                    let decoder = JSONDecoder()
                    let clockResponse = try decoder.decode(ClockResponseModel.self, from: clockData)

                    DDLogDebug("ClockModel : Clock Json Data - \(clockResponse)")

                    if clockResponse.status == "success" {
                        if !clockResponse.data.isEmpty {
                            DataHandler().deleteRecords("Clock", managedObjectContext)

                            managedObjectContext?.performAndWait {
                                clock = NSEntityDescription.insertNewObject(forEntityName: "Clock", into: managedObjectContext!) as? Clock
                                clock?.status = clockResponse.status
                                clock?.statusFlag = Int16(clockResponse.data[0].statusFlag)
                                clock?.message = clockResponse.data[0].message
                                clock?.startTime = clockResponse.data[0].startTime
                                clock?.endTime = clockResponse.data[0].endTime

                                do {
                                    try managedObjectContext?.save()
                                    DDLogDebug("ClockModel : Saved ClockModel response in coredata")
                                } catch {
                                    DDLogDebug("ClockModel : Unable to save ClockModel response in coredata")
                                }
                                DDLogDebug("ClockModel : Clock Data - \(String(describing: clock))")
                            }

                            reset()
                            DDLogDebug("ClockModel : Clock response was successful")
                            self.mainViewdelegate?.clockSuccessResponse()

                        } else {
                            DataHandler().deleteRecords("Clock", managedObjectContext)
                            reset()
                            DDLogDebug("ClockModel : Clock response data was empty")
                            self.mainViewdelegate?.clockSuccessResponse()
                        }

                    } else {
                        reset()
                        DDLogDebug("ClockModel : Clock response was unsuccessful")
                        self.mainViewdelegate?.clockFailureResponse(message: "No Clock details available")
                    }

                } catch {
                    reset()
                    DDLogDebug("ClockModel : Parsing error at urlsession of clock model \(error)")
                    self.mainViewdelegate?.clockFailureResponse(message: error.localizedDescription)
                }
            } else {
                reset()
                DDLogDebug("Carousal : Received empty value on didCompleteWithError  at ClockModel")
                self.mainViewdelegate?.clockFailureResponse(message: "No Clock details available")
            }
        } catch: { exception in
            DDLogDebug("clockModel : Exception in processClockResponseData - \(String(describing: exception))")
        }
    }
}

// MARK: - ClockResponseModel

struct ClockResponseModel: Codable {
    var status: String
    var data: [ClockData]
}

// MARK: - ClockData

struct ClockData: Codable {
    var statusFlag: Int
    var message: String
    var startTime: String
    var endTime: String
}
