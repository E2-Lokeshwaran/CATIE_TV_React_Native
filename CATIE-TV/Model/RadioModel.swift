//
//  RadioModel.swift
//  CATIE-TV
//
//  Created by Admin on 03/07/19.
//  Copyright © 2019 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import CoreData
import Foundation

// MARK: - RadioModel

class RadioModel: NSObject {
    // MARK: Lifecycle

    deinit {
        DDLogDebug("RadioModel: deinit - cleaning up resources")

        // Cancel any running data task to prevent memory leaks
        if let task = radioDataTask {
            if task.state == .running {
                task.cancel()
                DDLogDebug("RadioModel: cancelled running radioDataTask")
            }
        }

        // Invalidate URLSession to break delegate retain cycle
        urlSession?.invalidateAndCancel()
        urlSession = nil

        // Clean up all resources
        reset()

        DDLogDebug("RadioModel: deinit - all resources cleaned up")
    }

    // MARK: Internal

    weak var mainViewdelegate: MainScreenDelegate?
    weak var tempMainViewDelegate: MainScreenDelegate?

    var radioData: Data!
    var radioDataTask: URLSessionDataTask?
    var urlSession: URLSession?
    var managedObjectContext: NSManagedObjectContext?
    var appDel: AppDelegate!
    var radio: Radio?

    func getRadioMetaData() {
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

            DDLogDebug("Radio : Get Radio Meta Data from server")

            let radioAPI = URL(string: API.networkAPI().radioFeedURL.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "")

            let request = URLRequest(url: radioAPI!)

            var canMakeNewRadioRequest = false
            if radioDataTask != nil {
                switch radioDataTask!.state {
                case .running:
                    DDLogDebug("Radio : radioDataTask state is running ")
                    canMakeNewRadioRequest = false

                case .suspended:
                    DDLogDebug("Radio : radioDataTask state is suspended ")
                    canMakeNewRadioRequest = true

                case .canceling:
                    DDLogDebug("Radio : radioDataTask state is canceling ")
                    canMakeNewRadioRequest = true

                case .completed:
                    DDLogDebug("Radio : radioDataTask state is completed ")
                    canMakeNewRadioRequest = true

                default:
                    DDLogDebug("Radio : radioDataTask state is default")
                    canMakeNewRadioRequest = true
                }
            } else {
                canMakeNewRadioRequest = true
            }

            if canMakeNewRadioRequest {
                radioDataTask = nil
                radioData = Data()

                DDLogDebug("Radio : Calling Radio API with url \(String(describing: radioAPI))")

                // Invalidate previous session to prevent accumulation
                urlSession?.invalidateAndCancel()
                urlSession = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)

                radioDataTask = urlSession?.dataTask(with: request)
                radioDataTask?.resume()
            } else {
                DDLogDebug("Radio : Already scheduled radio task is in-progress ignoring new coming task...")
            }
        } catch: { exception in
            DDLogDebug("Radio : Exception in getRadioMetaData - \(String(describing: exception))")
        }
    }

    func reset() {
        appDel = nil
        radio = nil
        tempMainViewDelegate = nil
        managedObjectContext = nil
        radioDataTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        radioData = Data()
    }
}

// MARK: URLSessionDelegate, URLSessionDataDelegate

extension RadioModel: URLSessionDelegate, URLSessionDataDelegate {
    func urlSession(_: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        SwiftTryCatch.try {
            completionHandler(
                URLSession.AuthChallengeDisposition.useCredential,
                URLCredential(trust:
                    challenge.protectionSpace.serverTrust!)
            )
            DDLogDebug("Radio : URLAuthentication Challenge")
        } catch: { exception in
            DDLogDebug("Radio : Exception in URLAuthenticationChallenge - \(String(describing: exception))")
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
                        managedObjectContext = appDel.persistentContainer.newBackgroundContext()
                    }
                } else {
                    managedObjectContext = appDel.persistentContainer.newBackgroundContext()
                }
            }

            DDLogDebug("Radio : MainViewDelegate - \(String(describing: mainViewdelegate))")

            let response = task.response as? HTTPURLResponse

            let safeDict = StatusCodeDict.shared
            safeDict.setObject(key: "statusCodeForRadio", value: response?.statusCode ?? 0)

            DDLogDebug("Radio : Response status - \(String(describing: response?.statusCode))")

            if error != nil {
                DDLogDebug("Radio : NSURLSession connection error at RadioModel \(String(describing: error?.localizedDescription))")
                reset()
                if tvStatus == 1 {
                    self.mainViewdelegate?.radioFeedFailureResponse(message: (error?.localizedDescription)!, isNetworkError: true)
                } else {
                    DDLogDebug("Radio : No room is registered")
                }

            } else {
                if tvStatus == 1 {
                    if OngoingAPICallDict.shared.getValue(key: "Radio") == false {
                        DDLogDebug("Radio : Process Radio Data")
                        OngoingAPICallDict.shared.setObject(key: "Radio", value: true)
                        processRadioResponseData()
                    } else {
                        DDLogDebug("Radio : Ongoing Radio process available")
                        PendingAPICallRequestDict.shared.setObject(key: "Radio", value: true)
                    }
                } else {
                    reset()
                    DDLogDebug("Radio : No room is registered so not saving radio response")
                    OngoingAPICallDict.shared.setObject(key: "Radio", value: false)
                }
            }
        } catch: { exception in
            DDLogDebug("Radio : Exception in didCompleteWithError - \(String(describing: exception))")
            reset()
        }
    }

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
        SwiftTryCatch.try {
            if !data.isEmpty {
                radioData.append(data)
                DDLogDebug("Radio : Received Data successfully")
            } else {
                DDLogDebug("Radio : Received empty value on didReceive data at RadioModel")
            }
        } catch: { exception in
            DDLogDebug("Radio : Exception in didReceive - \(String(describing: exception))")
        }
    }

    func processRadioResponseData() {
        SwiftTryCatch.try {
            if managedObjectContext == nil {
                DDLogDebug("Radio: Error at processRadioResponseData managedObjectContext is nil")
                if appDel == nil {
                    DispatchQueue.main.async { [weak self] in
                        guard let self else {
                            return
                        }

                        appDel = UIApplication.shared.delegate as? AppDelegate
                        managedObjectContext = appDel.persistentContainer.newBackgroundContext()
                    }
                } else {
                    managedObjectContext = appDel.persistentContainer.newBackgroundContext()
                }
            }

            if !radioData.isEmpty {
                let jsonData = String(decoding: radioData, as: UTF8.self)
                DDLogDebug("Radio : Data - \(jsonData)")
                do {
                    DDLogDebug("Radio : Parsing Json data from server")
                    let decoder = JSONDecoder()
                    let radioResponse = try decoder.decode(radioResponseModel.self, from: radioData)

                    DDLogDebug("Radio : Radio Json Data - \(radioResponse)")

                    if radioResponse.status == "success" {
                        DataHandler().deleteRecords("Radio", managedObjectContext)

                        managedObjectContext?.performAndWait {
                            radio = NSEntityDescription.insertNewObject(forEntityName: "Radio", into: managedObjectContext!) as? Radio
                            radio?.status = radioResponse.status
                            radio?.radioFeed = radioResponse.data.radioUrl
                            radio?.playingStatus = Int16(radioResponse.data.playingStatus)

                            do {
                                try managedObjectContext?.save()
                                DDLogDebug("Radio : Saved Radio response in coredata")
                            } catch {
                                DDLogDebug("Radio : Unable to save Radio response in coredata")
                            }
                            DDLogDebug("Radio : Radio Data - \(String(describing: radio))")
                        }

                        reset()
                        DDLogDebug("Radio : Radio response was successful")
                        self.mainViewdelegate?.radioFeedSuccessResponse()

                    } else {
                        reset()
                        DDLogDebug("Radio : Radio response was unsuccessful")
                        self.mainViewdelegate?.radioFeedFailureResponse(message: "Failure at readioResponse")
                    }
                } catch {
                    reset()
                    DDLogDebug("Radio : parsing error at urlsession of radioModel \(error)")
                    self.mainViewdelegate?.radioFeedFailureResponse(message: error.localizedDescription)
                }
            } else {
                reset()
                self.mainViewdelegate?.radioFeedFailureResponse(message: "Failure at readioResponse")
                DDLogDebug("Radio : Received empty value on didCompleteWithError data at RadioModel")
            }
        } catch: { exception in
            DDLogDebug("Radio : Exception in processRadioResponseData - \(String(describing: exception))")
        }
    }
}

// MARK: - radioResponseModel

struct radioResponseModel: Codable {
    var status: String
    var data: radioData
}

// MARK: - radioData

struct radioData: Codable {
    var radioUrl: String
    var playingStatus: Int
}
