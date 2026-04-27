//
//  ScrollMessageModel.swift
//  CATIE-TV
//
//  Created by Shrinath Sivasankaran on 06/05/21.
//  Copyright © 2021 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import CoreData
import Foundation
import UIKit

// MARK: - ScrollMessageModel

// This class used to display the Scrolling message for the CATIE TV

class ScrollMessageModel: NSObject {
    // MARK: Lifecycle

    deinit {
        DDLogDebug("ScrollMessageModel: deinit - cleaning up resources")

        // Cancel any running data task to prevent memory leaks
        if let task = scrollMessageDataTask {
            if task.state == .running {
                task.cancel()
                DDLogDebug("ScrollMessageModel: cancelled running scrollMessageDataTask")
            }
        }

        // Invalidate URLSession to break delegate retain cycle
        urlSession?.invalidateAndCancel()
        urlSession = nil

        // Clean up all resources
        reset()

        DDLogDebug("ScrollMessageModel: deinit - all resources cleaned up")
    }

    // MARK: Internal

    weak var mainViewdelegate: MainScreenDelegate?
    weak var tempMainViewDelegate: MainScreenDelegate?

    var scrollMessageData: Data!
    var scrollMessageDataTask: URLSessionDataTask?
    var urlSession: URLSession?

    var appDel: AppDelegate?
    var managedObjectContext: NSManagedObjectContext?
    var scrollMessage: ScrollMessage?

    func getScrollMessageData() {
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

            DDLogDebug("ScrollMessage : Get ScrollMessage Data from Server")

            let scrollMessageAPI = URL(string: API.networkAPI().scrollMessageURL.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "")

            let request = URLRequest(url: scrollMessageAPI!)

            var canMakeScrollMessageRequest = false
            if scrollMessageDataTask != nil {
                switch scrollMessageDataTask!.state {
                case .running:
                    DDLogDebug("ScrollMessage : scrollMessageDataTask state is running")
                    canMakeScrollMessageRequest = false

                case .suspended:
                    DDLogDebug("ScrollMessage : scrollMessageDataTask state is suspended")
                    canMakeScrollMessageRequest = true

                case .canceling:
                    DDLogDebug("ScrollMessage : scrollMessageDataTask state is canceling")
                    canMakeScrollMessageRequest = true

                case .completed:
                    DDLogDebug("ScrollMessage : scrollMessageDataTask state is completed")
                    canMakeScrollMessageRequest = true

                default:
                    DDLogDebug("ScrollMessage : scrollMessageDataTask state is default")
                    canMakeScrollMessageRequest = true
                }
            } else {
                canMakeScrollMessageRequest = true
            }

            if canMakeScrollMessageRequest {
                scrollMessageDataTask = nil
                scrollMessageData = Data()

                DDLogDebug("ScrollMessage : Calling Scroll message API with url \(String(describing: scrollMessageAPI))")

                // Invalidate previous session to prevent accumulation
                urlSession?.invalidateAndCancel()
                urlSession = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)

                scrollMessageDataTask = urlSession?.dataTask(with: request)
                scrollMessageDataTask?.resume()
            } else {
                DDLogDebug("ScrollMessage : Already scheduled Scroll message task is in-progress ignoring new coming task...")
            }
        } catch: { exception in
            DDLogDebug("ScrollMessage : Exception in getScrollMessageData - \(String(describing: exception))")
        }
    }

    func reset() {
        urlSession?.invalidateAndCancel()
        urlSession = nil
        appDel = nil
        scrollMessage = nil
        scrollMessageDataTask = nil
        managedObjectContext = nil
        tempMainViewDelegate = nil
        scrollMessageData = Data()
    }
}

// MARK: URLSessionDelegate, URLSessionDataDelegate

extension ScrollMessageModel: URLSessionDelegate, URLSessionDataDelegate {
    func urlSession(_: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        SwiftTryCatch.try {
            completionHandler(
                URLSession.AuthChallengeDisposition.useCredential,
                URLCredential(trust:
                    challenge.protectionSpace.serverTrust!)
            )
            DDLogDebug("ScrollMessage : URLAuthentication Challenge")
        } catch: { exception in
            DDLogDebug("ScrollMessage : Exception in URLAuthenticationChallenge - \(String(describing: exception))")
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

            DDLogDebug("ScrollMessage : MainViewDelegate - \(String(describing: mainViewdelegate))")

            let response = task.response as? HTTPURLResponse

            let safeDict = StatusCodeDict.shared
            safeDict.setObject(key: "statusCodeForScrollMessage", value: response?.statusCode ?? 0)

            DDLogDebug("ScrollMessage : Response status - \(String(describing: response?.statusCode))")

            if error != nil {
                DDLogDebug("ScrollMessage : NSURLSession connection error at Scrollmessage \(String(describing: error?.localizedDescription))")

                reset()
                if tvStatus == 1 {
                    self.mainViewdelegate?.scrollingMsgFailureResponse(message: (error?.localizedDescription)!, isNetworkError: true)
                } else {
                    DDLogDebug("ScrollMessage : No room is registered")
                }

            } else {
                if tvStatus == 1 {
                    if OngoingAPICallDict.shared.getValue(key: "ScrollMessage") == false {
                        DDLogDebug("ScrollMessage : Process ScrollMessage Data")
                        OngoingAPICallDict.shared.setObject(key: "ScrollMessage", value: true)
                        processScrollMessageResponseData()
                    } else {
                        DDLogDebug("ScrollMessage : Ongoing ScrollMessage process available")
                        PendingAPICallRequestDict.shared.setObject(key: "ScrollMessage", value: true)
                    }
                } else {
                    reset()
                    DDLogDebug("ScrollMessage : No room is registered so not saving ScrollMessage response")
                    OngoingAPICallDict.shared.setObject(key: "ScrollMessage", value: false)
                }
            }
        } catch: { exception in
            DDLogDebug("ScrollMessage : Exception in didCompleteWithError - \(String(describing: exception))")
            reset()
        }
    }

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
        SwiftTryCatch.try {
            if !data.isEmpty {
                scrollMessageData?.append(data)
                DDLogDebug("ScrollMessage : Received Data Successfully")
            } else {
                DDLogDebug("ScrollMessage : Received empty value on didReceive data at ScrollMessageModel")
            }
        } catch: { exception in
            DDLogDebug("ScrollMessage : Exception in didReceive - \(String(describing: exception))")
        }
    }

    func processScrollMessageResponseData() {
        SwiftTryCatch.try {
            if managedObjectContext == nil {
                DDLogDebug("ScrollMessage : Error in processScrollMessageResponseData managedObjectContext is nil")
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
            if !scrollMessageData.isEmpty {
                let jsonData = String(decoding: scrollMessageData, as: UTF8.self)
                DDLogDebug("ScrollMessage : Data - \(jsonData)")
                do {
                    DDLogDebug("ScrollMessage : Parsing Json Data from server")
                    let decoder = JSONDecoder()
                    let scrollMessageResponse = try decoder.decode(scrollMessageResponseModel.self, from: scrollMessageData)

                    DDLogDebug("ScrollMessage : ScrollMessage Json Data - \(scrollMessageResponse)")

                    if scrollMessageResponse.status == "success" {
                        if !scrollMessageResponse.data.isEmpty {
                            DataHandler().deleteRecords("ScrollMessage", managedObjectContext)

                            var messageList = ""

                            for i in 0 ..< (scrollMessageResponse.data.count) {
                                let singleMessage = scrollMessageResponse.data[i]

                                // For single message, show as is without modification
                                if scrollMessageResponse.data.count == 1 {
                                    let singleMessgeWithoutSpace = singleMessage.replacingOccurrences(of: "\n", with: "")
                                    messageList = singleMessgeWithoutSpace
                                } else {
                                    // For multiple messages, keep the message as is and add ".... " after each message
                                    let singleMessgeWithoutSpace = singleMessage.replacingOccurrences(of: "\n", with: "")
                                    messageList = messageList + singleMessgeWithoutSpace + ".... "
                                }

                                DDLogDebug("ScrollMessage : ScrollMessage - \(singleMessage)")
                                DDLogDebug("ScrollMessage : ScrollMessage data append : \(i + 1)")
                            }

                            DDLogDebug("ScrollMessage : Filtering scroll message from parsed data - \(messageList)")

                            managedObjectContext?.performAndWait {
                                scrollMessage = NSEntityDescription.insertNewObject(forEntityName: "ScrollMessage", into: managedObjectContext!) as? ScrollMessage
                                scrollMessage?.messageDescription = messageList

                                do {
                                    try managedObjectContext?.save()
                                    DDLogDebug("ScrollMessage : Saved ScrollMessage response in coredata")
                                } catch {
                                    DDLogDebug("ScrollMessage : Unable to save ScrollMessage response in coredata")
                                }
                                DDLogDebug("ScrollMessage : ScrollMessage Data - \(String(describing: scrollMessage))")
                            }

                            reset()
                            DDLogDebug("ScrollMessage : ScrollMessage response was successful")
                            self.mainViewdelegate?.scrollingMsgSuccessResponse()

                        } else {
                            DataHandler().deleteRecords("ScrollMessage", managedObjectContext)
                            reset()
                            DDLogDebug("ScrollMessage : ScrollMessage response data was empty")
                            self.mainViewdelegate?.scrollingMsgSuccessResponse()
                        }

                    } else {
                        reset()
                        DDLogDebug("ScrollMessage : ScrollMessage response was unsuccessful")
                        self.mainViewdelegate?.scrollingMsgFailureResponse(message: "Failure at scrollMessageResponse")
                    }
                } catch {
                    reset()
                    DDLogDebug("ScrollMessage : parsing error at urlsession of scrolling message model \(error)")
                    self.mainViewdelegate?.scrollingMsgFailureResponse(message: error.localizedDescription)
                }
            } else {
                reset()
                DDLogDebug("ScrollMessage : Received empty value on didCompleteWithError data at scrollMessageModel")
                self.mainViewdelegate?.scrollingMsgFailureResponse(message: "Failure at scrollMessageResponse")
            }
        } catch: { exception in
            DDLogDebug("ScrollMessage : Exception in processScrollMessageResponseData - \(String(describing: exception))")
        }
    }
}

// MARK: - scrollMessageResponseModel

struct scrollMessageResponseModel: Codable {
    var status: String
    var data: [String]
}
