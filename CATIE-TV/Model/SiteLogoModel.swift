//
//  SiteLogoModel.swift
//  CATIE-TV
//
//  Created by Pavithran on 01/06/20.
//  Copyright © 2020 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import CoreData
import Foundation

// MARK: - SiteLogoModel

class SiteLogoModel: NSObject {
    // MARK: Lifecycle

    deinit {
        DDLogDebug("SiteLogoModel: deinit - cleaning up resources")

        // Cancel any running data task to prevent memory leaks
        if let task = siteLogoDataTask {
            if task.state == .running {
                task.cancel()
                DDLogDebug("SiteLogoModel: cancelled running siteLogoDataTask")
            }
        }

        // Invalidate URLSession to break delegate retain cycle
        urlSession?.invalidateAndCancel()
        urlSession = nil

        // Clean up all resources
        reset()

        DDLogDebug("SiteLogoModel: deinit - all resources cleaned up")
    }

    // MARK: Internal

    weak var mainViewdelegate: MainScreenDelegate?
    weak var tempMainViewDelegate: MainScreenDelegate?
    var appDel: AppDelegate?
    var managedObjectContext: NSManagedObjectContext?
    var siteLogo: SiteLogo?

    var siteLogoImageData: Data!
    var siteLogoDataTask: URLSessionDataTask?
    var urlSession: URLSession?

    func getSiteLogoData() {
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

            DDLogDebug("SiteLogo : Get SiteLogo Data from server")

            let siteLogoAPI = URL(string: API.networkAPI().siteLogoURL.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "")

            let request = URLRequest(url: siteLogoAPI!)

            var canMakeNewCarouselRequest = false
            if siteLogoDataTask != nil {
                switch siteLogoDataTask!.state {
                case .running:
                    DDLogDebug("SiteLogo : SiteLogDataTask state is running ")
                    canMakeNewCarouselRequest = false

                case .suspended:
                    DDLogDebug("SiteLogo : SiteLogDataTask state is suspended ")
                    canMakeNewCarouselRequest = true

                case .canceling:
                    DDLogDebug("SiteLogo : SiteLogDataTask state is canceling ")
                    canMakeNewCarouselRequest = true

                case .completed:
                    DDLogDebug("SiteLogo : SiteLogDataTask state is completed ")
                    canMakeNewCarouselRequest = true

                default:
                    DDLogDebug("SiteLogo : SiteLogDataTask state is default ")
                    canMakeNewCarouselRequest = true
                }
            } else {
                canMakeNewCarouselRequest = true
            }

            if canMakeNewCarouselRequest {
                siteLogoImageData = nil
                siteLogoImageData = Data()

                DDLogDebug("SiteLogo : Calling site logo API with url \(String(describing: siteLogoAPI))")

                // Invalidate previous session to prevent accumulation
                urlSession?.invalidateAndCancel()
                urlSession = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)

                siteLogoDataTask = urlSession?.dataTask(with: request)
                siteLogoDataTask?.resume()
            } else {
                DDLogDebug("SiteLogo : Already scheduled site logo task is in-progress ignoring new coming task...")
            }
        } catch: { exception in
            DDLogDebug("SiteLogo : Exception in getSiteLogoData - \(String(describing: exception))")
        }
    }

    func reset() {
        urlSession?.invalidateAndCancel()
        urlSession = nil
        appDel = nil
        siteLogo = nil
        siteLogoDataTask = nil
        managedObjectContext = nil
        tempMainViewDelegate = nil
        siteLogoImageData = Data()
    }
}

// MARK: URLSessionDelegate, URLSessionDataDelegate

extension SiteLogoModel: URLSessionDelegate, URLSessionDataDelegate {
    func urlSession(_: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        SwiftTryCatch.try {
            completionHandler(
                URLSession.AuthChallengeDisposition.useCredential,
                URLCredential(trust:
                    challenge.protectionSpace.serverTrust!)
            )
            DDLogDebug("SiteLogo : URLAuthentication challenge")
        } catch: { exception in
            DDLogDebug("SiteLogo : Exception in URLAuthenticationChallenge - \(String(describing: exception))")
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

            DDLogDebug("SiteLogo : MainViewDelegate - \(String(describing: mainViewdelegate))")

            let response = task.response as? HTTPURLResponse

            let safeDict = StatusCodeDict.shared
            safeDict.setObject(key: "statusCodeForSiteLogo", value: response?.statusCode ?? 0)

            DDLogDebug("SiteLogo : Response status - \(String(describing: response?.statusCode))")

            if error != nil {
                DDLogDebug("SiteLogo : NSURLSession connection error at siteLogoModel \(String(describing: error?.localizedDescription))")
                reset()
                if tvStatus == 1 {
                    self.mainViewdelegate?.siteLogoFailureResponse(message: (error?.localizedDescription)!, isNetworkError: true)
                } else {
                    DDLogDebug("SiteLogo : No room is registered")
                }
            } else {
                if tvStatus == 1 {
                    if OngoingAPICallDict.shared.getValue(key: "SiteLogo") == false {
                        DDLogDebug("SiteLogo : Process SiteLogo Data")
                        OngoingAPICallDict.shared.setObject(key: "SiteLogo", value: true)
                        processSiteLogoResponseData()
                    } else {
                        DDLogDebug("SiteLogo : Ongoing SiteLogo process available")
                        PendingAPICallRequestDict.shared.setObject(key: "SiteLogo", value: true)
                    }
                } else {
                    DDLogDebug("SiteLogo : No room is registered so not saving site logo response")
                    reset()
                    OngoingAPICallDict.shared.setObject(key: "SiteLogo", value: false)
                }
            }

        } catch: { exception in
            DDLogDebug("SiteLogo : Exception in didCompleteWithError - \(String(describing: exception))")
            reset()
        }
    }

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
        SwiftTryCatch.try {
            if !data.isEmpty {
                siteLogoImageData.append(data)
                DDLogDebug("SiteLogo : Received Data Successfully")
            } else {
                DDLogDebug("SiteLogo : Received empty value on didReceive data at siteLogoModel")
            }
        } catch: { exception in
            DDLogDebug("SiteLogo : Exception in didReceive - \(String(describing: exception))")
        }
    }

    func processSiteLogoResponseData() {
        SwiftTryCatch.try {
            if managedObjectContext == nil {
                DDLogDebug("SiteLogo : Error in processSiteLogoResponseData managedObjectContext is nil")
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

            if !siteLogoImageData.isEmpty {
                let jsonData = String(decoding: siteLogoImageData, as: UTF8.self)
                DDLogDebug("SiteLogo : Data - \(jsonData)")
                do {
                    DDLogDebug("SiteLogo : Parsing Json data from the server")
                    let decoder = JSONDecoder()
                    let siteLogoResponse = try decoder.decode(siteLogoResponseModel.self, from: siteLogoImageData)

                    DDLogDebug("SiteLogo : SiteLogo Json Data - \(siteLogoResponse)")

                    if siteLogoResponse.status == "success" {
                        DataHandler().deleteRecords("SiteLogo", managedObjectContext)

                        let imageURL = "https://\(domainAddress!)" + (siteLogoResponse.data?.catieTvIcon ?? "")
                        let imagePath = siteLogoResponse.data?.catieTvIcon.components(separatedBy: "&")
                        let imageName = imagePath?[0].components(separatedBy: "=")[1]

                        managedObjectContext?.performAndWait {
                            siteLogo = NSEntityDescription.insertNewObject(forEntityName: "SiteLogo", into: managedObjectContext!) as? SiteLogo
                            siteLogo?.imageName = imageName ?? ""

                            do {
                                try managedObjectContext?.save()
                                DDLogDebug("SiteLogo : Saved Site Logo response in coredata")
                            } catch {
                                DDLogDebug("SiteLogo : Unable to save Site Logo response in coredata")
                            }
                        }
                        if let context = managedObjectContext {
                            fileDownloader().downloadData(key: imageName ?? "", value: imageURL, entity: "SiteLogo", managedObjectContext: context)
                        } else {
                            DDLogDebug("Managed Object Context is nil - Cannot download data for SiteLogo.")
                        }

                        DDLogDebug("SiteLogo : Site Logo response was successful")
                        reset()

                    } else {
                        reset()
                        DDLogDebug("SiteLogo : Site Logo response was unsuccessful")
                        self.mainViewdelegate?.siteLogoFailureResponse(message: "No Site image available!")
                    }

                } catch {
                    reset()
                    DDLogDebug("SiteLogo : NSURLSession connection error at siteLogoModel \(String(describing: error))")
                    self.mainViewdelegate?.siteLogoFailureResponse(message: error.localizedDescription)
                }
            } else {
                reset()
                DDLogDebug("SiteLogo : NSURLSession connection error at siteLogoModel")
                self.mainViewdelegate?.siteLogoFailureResponse(message: "Failure at siteLogo")
            }

            OngoingAPICallDict.shared.setObject(key: "SiteLogo", value: false)
        } catch: { exception in
            OngoingAPICallDict.shared.setObject(key: "SiteLogo", value: false)
            DDLogDebug("SiteLogo : Exception in processSiteLogoResponseData - \(String(describing: exception))")
        }
    }
}

// MARK: - siteLogoResponseModel

struct siteLogoResponseModel: Codable {
    var status: String
    var data: siteLogoData?
}

// MARK: - siteLogoData

struct siteLogoData: Codable {
    var catieTvIcon: String
}
