//
//  Carousal+CoreDataProperties.swift
//  CATIE-TV
//
//  Created by Karthick Perumal on 14/03/23.
//  Copyright © 2023 statusSolutions. All rights reserved.
//
//

import CoreData
import Foundation

public extension Carousal {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Carousal> {
        NSFetchRequest<Carousal>(entityName: "Carousal")
    }

    @NSManaged var status: String?
    @NSManaged var startTime: String?
    @NSManaged var endTime: String?
}
