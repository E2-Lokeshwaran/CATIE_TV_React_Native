//
//  Radio+CoreDataProperties.swift
//  CATIE-TV
//
//  Created by Karthick Perumal on 14/03/23.
//  Copyright © 2023 statusSolutions. All rights reserved.
//
//

import CoreData
import Foundation

public extension Radio {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Radio> {
        NSFetchRequest<Radio>(entityName: "Radio")
    }

    @NSManaged var status: String?
    @NSManaged var radioFeed: String?
    @NSManaged var playingStatus: Int16
}
