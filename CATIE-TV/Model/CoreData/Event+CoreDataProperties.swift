//
//  Event+CoreDataProperties.swift
//  CATIE-TV
//
//  Created by Karthick Perumal on 14/03/23.
//  Copyright © 2023 statusSolutions. All rights reserved.
//
//

import CoreData
import Foundation

public extension Event {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Event> {
        NSFetchRequest<Event>(entityName: "Event")
    }

    @NSManaged var status: String?
    @NSManaged var titleName: String?
    @NSManaged var multiCalendar: Bool
}
