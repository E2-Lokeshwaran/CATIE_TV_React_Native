//
//  DataHelpers.swift
//  CATIE-TV
//
//  Created by Admin on 24/04/19.
//  Copyright © 2019 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import CoreData
import Foundation
import UIKit

// MARK: - API

class API: NSObject {
    struct networkAPI {
        var weatherURL = "https://\(domainAddress!)/catie/api/deviceNotification/weatherInformationCatieTv?roomNumber=\(roomNo!)"
        var eventsURL = "https://\(domainAddress!)/catie/api/device/event/tvEventList.json?roomNo=\(roomNo!)&userId=\(userID!)"
        var stausIndicatorURL = "https://\(domainAddress!)/catie/api/statusIndicator/getStatusIndicator?roomNumber=\(userID!)"
        var carousalURL = "https://\(domainAddress!)/catie/appadmin/contentManagement/scheduleTemplateTv.do?roomNumber=\(roomNo!)"
        var siteLogoURL = "https://\(domainAddress!)/catie/appadmin/appsetting/propertyDetails/getIcon.do?userId=\(userID!)"
        var imageDownloadURL = "https://\(domainAddress!)/catie"
        var radioFeedURL = "https://\(domainAddress!)/catie/api/device/radio/radioConfiguration?roomNumber=\(roomNo!)"
        var scrollMessageURL = "https://\(domainAddress!)/catie/api/device/scrollingmessage/message.json?userId=\(userID!)"
        var saraAlertURL = "https://\(domainAddress!)/catie/api/deviceNotificationStatus/saraAlertToTv?roomNumber=\(userID!)"
        /// var logFileUploadMultiForm = "https://\(domainAddress!)/catie/saveAppLog.htm"
        var logFileUploadJson = "https://\(domainAddress!)/catie/saveLog.htm"

        var customHomePageURL = "https://\(domainAddress!)/catie/api/deviceConfiguration/getTvInitialConfig?roomNumber=\(roomNo!)"

        var clockURL = "https://\(domainAddress!)/catie/api/statusIndicator/getClockText?roomNumber=\(roomNo!)"
    }
}

// MARK: URLSessionDelegate, URLSessionDataDelegate

extension API: URLSessionDelegate, URLSessionDataDelegate {
    func urlSession(_: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        SwiftTryCatch.try {
            completionHandler(
                URLSession.AuthChallengeDisposition.useCredential,
                URLCredential(trust:
                    challenge.protectionSpace.serverTrust!)
            )
            DDLogDebug("DataHelpers : URLAuthentication Challenge")
        } catch: { exception in
            DDLogDebug("DataHelpers : Exception in URLAuthenticationChallenge - \(String(describing: exception))")
        }
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        SwiftTryCatch.try {
            let response = task.response as? HTTPURLResponse

            DDLogDebug("DataHelpers : Response status - \(String(describing: response?.statusCode))")
            if error != nil {
                DDLogDebug("DataHelpers : NSURLsession connection failed at API Class - \(String(describing: error))")
            }
        } catch: { exception in
            DDLogDebug("DataHelpers : Exception in didCompleteWithError - \(String(describing: exception))")
        }
    }
}

// MARK: - ApplicationState

class ApplicationState: NSObject {
    func resetUserDefaults() {
        SwiftTryCatch.try {
            UserDefaults.standard.set("", forKey: "roomNumber")
            UserDefaults.standard.set("", forKey: "domainAddress")
            UserDefaults.standard.set("", forKey: "userId")
            UserDefaults.standard.synchronize()
        } catch: { exception in
            DDLogDebug("DataHelpers : Exception in resetUserDefaults - \(String(describing: exception))")
        }
    }
}

// MARK: - DeviceDetails

class DeviceDetails: NSObject {
    enum Network: String {
        case wifi = "en0"
        case cellular = "pdp_ip0"
        case ipv4
        case ipv6
        case port1 = "en1"
    }

    func getIPAddress() -> String {
        var ipAddressArray = [String]()
        var ipAddress = "0.0.0.0"

        SwiftTryCatch.try {
            ipAddressArray.append(getAddress(for: .wifi)!)
            ipAddressArray.append(getAddress(for: .cellular)!)
            ipAddressArray.append(getAddress(for: .port1)!)
            ipAddressArray.append(getAddress(for: .ipv4)!)
            ipAddressArray.append(getAddress(for: .ipv6)!)

            DDLogDebug("DataHelpers : get IPAddress Array - \(ipAddressArray)")

            for i in 0 ..< ipAddressArray.count {
                if ipAddressArray[i] != "0.0.0.0" {
                    ipAddress = ipAddressArray[i]
                    break
                }
            }

        } catch: { exception in
            DDLogDebug("DataHelpers : Exception in getIPAddress - \(String(describing: exception))")
        }

        return ipAddress
    }

    func getAddress(for network: Network) -> String? {
        var address: String?
        // Get list of all interfaces on the local machine:
        DDLogDebug("DataHelpers : Get list of all interfaces on the local machine")
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else {
            return "0.0.0.0"
        }
        guard let firstAddr = ifaddr else {
            return "0.0.0.0"
        }

        SwiftTryCatch.try {
            // For each interface ...
            for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
                let interface = ifptr.pointee

                // Check for IPv4 or IPv6 interface:
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    // Check interface name:
                    let name = String(cString: interface.ifa_name)
                    if name == network.rawValue {
                        DDLogDebug("DataHelpers : Check for IPv4 or IPv6 interface")
                        // Convert interface address to a human readable string:
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                    &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        } catch: { exception in
            DDLogDebug("DataHelpers : Exception in getAddress - \(String(describing: exception))")
        }

        if address != nil {
            return address
        } else {
            return "0.0.0.0"
        }
    }

    func getOSVersion() -> String {
        var getOSVersion = String()
        SwiftTryCatch.try {
            getOSVersion = UIDevice.current.systemVersion as NSString as String
        } catch: { exception in
            DDLogDebug("DataHelpers : Exception in getOSVersion - \(String(describing: exception))")
        }

        return getOSVersion
    }

    func getDeviceType() -> String {
        var getDeviceType = String()
        SwiftTryCatch.try {
            getDeviceType = UIDevice.modelName
        } catch: { exception in
            DDLogDebug("DataHelpers : Exception in getDeviceType - \(String(describing: exception))")
        }

        return getDeviceType
    }

    func getAppVersion() -> String {
        var getAppVersion = String()
        SwiftTryCatch.try {
            getAppVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)! + "-" + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String)!
        } catch: { exception in
            DDLogDebug("DataHelpers : Exception in getAppVersion - \(String(describing: exception))")
        }
        return getAppVersion
    }

    func getDateAndTime() -> String {
        var getDateAndTime = String()
        SwiftTryCatch.try {
            let date = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM-dd-yyyy h:mm a"
            getDateAndTime = dateFormatter.string(from: date)
        } catch: { exception in
            DDLogDebug("DataHelpers : Exception in getDateAndTime - \(String(describing: exception))")
        }

        return getDateAndTime
    }
}

public extension UIDevice {
    static let modelName: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else {
                return identifier
            }

            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        func mapToDevice(identifier: String) -> String { // swiftlint:disable:this cyclomatic_complexity
            switch identifier {
            case "AppleTV2,1": "Apple TV 2nd Gen"
            case "AppleTV3,1": "Apple TV 3rd Gen"
            case "AppleTV3,2": "Apple TV 3rd Gen"
            case "AppleTV5,3": "Apple TV 4"
            case "AppleTV6,2": "Apple TV 4K"
            case "i386",
                 "x86_64": "Simulator \(mapToDevice(identifier: ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "tvOS"))"
            default: identifier
            }
        }

        return mapToDevice(identifier: identifier)
    }()
}

// MARK: - fileDownloader

class fileDownloader: NSObject {
    var managedObjectContext: NSManagedObjectContext?
    var entityName: String?

    func downloadData(key: String, value: String, entity: String, managedObjectContext: NSManagedObjectContext) {
        SwiftTryCatch.try {
            entityName = entity

            self.managedObjectContext = managedObjectContext

            let urlString = value

            let encodedString = urlString.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? ""
            let url = URL(string: encodedString)

            DDLogDebug("fileDownloader : Calling image downloadData API \(String(describing: url))")

            let urlRequest = URLRequest(url: url!)

            let session = URLSession(configuration: .default, delegate: API(), delegateQueue: nil)

            let task = session.dataTask(with: urlRequest) { [self] data, response, error in
                defer {
                    // Properly invalidate session to prevent memory leaks
                    session.finishTasksAndInvalidate()
                }

                DDLogDebug("fileDownloader : Response code - \(String(describing: (response as? HTTPURLResponse)?.statusCode)) for \(String(describing: url))")

                guard error == nil else {
                    if entityName == "CarousalImages" {
                        downloadedCarousalCount = downloadedCarousalCount + 1
                    } else if entityName == "SiteLogo" {
                        siteLogoDownloaded = true
                    } else if entityName == "Weather" {
                        weatherIconsDownloaded += 1
                        OngoingAPICallDict.shared.setObject(key: "Weather", value: false)
                    } else if entityName == "SaraAlert" {
                        saraAlertWithAudio = true
                    }
                    DDLogDebug("fileDownloader : error at downloadData - \(String(describing: error?.localizedDescription)) for \(String(describing: url))")

                    return
                }
                guard let content = data else {
                    DDLogDebug("fileDownloader : error data at downloadData - \(String(describing: error?.localizedDescription)) for \(String(describing: url))")

                    return
                }

                DDLogDebug("fileDownloader : Downloaded data \(content.count) for \(String(describing: url))")

                updateData(entityName: entityName!, identifier: key, data: content)
            }
            task.resume()

        } catch: { exception in
            DDLogDebug("fileDownloader : Exception in downloadData - \(String(describing: exception))")

            if entityName == "CarousalImages" {
                downloadedCarousalCount = downloadedCarousalCount + 1
            } else if entityName == "SiteLogo" {
                siteLogoDownloaded = true
            } else if entityName == "Weather" {
                weatherIconsDownloaded += 1
                OngoingAPICallDict.shared.setObject(key: "Weather", value: false)
            } else if entityName == "SaraAlert" {
                saraAlertWithAudio = true
            }
        }
    }

    func updateData(entityName: String, identifier: String, data: Data?) {
        if managedObjectContext == nil {
            DispatchQueue.main.sync {
                DDLogDebug("fileDownloader : context required for update")
                managedObjectContext = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.newBackgroundContext()
            }
        }

        let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
        fetchRequest.entity = NSEntityDescription.entity(forEntityName: entityName, in: managedObjectContext!)
        var predicate: NSPredicate?
        if entityName == "CarousalImages" {
            predicate = NSPredicate(format: "imageName == %@", identifier)
        } else if entityName == "Weather" {
            predicate = NSPredicate(format: "date == %@", identifier)
        } else if entityName == "ForeCastWeather" {
            predicate = NSPredicate(format: "day == %@", identifier)
        } else if entityName == "SiteLogo" {
            predicate = NSPredicate(format: "imageName == %@", identifier)
        } else if entityName == "SaraAlert" {
            //            predicate = NSPredicate(format: "flashColor == %@", identifier)
        }

        fetchRequest.predicate = predicate
        //            fetchRequest.includesPropertyValues = false //only fetch the managedObjectID
        fetchRequest.returnsObjectsAsFaults = false

        var rows: [Any]? = nil

        managedObjectContext?.performAndWait {
            do {
                rows = try (managedObjectContext)?.fetch(fetchRequest)

            } catch {
                DDLogDebug("updateData : Exception in Fetching \(entityName) details - \(String(describing: error))")
            }
            if !(rows?.isEmpty ?? true) {
                DDLogDebug("updateData : Fetching \(entityName) data successfully - \(String(describing: rows))")
            } else {
                DDLogDebug("updateData : No \(entityName) data available in local storage")
            }

            if entityName == "CarousalImages" {
                if !(rows?.isEmpty ?? true) {
                    let carousalImages = rows?[0] as? CarousalImages
                    carousalImages?.carousalImage = data ?? Data()

                    do {
                        try managedObjectContext?.save()
                        DDLogDebug("updateData : Existing \(String(describing: entityName)) records updated succesfully")
                        downloadedCarousalCount += 1
                    } catch {
                        DDLogDebug("updateData : Exception in \(String(describing: entityName)) records updation - \(String(describing: error))")
                        downloadedCarousalCount += 1
                    }
                } else {
                    downloadedCarousalCount += 1
                }

            } else if entityName == "Weather" {
                if !(rows?.isEmpty ?? true) {
                    let weather = rows?[0] as? Weather
                    weather?.weatherIcon = data ?? Data()

                    do {
                        try managedObjectContext?.save()
                        DDLogDebug("updateData : Existing \(String(describing: entityName)) records updated succesfully")
                        weatherIconsDownloaded += 1
                    } catch {
                        DDLogDebug("updateData : Exception in \(String(describing: entityName)) records updation - \(String(describing: error))")
                        weatherIconsDownloaded += 1
                    }

                } else {
                    weatherIconsDownloaded += 1
                }

            } else if entityName == "ForeCastWeather" {
                if !(rows?.isEmpty ?? true) {
                    let forecastWeather = rows?[0] as? ForeCastWeather
                    forecastWeather?.weatherIcons = data ?? Data()

                    do {
                        try managedObjectContext?.save()
                        DDLogDebug("updateData : Existing \(String(describing: entityName)) records updated succesfully")
                        weatherIconsDownloaded += 1
                    } catch {
                        DDLogDebug("updateData : Exception in \(String(describing: entityName)) records updation - \(String(describing: error))")
                        weatherIconsDownloaded += 1
                    }

                } else {
                    weatherIconsDownloaded += 1
                }
            } else if entityName == "SiteLogo" {
                if !(rows?.isEmpty ?? true) {
                    let siteLogo = rows?[0] as? SiteLogo
                    siteLogo?.imageData = data ?? Data()
                    do {
                        try managedObjectContext?.save()
                        DDLogDebug("updateData : Existing \(String(describing: entityName)) records updated succesfully")
                        siteLogoDownloaded = true
                    } catch {
                        DDLogDebug("updateData : Exception in \(String(describing: entityName)) records updation - \(String(describing: error))")
                        siteLogoDownloaded = true
                    }
                } else {
                    siteLogoDownloaded = true
                }

            } else if entityName == "SaraAlert" {
                if !(rows?.isEmpty ?? true) {
                    let saraAlert = rows?[0] as? SaraAlert
                    saraAlert?.audio = data ?? Data()
                    do {
                        try managedObjectContext?.save()
                        DDLogDebug("updateData : Existing \(String(describing: entityName)) records updated succesfully")
                        saraAlertWithAudio = true
                    } catch {
                        DDLogDebug("updateData : Exception in \(String(describing: entityName)) records updation - \(String(describing: error))")
                        saraAlertWithAudio = true
                    }
                } else {
                    saraAlertWithAudio = true
                }
            }
        }
    }
}

////MARK:- App Log Handling
// extension OSLog {
//    private static var subsystem = Bundle.main.bundleIdentifier!
//
//    static let HomeView = OSLog(subsystem: subsystem, category: "HomeViewController")
//    static let HomeViewExtension = OSLog(subsystem: subsystem, category: "HomeViewControllerExtension")
//    static let Registration = OSLog(subsystem: subsystem, category: "RegistrationViewController")
//    static let Radio = OSLog(subsystem: subsystem, category: "RadioViewController")
//    static let NetworkDown = OSLog(subsystem: subsystem, category: "NetworkDownViewController")
//    static let DesignHelper = OSLog(subsystem: subsystem, category: "DesignHelperClass")
//    static let AppDelegate = OSLog(subsystem: subsystem, category: "AppDelegateClass")
//    static let DataHelper = OSLog(subsystem: subsystem, category: "DatahelperClass")
//    static let Socket = OSLog(subsystem: subsystem, category: "SocketConnectionClass")
//    static let Weather = OSLog(subsystem: subsystem, category: "WeatherModel")
//    static let Events = OSLog(subsystem: subsystem, category: "EventsModel")
//    static let Carousal = OSLog(subsystem: subsystem, category: "CarousalModel")
//    static let Status = OSLog(subsystem: subsystem, category: "StatusIndicatorModel")
//
// }
