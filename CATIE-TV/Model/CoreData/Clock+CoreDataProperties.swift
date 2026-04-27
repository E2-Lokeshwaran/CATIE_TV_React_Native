//
//  Clock+CoreDataProperties.swift
//  CATIE-TV
//
//  Created by Karthick Perumal on 15/03/23.
//  Copyright © 2023 statusSolutions. All rights reserved.
//
//

import CoreData
import Foundation

public extension Clock {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Clock> {
        NSFetchRequest<Clock>(entityName: "Clock")
    }

    @NSManaged var status: String?
    @NSManaged var statusFlag: Int16
    @NSManaged var message: String?
    @NSManaged var startTime: String?
    @NSManaged var endTime: String?
}
