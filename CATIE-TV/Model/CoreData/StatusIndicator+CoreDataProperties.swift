//
//  StatusIndicator+CoreDataProperties.swift
//  CATIE-TV
//
//  Created by Karthick Perumal on 14/03/23.
//  Copyright © 2023 statusSolutions. All rights reserved.
//
//

import CoreData
import Foundation

public extension StatusIndicator {
    @nonobjc class func fetchRequest() -> NSFetchRequest<StatusIndicator> {
        NSFetchRequest<StatusIndicator>(entityName: "StatusIndicator")
    }

    @NSManaged var status: String?
    @NSManaged var statusName: String?
    @NSManaged var statusFlag: Int16
    @NSManaged var message: String?
}
