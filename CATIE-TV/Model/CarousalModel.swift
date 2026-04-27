//
//  CarousalModel.swift
//  CATIE-TV
//
//  Created by Admin on 06/05/19.
//  Copyright © 2019 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import CoreData
import Foundation

// MARK: - CarousalModel

class CarousalModel: NSObject {
    // MARK: Lifecycle

    deinit {
        DDLogDebug("CarousalModel: deinit - cleaning up resources")

        // Cancel any running data task to prevent memory leaks
        if let task = carousalDataTask {
            if task.state == .running {
                task.cancel()
                DDLogDebug("CarousalModel: cancelled running carousalDataTask")
            }
        }

        // Invalidate URLSession to break delegate retain cycle
        urlSession?.invalidateAndCancel()
        urlSession = nil

        // Clean up all resources
        reset()

        DDLogDebug("CarousalModel: deinit - all resources cleaned up")
    }

    // MARK: Internal

    weak var mainViewdelegate: MainScreenDelegate?
    weak var tempMainViewDelegate: MainScreenDelegate?

    var carousalImageData: Data!
    var carousalDataTask: URLSessionDataTask?
    var urlSession: URLSession?

    var managedObjectContext: NSManagedObjectContext?
    var appDel: AppDelegate?
    var carousal: Carousal?
    var carousalImagesData: CarousalImages?

    func getCarousalData() {
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

            DDLogDebug("Carousal : Get Carousal Data from server")

            let carousalAPI = URL(string: API.networkAPI().carousalURL.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "")

            let request = URLRequest(url: carousalAPI!)

            var canMakeNewCarouselRequest = false

            if carousalDataTask != nil {
                switch carousalDataTask!.state {
                case .running:
                    DDLogDebug("Carousal : CarousalDataTask state is running ")
                    canMakeNewCarouselRequest = true
                    carousalDataTask!.cancel()

                case .suspended:
                    DDLogDebug("Carousal : CarousalDataTask state is suspended ")
                    canMakeNewCarouselRequest = true

                case .canceling:
                    DDLogDebug("Carousal : CarousalDataTask state is canceling ")
                    canMakeNewCarouselRequest = true

                case .completed:
                    DDLogDebug("Carousal : CarousalDataTask state is completed ")
                    canMakeNewCarouselRequest = true

                default:
                    DDLogDebug("Carousal : CarousalDataTask state is default")
                    canMakeNewCarouselRequest = true
                }
            } else {
                canMakeNewCarouselRequest = true
            }

            if canMakeNewCarouselRequest {
                carousalDataTask = nil
                carousalImageData = Data()

                DDLogDebug("Carousal : Calling carousal API with url \(String(describing: carousalAPI))")

                // Invalidate previous session to prevent accumulation
                urlSession?.invalidateAndCancel()
                urlSession = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)

                carousalDataTask = urlSession?.dataTask(with: request)
                carousalDataTask?.resume()
            } else {
                DDLogDebug("Carousal : Already scheduled carousal task is in-progress ignoring new coming task...")
            }

        } catch: { exception in
            DDLogDebug("Carousal : Exception in getCarousalData - \(String(describing: exception))")
        }
    }

    func reset() {
        carousal = nil
        carousalImagesData = nil
        appDel = nil
        managedObjectContext = nil
        tempMainViewDelegate = nil
        carousalDataTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        carousalImageData = Data()
    }
}

// MARK: URLSessionDelegate, URLSessionDataDelegate

extension CarousalModel: URLSessionDelegate, URLSessionDataDelegate {
    func urlSession(_: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        SwiftTryCatch.try {
            completionHandler(
                URLSession.AuthChallengeDisposition.useCredential,
                URLCredential(trust:
                    challenge.protectionSpace.serverTrust!)
            )
            DDLogDebug("Carousal : URLAuthentication Challenge")
        } catch: { exception in
            DDLogDebug("Carousal : Exception in URLAuthenticationChallenge - \(String(describing: exception))")
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

            DDLogDebug("Carousal : MainViewDelegate - \(String(describing: mainViewdelegate))")

            let response = task.response as? HTTPURLResponse

            let safeDict = StatusCodeDict.shared
            safeDict.setObject(key: "statusCodeForCarousal", value: response?.statusCode ?? 0)

            DDLogDebug("Carousal : Response status - \(String(describing: response?.statusCode))")

            if error != nil {
                DDLogDebug("Carousal : NSURLSession connection error at carousalModel \(String(describing: error))")
                reset()
                if tvStatus == 1 {
                    self.mainViewdelegate?.CarousalImagesFailureResponse(message: (error?.localizedDescription)!, isNetworkError: true)
                } else {
                    DDLogDebug("Carousal : No room is registered")
                }

            } else {
                // Facing didReceive data with data overlap issue due to discontiguous data,so processing the received
                // data with local variable instead of carousalImageData would avoid data parsing issue.
                if tvStatus == 1 {
                    if OngoingAPICallDict.shared.getValue(key: "Carousal") == false {
                        DDLogDebug("Carousal : Process Carousal Data")
                        OngoingAPICallDict.shared.setObject(key: "Carousal", value: true)
                        processCarousalResponseData(carousalImageData)
                    } else {
                        DDLogDebug("Carousal : Ongoing carousal process avilable")
                        PendingAPICallRequestDict.shared.setObject(key: "Carousal", value: true)
                    }

                } else {
                    OngoingAPICallDict.shared.setObject(key: "Carousal", value: false)
                    reset()
                    DDLogDebug("Carousal : No room is registered so not saving carousal response")
                }
            }

        } catch: { exception in
            DDLogDebug("Carousal : Exception in didCompleteWithError - \(String(describing: exception))")
        }
    }

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
        SwiftTryCatch.try {
            if !data.isEmpty {
                carousalImageData.append(data)
                DDLogDebug("Carousal : Received Data successfully")
            } else {
                DDLogDebug("Carousal : Received empty value on didReceive data at CarousalModel")
            }
        } catch: { exception in
            DDLogDebug("Carousal : Exception in didReceive - \(String(describing: exception))")
        }
    }

    func processCarousalResponseData(_ carousalResponseData: Data?) {
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

        var carousalForDownload: [String: String] = [:]

        SwiftTryCatch.try {
            if carousalResponseData != nil, !carousalResponseData!.isEmpty {
                let jsonData = String(decoding: carousalResponseData!, as: UTF8.self)

                DDLogDebug("Carousal : Data - \(jsonData)")

                do {
                    DDLogDebug("Carousal : Parsing Json data from server")

                    let decoder = JSONDecoder()
                    let carousalResponse = try decoder.decode(carousalImagesResponseModel.self, from: carousalResponseData!)

                    DDLogDebug("Carousal : Carousal Json Data - \(carousalResponse)")

                    if carousalResponse.status == "success" {
                        let existingCarousal = DataHandler().fetchData("CarousalImages", managedObjectContext)

                        var existingCarousalDict: [String: (Data, String)] = [:]

                        // Moving existing carousal details into local variables to use in comparison below

                        managedObjectContext?.performAndWait {
                            if existingCarousal?.count ?? 0 > 0 {
                                for carousal in existingCarousal! {
                                    let carousalDetails = carousal as? CarousalImages
                                    existingCarousalDict.updateValue((carousalDetails?.carousalImage ?? Data(), carousalDetails?.audioPath ?? ""), forKey: (carousalDetails?.imageName ?? ""))
                                }
                            }
                        }

                        DataHandler().deleteRecords("Carousal", managedObjectContext)

                        managedObjectContext?.performAndWait {
                            carousal = NSEntityDescription.insertNewObject(forEntityName: "Carousal", into: managedObjectContext!) as? Carousal
                            carousal?.status = carousalResponse.status
                            carousal?.startTime = carousalResponse.startTime
                            carousal?.endTime = carousalResponse.endTime

                            do {
                                try managedObjectContext?.save()
                                DDLogDebug("Carousal : Saved Carousal response in coredata")
                            } catch {
                                DDLogDebug("Carousal : Unable to Carousal Weather response in coredata")
                            }
                            DDLogDebug("Carousal : Carousal Data : \(String(describing: carousal))")
                            DDLogDebug("Carousal : Existing Carousal Data : \(String(describing: existingCarousal))")
                        }

                        DataHandler().deleteRecords("CarousalImages", managedObjectContext)

                        if carousalResponse.data?.count ?? 0 > 0 {
                            DDLogDebug("Carousal : Existing carousal Data - \(existingCarousalDict)")

                            // Downloading only changed images from the server by checking last updated data
                            for i in 0 ..< (carousalResponse.data?.count ?? 0) {
                                DDLogDebug("Carousal : Processing carousal entry \(i)")

                                guard let scheduleImagePath = carousalResponse.data?[i].scheduleImagePath,
                                      let imageFilePath = scheduleImagePath.components(separatedBy: "&").first,
                                      let imageName = imageFilePath.components(separatedBy: "=").last,
                                      !imageName.isEmpty
                                else {
                                    DDLogDebug("Carousal : Skipping entry due to invalid image path or name")
                                    continue
                                }

                                let carouselAudioURL: String

                                let domain = domainAddress ?? ""
                                if let audioPath = carousalResponse.data?[i].audioPath, !audioPath.isEmpty, !domain.isEmpty {
                                    carouselAudioURL = "https://\(domain)\(audioPath)"
                                } else {
                                    carouselAudioURL = ""
                                }

                                var matchFound = false

                                DDLogDebug("Carousal : Checking existing carousel data & its path")
                                if let existingImage = existingCarousalDict[imageName], !existingImage.0.isEmpty {
                                    matchFound = true
                                    DDLogDebug("Carousal : Found existing carousel data & its path")
                                }

                                managedObjectContext?.performAndWait {
                                    carousalImagesData = NSEntityDescription.insertNewObject(forEntityName: "CarousalImages", into: managedObjectContext!) as? CarousalImages

                                    // Check if the image has changed or needs downloading
                                    if matchFound {
                                        carousalImagesData?.imageName = imageName
                                        carousalImagesData?.carousalImage = existingCarousalDict[imageName]?.0
                                        DDLogDebug("Carousal : Using existing image data for \(imageName)")
                                    } else {
                                        DDLogDebug("Carousal : Downloading new image for \(imageName)")
                                        carousalImagesData?.imageName = imageName
                                        let imagePath = "https://\(domainAddress ?? "")" + scheduleImagePath
                                        carousalForDownload[imageName] = imagePath
                                    }

                                    // Add the audio path
                                    carousalImagesData?.audioPath = carouselAudioURL

                                    DDLogDebug("Carousal : Checking Slide Type")
                                    let slideType = carousalResponse.data?[i].slideDetails?.carouselType ?? 0
                                    carousalImagesData?.carouselType = Int16(slideType)

                                    if slideType == 1 { // Ingage
                                        DDLogDebug("Carousal : Slide Type - Ingage")
                                        carousalImagesData?.slotTime = Int16(carousalResponse.data?[i].slideDetails?.timeout ?? 5)
                                    } else { // Carousel
                                        DDLogDebug("Carousal : Slide Type - Carousel")
                                        carousalImagesData?.slotTime = Int16(carousalResponse.slotTime)
                                    }

                                    do {
                                        try managedObjectContext?.save()
                                        DDLogDebug("Carousal : Saved CarousalImage response in Core Data")
                                    } catch {
                                        DDLogDebug("Carousal : Unable to save CarousalImage response in Core Data")
                                    }
                                    DDLogDebug("Carousal : CarousalImage Data : \(String(describing: carousalImagesData))")
                                }
                            }
                        } else {
                            DDLogDebug("Carousal : Carousal Images response is empty")
                        }

                        DDLogDebug("Carousal : Carousal response was successful")
                        carousalDataTask = nil

                        if !carousalForDownload.isEmpty {
                            DDLogDebug("Carousal : Total Images need to be downloaded - \(carousalForDownload.count)")
                            carousalsForDownload = carousalForDownload.count
                            downloadedCarousalCount = 0
                            downloadCarousalImage(imageDict: carousalForDownload)
                            reset()
                        } else {
                            reset()
                            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "refreshCarousalModel"), object: nil)
                        }

                    } else {
                        reset()
                        DDLogDebug("Carousal : Carousal response was unsuccessful")
                        self.mainViewdelegate?.CarousalImagesFailureResponse(message: "No Carousal images available!")
                    }

                } catch {
                    reset()
                    DDLogDebug("Carousal : Parsing error at urlsession of carousal model \(error)")
                    self.mainViewdelegate?.CarousalImagesFailureResponse(message: error.localizedDescription)
                }
            } else {
                reset()
                DDLogDebug("Carousal : Received empty value on processCarousalResponseData at CarousalModel")
                self.mainViewdelegate?.CarousalImagesFailureResponse(message: "No Carousal images available!")
            }
        } catch: { exception in
            reset()
            DDLogDebug("Carousal : Exception in processCarousalResponseData - \(String(describing: exception))")
            self.mainViewdelegate?.CarousalImagesFailureResponse(message: "\(String(describing: exception))")
        }
    }

    func downloadCarousalImage(imageDict: [String: String]) {
        SwiftTryCatch.try {
            if managedObjectContext == nil {
                DDLogDebug("Carousal: Error at downloadCarousalImage managedObjectContext is nil")
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
            } else {
                for i in imageDict {
                    let data = i
                    DDLogDebug("Carousal : Calling downloadImage API for \(data.key) and url - \(data.value)")
                    if let context = managedObjectContext {
                        fileDownloader().downloadData(key: data.key, value: data.value, entity: "CarousalImages", managedObjectContext: context)
                    } else {
                        DDLogDebug("managedObjectContext is nil - Cannot download data for CarousalImages.")
                    }
                }
            }
        } catch: { exception in
            DDLogDebug("Carousal : Exception in downloadCarousalImage - \(String(describing: exception))")
        }
    }
}

// MARK: - carousalImagesResponseModel

struct carousalImagesResponseModel: Codable {
    var status: String
    var slotTime: Int
    var startTime: String
    var endTime: String
    var data: [carousalData]?
}

// MARK: - carousalData

struct carousalData: Codable {
    var slideDetails: carouselSlideData? // To get the configuration details for the individual slide
    var scheduleImagePath: String
    var audioPath: String?
}

// MARK: - carouselSlideData

struct carouselSlideData: Codable {
    var timeout: Int?
    var carouselType: Int // 0 - carousel, 1- Ingage
    var title: String?
}
