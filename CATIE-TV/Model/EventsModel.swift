//
//  EventsModel.swift
//  CATIE-TV
//
//  Created by Admin on 30/04/19.
//  Copyright © 2019 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import CoreData
import Foundation

// MARK: - EventsModel

class EventsModel: NSObject {
    // MARK: Lifecycle

    deinit {
        DDLogDebug("EventsModel: deinit - cleaning up resources")

        // Cancel any running data task to prevent memory leaks
        if let task = eventDataTask {
            if task.state == .running {
                task.cancel()
                DDLogDebug("EventsModel: cancelled running eventDataTask")
            }
        }

        // Invalidate URLSession to break delegate retain cycle
        urlSession?.invalidateAndCancel()
        urlSession = nil

        // Clean up all resources
        reset()

        DDLogDebug("EventsModel: deinit - all resources cleaned up")
    }

    // MARK: Internal

    weak var mainViewdelegate: MainScreenDelegate?

    weak var tempMainViewDelegate: MainScreenDelegate?

    var eventListData: Data!
    var eventDataTask: URLSessionDataTask?
    var urlSession: URLSession?
    var managedObjectContext: NSManagedObjectContext?
    var appDel: AppDelegate?
    var event: Event?
    var eventList: EventList?

    func getEventsData() {
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

            DDLogDebug("Event : Get Event Data from server")

            let eventsAPI = URL(string: API.networkAPI().eventsURL.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "")

            let request = URLRequest(url: eventsAPI!)

            var canMakeNewEventRequest = false
            if eventDataTask != nil {
                switch eventDataTask!.state {
                case .running:
                    DDLogDebug("Event : eventDataTask state is running ")
                    canMakeNewEventRequest = false

                case .suspended:
                    DDLogDebug("Event : eventDataTask state is suspended ")
                    canMakeNewEventRequest = true

                case .canceling:
                    DDLogDebug("Event : eventDataTask state is canceling ")
                    canMakeNewEventRequest = true

                case .completed:
                    DDLogDebug("Event : eventDataTask state is completed ")
                    canMakeNewEventRequest = true

                default:
                    DDLogDebug("Event : eventDataTask state is default ")
                    canMakeNewEventRequest = true
                }
            } else {
                canMakeNewEventRequest = true
            }

            if canMakeNewEventRequest {
                eventDataTask = nil
                eventListData = Data()

                DDLogDebug("Event : Calling event API with url \(String(describing: eventsAPI))")

                // Invalidate previous session to prevent accumulation
                urlSession?.invalidateAndCancel()
                urlSession = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)

                eventDataTask = urlSession?.dataTask(with: request)
                eventDataTask?.resume()
            } else {
                DDLogDebug("Event : Already scheduled event task is in-progress ignoring new coming task...")
            }
        } catch: { exception in
            DDLogDebug("Event : Exception in getEventsData - \(String(describing: exception))")
        }
    }

    func reset() {
        appDel = nil
        event = nil
        eventList = nil
        eventDataTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        managedObjectContext = nil
        tempMainViewDelegate = nil
        eventListData = Data()
    }
}

// MARK: URLSessionDelegate, URLSessionDataDelegate

extension EventsModel: URLSessionDelegate, URLSessionDataDelegate {
    func urlSession(_: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        SwiftTryCatch.try {
            completionHandler(
                URLSession.AuthChallengeDisposition.useCredential,
                URLCredential(trust:
                    challenge.protectionSpace.serverTrust!)
            )
            DDLogDebug("Event : URLAuthentication Challenge")
        } catch: { exception in
            DDLogDebug("Event : Exception in URLAuthenticationChallenge - \(String(describing: exception))")
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

            DDLogDebug("Event : MainViewDelegate - \(String(describing: mainViewdelegate))")

            let response = task.response as? HTTPURLResponse

            let safeDict = StatusCodeDict.shared
            safeDict.setObject(key: "statusCodeForEvent", value: response?.statusCode ?? 0)

            DDLogDebug("Event : Response status - \(String(describing: response?.statusCode))")

            if error != nil {
                DDLogDebug("Event : NSURLSession connection error at eventsModel \(String(describing: error?.localizedDescription))")
                reset()
                if tvStatus == 1 {
                    self.mainViewdelegate?.eventFailureResponse(message: (error?.localizedDescription)!, isNetworkError: true)
                } else {
                    DDLogDebug("Event : No room is registered")
                }

            } else {
                if tvStatus == 1 {
                    if OngoingAPICallDict.shared.getValue(key: "Events") == false {
                        DDLogDebug("Event : Process Event Data")
                        OngoingAPICallDict.shared.setObject(key: "Events", value: true)
                        processEventResponseData()
                    } else {
                        DDLogDebug("Event : Ongoing event process available")
                        PendingAPICallRequestDict.shared.setObject(key: "Events", value: true)
                    }
                } else {
                    DDLogDebug("Event : No room is registered so not saving Event response")
                    reset()
                    OngoingAPICallDict.shared.setObject(key: "Events", value: false)
                }
            }
        } catch: { exception in
            DDLogDebug("Event : Exception in didCompleteWithError - \(String(describing: exception))")
            reset()
        }
    }

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
        SwiftTryCatch.try {
            if !data.isEmpty {
                eventListData.append(data)
                DDLogDebug("Event : Received Data Successfully")
            } else {
                DDLogDebug("Event : Received empty value on didReceive data at EventsModel")
            }
        } catch: { exception in
            DDLogDebug("Event : Exception in didReceive - \(String(describing: exception))")
        }
    }

    func processEventResponseData() {
        if managedObjectContext == nil {
            DDLogDebug("Weather : Error in processEventResponseData managedObjectContext is nil")
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
        SwiftTryCatch.try {
            if !eventListData.isEmpty {
                let jsonData = String(decoding: eventListData, as: UTF8.self)
                DDLogDebug("Event : Data - \(jsonData)")
                do {
                    DDLogDebug("Event : Parsing Json data from response")
                    let decoder = JSONDecoder()
                    let eventResponse = try decoder.decode(EventsResponseModel.self, from: eventListData)

                    DDLogDebug("Event : Event Json data - \(eventResponse)")

                    if eventResponse.status == "success" {
                        DataHandler().deleteRecords("Event", managedObjectContext)

                        managedObjectContext?.performAndWait {
                            event = NSEntityDescription.insertNewObject(forEntityName: "Event", into: managedObjectContext!) as? Event

                            event?.status = eventResponse.status
                            event?.titleName = eventResponse.titleName
                            event?.multiCalendar = eventResponse.multiCalendar ?? false

                            do {
                                try managedObjectContext?.save()
                                DDLogDebug("Event : Saved Event response in coredata")
                            } catch {
                                DDLogDebug("Event : Unable to save Event response in coredata")
                            }
                            DDLogDebug("Event : Event Data - \(String(describing: event))")
                        }

                        DataHandler().deleteRecords("EventList", managedObjectContext)

                        if !eventResponse.data[0].eventList.isEmpty {
                            for index in 0 ..< eventResponse.data[0].eventList.count {
                                managedObjectContext?.performAndWait {
                                    eventList = NSEntityDescription.insertNewObject(forEntityName: "EventList", into: managedObjectContext!) as? EventList
                                    eventList?.date = eventResponse.data[0].date
                                    eventList?.calendarName = eventResponse.data[0].eventList[index].calendarName
                                    eventList?.eventName = eventResponse.data[0].eventList[index].eventName
                                    eventList?.startTime = eventResponse.data[0].eventList[index].startTime
                                    eventList?.endTime = eventResponse.data[0].eventList[index].endTime
                                    eventList?.eventDescription = eventResponse.data[0].eventList[index].eventDescription

                                    do {
                                        try managedObjectContext?.save()
                                        DDLogDebug("Event : Saved EventList response in coredata")
                                    } catch {
                                        DDLogDebug("Event : Unable to save EventList response in coredata")
                                    }
                                    DDLogDebug("Event : Event List Data - \(String(describing: eventList))")
                                }
                            }

                        } else {
                            DDLogDebug("Event : EventList is empty")
                        }
                        DDLogDebug("Event : event fetching was successful")
                        reset()
                        self.mainViewdelegate?.eventsSuccessResponse()

                    } else {
                        DDLogDebug("Event : event fetching was unsuccessful")
                        reset()
                        self.mainViewdelegate?.eventFailureResponse(message: "Unable to fetch events!")
                    }
                } catch {
                    reset()
                    DDLogDebug("Event : parsing error at urlsession of eventsModel \(error)")
                    self.mainViewdelegate?.eventFailureResponse(message: error.localizedDescription)
                }
            } else {
                reset()
                DDLogDebug("Event : Received empty value on didcompleteWith Error data at EventsModel")
                self.mainViewdelegate?.eventFailureResponse(message: "Unable to fetch events!")
            }
        } catch: { exception in
            DDLogDebug("Event : Exception in processEventResponseData - \(String(describing: exception))")
        }
    }
}

// MARK: - EventsResponseModel

struct EventsResponseModel: Codable {
    var multiCalendar: Bool?
    var titleName: String
    var status: String
    var data: [EventsData]
}

// MARK: - EventsData

struct EventsData: Codable {
    var date: String
    var eventList: [EventsList]
}

// MARK: - EventsList

struct EventsList: Codable {
    var calendarName: String
    var eventName: String
    var startTime: String
    var endTime: String
    var eventDescription: String?
}
