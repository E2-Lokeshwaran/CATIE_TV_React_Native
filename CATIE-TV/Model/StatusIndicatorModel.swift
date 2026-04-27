//
//  StatusIndicatorModel.swift
//  CATIE-TV
//
//  Created by Admin on 02/05/19.
//  Copyright © 2019 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import CoreData
import Foundation

// MARK: - statusIndicatorModel

class statusIndicatorModel: NSObject {
    // MARK: Lifecycle

    deinit {
        DDLogDebug("statusIndicatorModel: deinit - cleaning up resources")

        // Cancel any running data task to prevent memory leaks
        if let task = statusDataTask {
            if task.state == .running {
                task.cancel()
                DDLogDebug("statusIndicatorModel: cancelled running statusDataTask")
            }
        }

        // Invalidate URLSession to break delegate retain cycle
        urlSession?.invalidateAndCancel()
        urlSession = nil

        // Clean up all resources
        reset()

        DDLogDebug("statusIndicatorModel: deinit - all resources cleaned up")
    }

    // MARK: Internal

    weak var mainViewDelegate: MainScreenDelegate?
    weak var tempMainViewDelegate: MainScreenDelegate?

    var statusIndicatorData: Data!
    var statusDataTask: URLSessionDataTask?
    var urlSession: URLSession?
    var managedObjectContext: NSManagedObjectContext?
    var appDel: AppDelegate?
    var statusIndicator: StatusIndicator?

    func getStatusIndicatorData() {
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

            tempMainViewDelegate = mainViewDelegate

            DDLogDebug("StatusIndicator : Get StatusIndicator Data from server")

            let statusAPI = URL(string: API.networkAPI().stausIndicatorURL.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "")

            let request = URLRequest(url: statusAPI!)

            var canMakeNewStatusRequest = false
            if statusDataTask != nil {
                switch statusDataTask!.state {
                case .running:
                    DDLogDebug("StatusIndicator : statusDataTask state is running ")
                    canMakeNewStatusRequest = false

                case .suspended:
                    DDLogDebug("StatusIndicator : statusDataTask state is suspended ")
                    canMakeNewStatusRequest = true

                case .canceling:
                    DDLogDebug("StatusIndicator : statusDataTask state is canceling ")
                    canMakeNewStatusRequest = true

                case .completed:
                    DDLogDebug("StatusIndicator : statusDataTask state is completed ")
                    canMakeNewStatusRequest = true

                default:
                    DDLogDebug("StatusIndicator : statusDataTask state is default ")
                    canMakeNewStatusRequest = true
                }
            } else {
                canMakeNewStatusRequest = true
            }

            if canMakeNewStatusRequest {
                statusDataTask = nil
                statusIndicatorData = Data()

                DDLogDebug("StatusIndicator : Calling status Indicator API with url \(String(describing: statusAPI))")

                // Invalidate previous session to prevent accumulation
                urlSession?.invalidateAndCancel()
                urlSession = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)

                statusDataTask = urlSession?.dataTask(with: request)
                statusDataTask?.resume()
            } else {
                DDLogDebug("StatusIndicator : Already scheduled status task is in-progress ignoring new coming task...")
            }
        } catch: { exception in
            DDLogDebug("StatusIndicator : Exception in getStatusIndicatorData - \(String(describing: exception))")
        }
    }

    func reset() {
        appDel = nil
        tempMainViewDelegate = nil
        statusIndicator = nil
        statusDataTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        statusIndicatorData = Data()
    }
}

// MARK: URLSessionDelegate, URLSessionDataDelegate

extension statusIndicatorModel: URLSessionDelegate, URLSessionDataDelegate {
    func urlSession(_: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        SwiftTryCatch.try {
            completionHandler(
                URLSession.AuthChallengeDisposition.useCredential,
                URLCredential(trust:
                    challenge.protectionSpace.serverTrust!)
            )
            DDLogDebug("StatusIndicator : URLAuthentication Challenge")
        } catch: { exception in
            DDLogDebug("StatusIndicator : Exception in URLAuthenticationChallenge - \(String(describing: exception))")
        }
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        SwiftTryCatch.try {
            if mainViewDelegate == nil {
                mainViewDelegate = tempMainViewDelegate
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

            DDLogDebug("StatusIndicator : MainViewDelegate - \(String(describing: mainViewDelegate))")

            let response = task.response as? HTTPURLResponse

            let safeDict = StatusCodeDict.shared
            safeDict.setObject(key: "statusCodeForStatusIndicator", value: response?.statusCode ?? 0)

            DDLogDebug("StatusIndicator : Response status - \(String(describing: response?.statusCode))")

            if error != nil {
                DDLogDebug("StatusIndicator : NSURLSession connection error at statusIndicatorModel \(String(describing: error?.localizedDescription))")
                reset()
                if tvStatus == 1 {
                    self.mainViewDelegate?.statusIndicatorFailureResponse(message: (error?.localizedDescription)!, isNetworkError: true)
                } else {
                    DDLogDebug("StatusIndicator : No room is registered")
                }

            } else {
                if tvStatus == 1 {
                    if OngoingAPICallDict.shared.getValue(key: "StatusIndicator") == false {
                        DDLogDebug("StatusIndicator : Process StatusIndicator Data")
                        OngoingAPICallDict.shared.setObject(key: "StatusIndicator", value: true)
                        processStatusIndicatorResponseData()
                    } else {
                        DDLogDebug("StatusIndicator : Ongoing StatusIndicator process available")
                        PendingAPICallRequestDict.shared.setObject(key: "StatusIndicator", value: true)
                    }
                } else {
                    DDLogDebug("StatusIndicator : No room is registered so not saving StatusIndicator response")
                    reset()
                    OngoingAPICallDict.shared.setObject(key: "StatusIndicator", value: false)
                }
            }
        } catch: { exception in
            DDLogDebug("StatusIndicator : Exception in didCompleteWithError - \(String(describing: exception))")
            reset()
        }
    }

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
        SwiftTryCatch.try {
            if !data.isEmpty {
                statusIndicatorData.append(data)
                DDLogDebug("StatusIndicator : Received Data Successfully")
            } else {
                DDLogDebug("StatusIndicator : Received empty value on didReceive data at StatusIndicatorModel")
            }
        } catch: { exception in
            DDLogDebug("StatusIndicator : Exception in didReceive - \(String(describing: exception))")
        }
    }

    func processStatusIndicatorResponseData() {
        SwiftTryCatch.try {
            if managedObjectContext == nil {
                DDLogDebug("StatusIndicator : Error in processStatusIndicatorResponseData managedObjectContext is nil")
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

            if !statusIndicatorData.isEmpty {
                let jsonData = String(decoding: statusIndicatorData, as: UTF8.self)
                DDLogDebug("StatusIndicator : Data - \(jsonData)")
                do {
                    DDLogDebug("StatusIndicator : Parsing Json data from Response")
                    let decoder = JSONDecoder()
                    let statusResponse = try decoder.decode(statusIndicatorResponseModel.self, from: statusIndicatorData)

                    DDLogDebug("StatusIndicator : StatusIndicator Json Data - \(statusResponse)")

                    if statusResponse.status == "success" {
                        DataHandler().deleteRecords("StatusIndicator", managedObjectContext)

                        if !statusResponse.data.isEmpty {
                            for i in 0 ..< statusResponse.data.count {
                                managedObjectContext?.performAndWait {
                                    statusIndicator = NSEntityDescription.insertNewObject(forEntityName: "StatusIndicator", into: managedObjectContext!) as? StatusIndicator
                                    statusIndicator?.status = statusResponse.status
                                    statusIndicator?.statusName = statusResponse.data[i].statusName ?? ""
                                    statusIndicator?.message = statusResponse.data[i].message ?? ""
                                    // We assign 2 to statusFlag for denoting that statusFlag related data is missing.
                                    statusIndicator?.statusFlag = Int16(statusResponse.data[i].statusFlag ?? 2)

                                    do {
                                        try managedObjectContext?.save()
                                        DDLogDebug("StatusIndicator : Saved StatusIndicator response in coredata")
                                    } catch {
                                        DDLogDebug("StatusIndicator : Unable to save StatusIndicator response in coredata")
                                    }
                                    DDLogDebug("StatusIndicator : StatusIndicator Data - \(String(describing: statusIndicator))")
                                }
                            }

                            reset()
                            DDLogDebug("StatusIndicator : Status Indicator fetching was successful")
                            self.mainViewDelegate?.statusIndicatorSuccessResponse()

                        } else {
                            reset()
                            DDLogDebug("StatusIndicator : Status Indicator data unavailable")
                            self.mainViewDelegate?.statusIndicatorFailureResponse(message: "No stauts indicator available!")
                        }
                    } else {
                        reset()
                        DDLogDebug("StatusIndicator : Status Indicator fetching was unsuccessful")
                        self.mainViewDelegate?.statusIndicatorFailureResponse(message: "Unable to fetch statusIndicator!")
                    }
                } catch {
                    reset()
                    DDLogDebug("StatusIndicator : parsing error at urlsession of statusIndicatorModel \(error)")
                    self.mainViewDelegate?.statusIndicatorFailureResponse(message: error.localizedDescription)
                }
            } else {
                reset()
                DDLogDebug("StatusIndicator : Received empty value on didCompleteWithError at StatusIndicatorModel")
                self.mainViewDelegate?.statusIndicatorFailureResponse(message: "No stauts indicator available!")
            }
        } catch: { exception in
            DDLogDebug("StatusIndicator : Exception in processStatusIndicatorResponseData - \(String(describing: exception))")
        }
    }
}

// MARK: - statusIndicatorResponseModel

struct statusIndicatorResponseModel: Codable {
    var status: String
    var data: [statusData]
}

// MARK: - statusData

struct statusData: Codable {
    var statusName: String?
    var statusFlag: Int?
    var message: String?
}
