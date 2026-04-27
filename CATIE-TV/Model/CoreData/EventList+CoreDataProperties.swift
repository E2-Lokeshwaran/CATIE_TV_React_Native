//
//  EventList+CoreDataProperties.swift
//  CATIE-TV
//
//  Created by Karthick Perumal on 14/03/23.
//  Copyright © 2023 statusSolutions. All rights reserved.
//
//

import CoreData
import Foundation

public extension EventList {
    @nonobjc class func fetchRequest() -> NSFetchRequest<EventList> {
        NSFetchRequest<EventList>(entityName: "EventList")
    }

    @NSManaged var date: String?
    @NSManaged var calendarName: String?
    @NSManaged var eventName: String?
    @NSManaged var startTime: String?
    @NSManaged var endTime: String?
    @NSManaged var eventDescription: String?
}
