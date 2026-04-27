//
//  SaraAlertModel.swift
//  CATIE-TV
//
//  Created by E2info on 26/05/21.
//  Copyright © 2021 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import CoreData
import Foundation
import UIKit

// MARK: - SaraAlertModel

//// This calss used to display the SARA alert message for the CATIE TV
class SaraAlertModel: NSObject {
    // MARK: Lifecycle

    deinit {
        DDLogDebug("SaraAlertModel: deinit - cleaning up resources")

        // Cancel any running data task to prevent memory leaks
        if let task = saraAlertDataTask {
            if task.state == .running {
                task.cancel()
                DDLogDebug("SaraAlertModel: cancelled running saraAlertDataTask")
            }
        }

        // Invalidate URLSession to break delegate retain cycle
        urlSession?.invalidateAndCancel()
        urlSession = nil

        // Clean up all resources
        reset()

        DDLogDebug("SaraAlertModel: deinit - all resources cleaned up")
    }

    // MARK: Internal

    weak var mainViewdelegate: MainScreenDelegate?
    weak var tempMainViewDelegate: MainScreenDelegate?

    var saraAlertData: Data!
    var saraAlertDataTask: URLSessionDataTask?
    var urlSession: URLSession?

    var appDel: AppDelegate?
    var managedObjectContext: NSManagedObjectContext?

    var saraAlert: SaraAlert?
    var saraHeader: SaraHeader?
    var saraFooter: SaraFooter?
    var saraBody: SaraBody?
    var saraBodyText: SaraBodyText?
    var saraBodyIndividual: SaraBodyIndividual?

    /// This method downloades the SARA alert message from server and save it to the data base
    func getSaraAlertData() {
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

            DDLogDebug("SaraAlert : Get SARA Alert message from the Server")

            let saraAlertAPI = URL(string: API.networkAPI().saraAlertURL.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "")

            let request = URLRequest(url: saraAlertAPI!)
            var canMakeScrollMessageRequest = false

            if saraAlertDataTask != nil {
                switch saraAlertDataTask!.state {
                case .running:
                    DDLogDebug("SaraAlert : saraAlertDataTask state is running ")
                    canMakeScrollMessageRequest = false

                case .suspended:
                    DDLogDebug("SaraAlert : saraAlertDataTask state is suspended ")
                    canMakeScrollMessageRequest = true

                case .canceling:
                    DDLogDebug("SaraAlert : saraAlertDataTask state is canceling ")
                    canMakeScrollMessageRequest = true

                case .completed:
                    DDLogDebug("SaraAlert : saraAlertDataTask state is completed ")
                    canMakeScrollMessageRequest = true

                default:
                    DDLogDebug("SaraAlert :saraAlertDataTask state is default *")
                    canMakeScrollMessageRequest = true
                }
            } else {
                canMakeScrollMessageRequest = true
            }

            if canMakeScrollMessageRequest {
                saraAlertDataTask = nil
                saraAlertData = Data()

                DDLogDebug("SaraAlert : Calling SARA Alert message API with url \(String(describing: saraAlertAPI))")

                // Invalidate previous session to prevent accumulation
                urlSession?.invalidateAndCancel()
                urlSession = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)

                saraAlertDataTask = urlSession?.dataTask(with: request)
                saraAlertDataTask?.resume()

            } else {
                DDLogDebug("SaraAlert : Already scheduled Sara alert data task is in-progress ignoring new coming task...")
            }
        } catch: { exception in
            DDLogDebug("SaraAlert : Exception in getSaraAlertData - \(String(describing: exception))")
        }
    }

    func reset() {
        appDel = nil
        saraAlert = nil
        saraHeader = nil
        saraFooter = nil
        saraBody = nil
        saraBodyText = nil
        saraBodyIndividual = nil
        saraAlertDataTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        managedObjectContext = nil
        tempMainViewDelegate = nil
        saraAlertData = Data()
    }
}

// MARK: URLSessionDelegate, URLSessionDataDelegate

extension SaraAlertModel: URLSessionDelegate, URLSessionDataDelegate {
    func urlSession(_: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        SwiftTryCatch.try {
            completionHandler(
                URLSession.AuthChallengeDisposition.useCredential,
                URLCredential(trust:
                    challenge.protectionSpace.serverTrust!)
            )
            DDLogDebug("SaraAlert : URLAuthentication Challenge")
        } catch: { exception in
            DDLogDebug("SaraAlert : Exception in URLAuthenticationChallenge- \(String(describing: exception))")
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

            DDLogDebug("SaraAlert : MainViewDelegate - \(String(describing: mainViewdelegate))")

            let response = task.response as? HTTPURLResponse

            let safeDict = StatusCodeDict.shared
            safeDict.setObject(key: "statusCodeForSaraAlert", value: response?.statusCode ?? 0)

            DDLogDebug("SaraAlert : Response status - \(String(describing: response?.statusCode))")

            if error != nil {
                DDLogDebug("SaraAlert : NSURLSession connection error at Sata Alert \(String(describing: error?.localizedDescription))")

                reset()
                if tvStatus == 1 {
                    self.mainViewdelegate?.saraAlertFailureResponse(message: (error?.localizedDescription)!, isNetworkError: true)
                } else {
                    DDLogDebug("SaraAlert : No room is registered")
                }

            } else {
                if tvStatus == 1 {
                    if OngoingAPICallDict.shared.getValue(key: "SaraAlert") == false {
                        DDLogDebug("SaraAlert : Process SaraAlert Data")
                        OngoingAPICallDict.shared.setObject(key: "SaraAlert", value: true)
                        processSaraAlertResponseData()
                    } else {
                        DDLogDebug("SaraAlert : Ongoing SaraAlert process available")
                        PendingAPICallRequestDict.shared.setObject(key: "SaraAlert", value: true)
                    }
                } else {
                    reset()
                    DDLogDebug("SaraAlert : No room is registered so not saving SaraAlert response")
                    OngoingAPICallDict.shared.setObject(key: "SaraAlert", value: false)
                }
            }
        } catch: { exception in
            DDLogDebug("SaraAlert : Exception in didCompleteWithError - \(String(describing: exception))")
            reset()
        }
    }

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
        SwiftTryCatch.try {
            if !data.isEmpty {
                saraAlertData.append(data)
                DDLogDebug("SaraAlert : Received Data successfully")
            } else {
                DDLogDebug("SaraAlert : Received empty value on didReceive data at sara alert model")
            }
        } catch: { exception in
            DDLogDebug("SaraAlert : Exception in didReceive - \(String(describing: exception))")
        }
    }

    func processSaraAlertResponseData() {
        SwiftTryCatch.try {
            if managedObjectContext == nil {
                DDLogDebug("SaraAlert : Error in processSaraAlertResponseData managedObjectContext is nil")
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

            if !saraAlertData.isEmpty {
                let jsonData = String(decoding: saraAlertData, as: UTF8.self)
                DDLogDebug("SaraAlert : Data - \(jsonData)")
                do {
                    DDLogDebug("SaraAlert : Parsing Json Data from the Server")
                    let saraAlertResponse = try JSONSerialization.jsonObject(with: saraAlertData, options: JSONSerialization.ReadingOptions.mutableContainers) as! NSDictionary

                    DDLogDebug("SaraAlert : SaraAlert Json Data - \(saraAlertResponse)")

                    var audioPath = ""

                    if saraAlertResponse["status"] as! String == "success" {
                        var alertData = saraAlertResponse["data"] as? NSDictionary

                        if alertData?.count ?? 0 > 0 {
                            DDLogDebug("SaraAlert : The sara alert reponse data has parameters.......")
                            DataHandler().deleteRecords("SaraAlert", managedObjectContext)

                            managedObjectContext?.performAndWait {
                                saraAlert = NSEntityDescription.insertNewObject(forEntityName: "SaraAlert", into: managedObjectContext!) as? SaraAlert

                                // Alert Flash Option
                                DDLogDebug("SaraAlert : Flash available for Alerts")
                                saraAlert?.flash = Int16(alertData?["flash"] as? Int ?? 0)
                                saraAlert?.flashColor = alertData?["flashColor"] as? String ?? ""
                                // Downloading audio file from the url path

                                // Alert Audio Option
                                DDLogDebug("SaraAlert : Audio available for Alerts")
                                if alertData?["audio"] as? String != "" {
                                    audioPath = "https://\(domainAddress!)" + (alertData?["audio"] as! String)
                                } else {
                                    DDLogDebug("SaraAlert : No Audio feed received from the given url")
                                    saraAlert?.audio = Data() // Putting up empty data when there is no audio feed received from the given url
                                }

                                // Alert Messages
                                DDLogDebug("SaraAlert : Filtering Alert message from parsed data")
                                alertData = alertData?["messages"] as? NSDictionary

                                // Basic content syle
                                let styleArray = alertData?["style"] as? [String]

                                for i in 0 ..< (styleArray?.count ?? 0) {
                                    if styleArray?[i].contains("height") == true {
                                        saraAlert?.height = String(styleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if styleArray?[i].contains("width") == true {
                                        saraAlert?.width = String(styleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if styleArray?[i].contains("margin") == true {
                                        saraAlert?.margin = String(styleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if styleArray?[i].contains("text-align") == true {
                                        saraAlert?.textAlign = String(styleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if styleArray?[i].contains("border-color") == true {
                                        saraAlert?.borderColor = String(styleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if styleArray?[i].contains("font-size") == true {
                                        saraAlert?.fontSize = String(styleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if styleArray?[i].contains("font-weight") == true {
                                        saraAlert?.fontWeight = String(styleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if styleArray?[i].contains("background-color") == true {
                                        saraAlert?.backgroundColor = String(styleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if styleArray?[i].contains("border") == true {
                                        saraAlert?.border = String(styleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if styleArray?[i].contains("color") == true {
                                        saraAlert?.color = String(styleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if styleArray?[i].contains("font-style") == true {
                                        saraAlert?.fontStyle = String(styleArray?[i].split(separator: ":")[1] ?? "")
                                    }
                                }

                                do {
                                    try managedObjectContext?.save()
                                    DDLogDebug("SaraAlert : Saved SaraAlert response in coredata")
                                } catch {
                                    DDLogDebug("SaraAlert : Unable to save SaraAlert response in coredata")
                                }
                            }

                            // Header Configurations
                            DDLogDebug("SaraAlert : Filtering Header configuration from parsed data")
                            DataHandler().deleteRecords("SaraHeader", managedObjectContext)

                            managedObjectContext?.performAndWait {
                                saraHeader = NSEntityDescription.insertNewObject(forEntityName: "SaraHeader", into: managedObjectContext!) as? SaraHeader
                                let alertHeaderData = alertData?["header"] as? NSDictionary
                                saraHeader?.headerText = alertHeaderData?["text"] as? String

                                let alertHeaderStyleArray = alertHeaderData?["style"] as? [String]

                                for i in 0 ..< (alertHeaderStyleArray?.count ?? 0) {
                                    if alertHeaderStyleArray?[i].contains("height") == true {
                                        saraHeader?.height = String(alertHeaderStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if alertHeaderStyleArray?[i].contains("width") == true {
                                        saraHeader?.width = String(alertHeaderStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if alertHeaderStyleArray?[i].contains("margin") == true {
                                        saraHeader?.margin = String(alertHeaderStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if alertHeaderStyleArray?[i].contains("text-align") == true {
                                        saraHeader?.textAlign = String(alertHeaderStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if alertHeaderStyleArray?[i].contains("border-color") == true {
                                        saraHeader?.borderColor = String(alertHeaderStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if alertHeaderStyleArray?[i].contains("font-size") == true {
                                        saraHeader?.fontSize = String(alertHeaderStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if alertHeaderStyleArray?[i].contains("font-weight") == true {
                                        saraHeader?.fontWeight = String(alertHeaderStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if alertHeaderStyleArray?[i].contains("background-color") == true {
                                        saraHeader?.backgroundColor = String(alertHeaderStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if alertHeaderStyleArray?[i].contains("border") == true {
                                        saraHeader?.border = String(alertHeaderStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if alertHeaderStyleArray?[i].contains("color") == true {
                                        saraHeader?.color = String(alertHeaderStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if alertHeaderStyleArray?[i].contains("font-style") == true {
                                        saraHeader?.fontStyle = String(alertHeaderStyleArray?[i].split(separator: ":")[1] ?? "")
                                    }
                                }

                                do {
                                    try managedObjectContext?.save()
                                    DDLogDebug("SaraAlert : Saved SaraHeader response in coredata")
                                } catch {
                                    DDLogDebug("SaraAlert : Unable to save SaraHeader response in coredata")
                                }
                            }

                            // Footer Configurations
                            DDLogDebug("SaraAlert : Filtering Footer configuration from parsed data")
                            DataHandler().deleteRecords("SaraFooter", managedObjectContext)

                            managedObjectContext?.performAndWait {
                                saraFooter = NSEntityDescription.insertNewObject(forEntityName: "SaraFooter", into: managedObjectContext!) as? SaraFooter

                                let alertFooterData = alertData?["footer"] as? NSDictionary

                                saraFooter?.footerText = alertFooterData?["text"] as? String

                                let alertFooterStyleArray = alertFooterData?["style"] as? [String]

                                for i in 0 ..< (alertFooterStyleArray?.count ?? 0) {
                                    if alertFooterStyleArray?[i].contains("height") == true {
                                        saraFooter?.height = String(alertFooterStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if alertFooterStyleArray?[i].contains("width") == true {
                                        saraFooter?.width = String(alertFooterStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if alertFooterStyleArray?[i].contains("margin") == true {
                                        saraFooter?.margin = String(alertFooterStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if alertFooterStyleArray?[i].contains("text-align") == true {
                                        saraFooter?.textAlign = String(alertFooterStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if alertFooterStyleArray?[i].contains("border-color") == true {
                                        saraFooter?.borderColor = String(alertFooterStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if alertFooterStyleArray?[i].contains("font-size") == true {
                                        saraFooter?.fontSize = String(alertFooterStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if alertFooterStyleArray?[i].contains("font-weight") == true {
                                        saraFooter?.fontWeight = String(alertFooterStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if alertFooterStyleArray?[i].contains("background-color") == true {
                                        saraFooter?.backgroundColor = String(alertFooterStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if alertFooterStyleArray?[i].contains("border") == true {
                                        saraFooter?.border = String(alertFooterStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if alertFooterStyleArray?[i].contains("color") == true {
                                        saraFooter?.color = String(alertFooterStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if alertFooterStyleArray?[i].contains("font-style") == true {
                                        saraFooter?.fontStyle = String(alertFooterStyleArray?[i].split(separator: ":")[1] ?? "")
                                    }
                                }

                                do {
                                    try managedObjectContext?.save()
                                    DDLogDebug("SaraAlert : Saved SaraFooter response in coredata")
                                } catch {
                                    DDLogDebug("SaraAlert : Unable to save SaraFooter response in coredata")
                                }
                            }

                            // Body Configuration
                            DDLogDebug("SaraAlert : Filtering Body configuration from parsed data")
                            DataHandler().deleteRecords("SaraBody", managedObjectContext)

                            managedObjectContext?.performAndWait {
                                saraBody = NSEntityDescription.insertNewObject(forEntityName: "SaraBody", into: managedObjectContext!) as? SaraBody

                                let saraAlertBodyStyleArray = (alertData?["body"] as? NSDictionary)?["style"] as? [String]

                                for i in 0 ..< (saraAlertBodyStyleArray?.count ?? 0) {
                                    if saraAlertBodyStyleArray?[i].contains("height") == true {
                                        saraBody?.height = String(saraAlertBodyStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if saraAlertBodyStyleArray?[i].contains("width") == true {
                                        saraBody?.width = String(saraAlertBodyStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if saraAlertBodyStyleArray?[i].contains("margin") == true {
                                        saraBody?.margin = String(saraAlertBodyStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if saraAlertBodyStyleArray?[i].contains("text-align") == true {
                                        saraBody?.textAlign = String(saraAlertBodyStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if saraAlertBodyStyleArray?[i].contains("border-color") == true {
                                        saraBody?.borderColor = String(saraAlertBodyStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if saraAlertBodyStyleArray?[i].contains("font-size") == true {
                                        saraBody?.fontSize = String(saraAlertBodyStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if saraAlertBodyStyleArray?[i].contains("font-weight") == true {
                                        saraBody?.fontWeight = String(saraAlertBodyStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if saraAlertBodyStyleArray?[i].contains("background-color") == true {
                                        saraBody?.backgroundColor = String(saraAlertBodyStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if saraAlertBodyStyleArray?[i].contains("border") == true {
                                        saraBody?.border = String(saraAlertBodyStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if saraAlertBodyStyleArray?[i].contains("color") == true {
                                        saraBody?.color = String(saraAlertBodyStyleArray?[i].split(separator: ":")[1] ?? "")
                                    } else if saraAlertBodyStyleArray?[i].contains("font-style") == true {
                                        saraBody?.fontStyle = String(saraAlertBodyStyleArray?[i].split(separator: ":")[1] ?? "")
                                    }
                                }

                                do {
                                    try managedObjectContext?.save()
                                    DDLogDebug("SaraAlert : Saved saraAlertBodyStyleArray response in coredata")
                                } catch {
                                    DDLogDebug("SaraAlert : Unable to save saraAlertBodyStyleArray response in coredata")
                                }
                            }

                            let alertBodyData = (alertData?["body"] as? NSDictionary)?["list"] as? NSArray
                            DataHandler().deleteRecords("SaraBodyText", managedObjectContext)

                            for i in 0 ..< (alertBodyData?.count ?? 0) {
                                managedObjectContext?.performAndWait {
                                    saraBodyText = NSEntityDescription.insertNewObject(forEntityName: "SaraBodyText", into: managedObjectContext!) as? SaraBodyText

                                    saraBodyText?.pointers = (alertBodyData?[i] as? NSDictionary)?["pointers"] as? String

                                    let saraBodyTextStyleArray = (alertBodyData?[i] as? NSDictionary)?["style"] as? [String]

                                    for i in 0 ..< (saraBodyTextStyleArray?.count ?? 0) {
                                        if saraBodyTextStyleArray?[i].contains("height") == true {
                                            saraBodyText?.height = String(saraBodyTextStyleArray?[i].split(separator: ":")[1] ?? "")
                                        } else if saraBodyTextStyleArray?[i].contains("width") == true {
                                            saraBodyText?.width = String(saraBodyTextStyleArray?[i].split(separator: ":")[1] ?? "")
                                        } else if saraBodyTextStyleArray?[i].contains("margin") == true {
                                            saraBodyText?.margin = String(saraBodyTextStyleArray?[i].split(separator: ":")[1] ?? "")
                                        } else if saraBodyTextStyleArray?[i].contains("text-align") == true {
                                            saraBodyText?.textAlign = String(saraBodyTextStyleArray?[i].split(separator: ":")[1] ?? "")
                                        } else if saraBodyTextStyleArray?[i].contains("border-color") == true {
                                            saraBodyText?.borderColor = String(saraBodyTextStyleArray?[i].split(separator: ":")[1] ?? "")
                                        } else if saraBodyTextStyleArray?[i].contains("font-size") == true {
                                            saraBodyText?.fontSize = String(saraBodyTextStyleArray?[i].split(separator: ":")[1] ?? "")
                                        } else if saraBodyTextStyleArray?[i].contains("font-weight") == true {
                                            saraBodyText?.fontWeight = String(saraBodyTextStyleArray?[i].split(separator: ":")[1] ?? "")
                                        } else if saraBodyTextStyleArray?[i].contains("background-color") == true {
                                            saraBodyText?.backgroundColor = String(saraBodyTextStyleArray?[i].split(separator: ":")[1] ?? "")
                                        } else if saraBodyTextStyleArray?[i].contains("border") == true {
                                            saraBodyText?.border = String(saraBodyTextStyleArray?[i].split(separator: ":")[1] ?? "")
                                        } else if saraBodyTextStyleArray?[i].contains("color") == true {
                                            saraBodyText?.color = String(saraBodyTextStyleArray?[i].split(separator: ":")[1] ?? "")
                                        } else if saraBodyTextStyleArray?[i].contains("font-style") == true {
                                            saraBodyText?.fontStyle = String(saraBodyTextStyleArray?[i].split(separator: ":")[1] ?? "")
                                        }
                                    }

                                    do {
                                        try managedObjectContext?.save()
                                        DDLogDebug("SaraAlert : Saved saraBodyTextStyleArray response in coredata")
                                    } catch {
                                        DDLogDebug("SaraAlert : Unable to save saraBodyTextStyleArray response in coredata")
                                    }
                                }
                            }
                            DataHandler().deleteRecords("SaraBodyIndividual", managedObjectContext)

                            for k in 0 ..< (alertBodyData?.count ?? 0) {
                                let alertBodyIndividualData = (alertBodyData?[k] as? NSDictionary)?["text"] as? NSArray

                                for j in 0 ..< (alertBodyIndividualData?.count ?? 0) {
                                    managedObjectContext?.performAndWait {
                                        saraBodyIndividual = NSEntityDescription.insertNewObject(forEntityName: "SaraBodyIndividual", into: managedObjectContext!) as? SaraBodyIndividual

                                        let saraBodyIndividualTextStyle = (alertBodyIndividualData?[j] as? NSDictionary)?["style"] as? [String]

                                        saraBodyIndividual?.bodyText = (alertBodyIndividualData?[j] as? NSDictionary)?["text"] as? String

                                        for i in 0 ..< (saraBodyIndividualTextStyle?.count ?? 0) {
                                            if saraBodyIndividualTextStyle?[i].contains("height") == true {
                                                saraBodyIndividual?.height = String(saraBodyIndividualTextStyle?[i].split(separator: ":")[1] ?? "")
                                            } else if saraBodyIndividualTextStyle?[i].contains("width") == true {
                                                saraBodyIndividual?.width = String(saraBodyIndividualTextStyle?[i].split(separator: ":")[1] ?? "")
                                            } else if saraBodyIndividualTextStyle?[i].contains("margin") == true {
                                                saraBodyIndividual?.margin = String(saraBodyIndividualTextStyle?[i].split(separator: ":")[1] ?? "")
                                            } else if saraBodyIndividualTextStyle?[i].contains("text-align") == true {
                                                saraBodyIndividual?.textAlign = String(saraBodyIndividualTextStyle?[i].split(separator: ":")[1] ?? "")
                                            } else if saraBodyIndividualTextStyle?[i].contains("border-color") == true {
                                                saraBodyIndividual?.borderColor = String(saraBodyIndividualTextStyle?[i].split(separator: ":")[1] ?? "")
                                            } else if saraBodyIndividualTextStyle?[i].contains("font-size") == true {
                                                saraBodyIndividual?.fontSize = String(saraBodyIndividualTextStyle?[i].split(separator: ":")[1] ?? "")
                                            } else if saraBodyIndividualTextStyle?[i].contains("font-weight") == true {
                                                saraBodyIndividual?.fontWeight = String(saraBodyIndividualTextStyle?[i].split(separator: ":")[1] ?? "")
                                            } else if saraBodyIndividualTextStyle?[i].contains("background-color") == true {
                                                saraBodyIndividual?.backgroundColor = String(saraBodyIndividualTextStyle?[i].split(separator: ":")[1] ?? "")
                                            } else if saraBodyIndividualTextStyle?[i].contains("border") == true {
                                                saraBodyIndividual?.border = String(saraBodyIndividualTextStyle?[i].split(separator: ":")[1] ?? "")
                                            } else if saraBodyIndividualTextStyle?[i].contains("color") == true {
                                                saraBodyIndividual?.color = String(saraBodyIndividualTextStyle?[i].split(separator: ":")[1] ?? "")
                                            } else if saraBodyIndividualTextStyle?[i].contains("font-style") == true {
                                                saraBodyIndividual?.fontStyle = String(saraBodyIndividualTextStyle?[i].split(separator: ":")[1] ?? "")
                                            }

                                            // We add indication to represent which line the texts are associated
                                            if saraBodyIndividual?.border == nil {
                                                saraBodyIndividual?.border = "+line\(k + 1)"
                                            } else {
                                                saraBodyIndividual?.border?.append("+line\(k + 1)")
                                            }
                                        }

                                        do {
                                            try managedObjectContext?.save()
                                            DDLogDebug("SaraAlert : Saved saraBodyIndividual response in coredata")
                                        } catch {
                                            DDLogDebug("SaraAlert : Unable to save saraBodyIndividual response in coredata")
                                        }
                                    }

                                    DDLogDebug("SaraAlert : AlertBody individual data append : \(j + 1)")
                                }

                                DDLogDebug("SaraAlert : AlertBody data append : \(k)")
                            }

                            DDLogDebug("SaraAlert : SaraAlert response was successful")

                            if audioPath != "" {
                                DDLogDebug("SaraAlert : Downloading Audio file")
                                if let context = managedObjectContext {
                                    fileDownloader().downloadData(key: alertData?["flashColor"] as? String ?? "", value: audioPath, entity: "SaraAlert", managedObjectContext: context)
                                } else {
                                    DDLogDebug("Managed Object Context is nil. Cannot download data for SaraAlert.")
                                }

                                reset()
                            } else {
                                reset()
                                viewUpdateHandlerConnection.dataForSaraAlertSuccessResponse()
                            }
                        } else {
                            DDLogDebug("SaraAlert : The sara alert response data has no parameters, so presenting the default view now.......")
                            // Deleting the existing alerts
                            DataHandler().deleteRecords("SaraAlert", managedObjectContext)
                            DataHandler().deleteRecords("SaraHeader", managedObjectContext)
                            DataHandler().deleteRecords("SaraFooter", managedObjectContext)
                            DataHandler().deleteRecords("SaraBody", managedObjectContext)
                            DataHandler().deleteRecords("SaraBodyText", managedObjectContext)
                            DataHandler().deleteRecords("SaraBodyIndividual", managedObjectContext)

                            reset()
                            DDLogDebug("SaraAlert : Received empty data response on sara Alert API request ")
                            self.mainViewdelegate?.saraAlertFailureResponse(message: "Received empty data response on sara alert API")
                        }
                    } else {
                        reset()
                        DDLogDebug("SaraAlert : received error response on sara Alert API request ")
                        self.mainViewdelegate?.saraAlertFailureResponse(message: "Received error response on sara alert API")
                    }

                } catch {
                    reset()
                    DDLogDebug("SaraAlert : parsing error at urlsession of sara alert message model \(error)")
                    self.mainViewdelegate?.saraAlertFailureResponse(message: error.localizedDescription)
                }
            } else {
                reset()
                DDLogDebug("SaraAlert : Received empty value on didCompleteWithError data at sara alert message")
                self.mainViewdelegate?.saraAlertFailureResponse(message: "Failure at Sara alert message")
            }
        } catch: { exception in
            DDLogDebug("SaraAlert : Exception in processSaraAlertResponseData - \(String(describing: exception))")
        }
    }
}

// MARK: - SARA Realm Object

// class SaraAlertRealm: Object {
//
//    @objc dynamic  var audio = Data()
//    @objc dynamic  var flash = 0
//    @objc dynamic  var flashColor =  ""
//
//    @objc dynamic  var headerData : saraHeaderClass?
//    @objc dynamic  var bodyData  : saraBodyClass?
//    @objc dynamic  var footerData : saraFooterClass?
//    @objc dynamic  var styleData : saraStyleClass?
// }
//
// class saraStyleClass:Object{
//    @objc dynamic var width = ""
//    @objc dynamic var height = ""
//    @objc dynamic var margin = ""
//    @objc dynamic var color = ""
//    @objc dynamic var textAlign = "" /// This will be either center or left or right
//    @objc dynamic var border = "" /// border line width - solid 5px
//    @objc dynamic var borderColor = ""
//    @objc dynamic var fontSize = ""
//    @objc dynamic var backgroundColor = ""
//    @objc dynamic var fontStyle = "" /// This will be used to differentiate between bold, italic and underline , underline and normal text
//    @objc dynamic var fontWeight = "" /// This will be used to differentiate between bold or normal
//
// }
//
// class saraHeaderClass:Object{
//    @objc dynamic var headerText = ""
//    @objc dynamic var headerStyle : saraStyleClass?
// }
//
// class saraFooterClass: Object {
//    @objc dynamic var footerText = ""
//    @objc dynamic var footerStyle : saraStyleClass?
// }
//
//
// class saraBodyClass:Object{
//   var bodyDataList = List<saraBodyTextData>()
//    @objc dynamic var bodyStyle : saraStyleClass?
//
// }
//
// class saraBodyTextData:Object{
//    /// This text object will be array of list with all the text and sytle as indiviudal
//    @objc dynamic var pointers = "" /// To indicate  - bullet , nothing or blutte or number
//    @objc dynamic var bodyTextStyle : saraStyleClass? /// This style class only contains the text allignment property
//    var bodyIndividualDataList = List<saraBodyIndividualList>() // Since a single line text can contain multiple styles we will be having an array like structure
//
// }
//
// class saraBodyIndividualList:Object{
//    @objc dynamic var bodyText = ""
//    @objc dynamic var bodyStyle : saraStyleClass?
// }

// Things to be changed
// 1. Font-Style multiple values.
// 1. Flash-Color value when the flash option is enabled.
