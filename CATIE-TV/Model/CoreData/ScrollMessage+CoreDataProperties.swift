//
//  ScrollMessage+CoreDataProperties.swift
//  CATIE-TV
//
//  Created by Karthick Perumal on 15/03/23.
//  Copyright © 2023 statusSolutions. All rights reserved.
//
//

import CoreData
import Foundation

public extension ScrollMessage {
    @nonobjc class func fetchRequest() -> NSFetchRequest<ScrollMessage> {
        NSFetchRequest<ScrollMessage>(entityName: "ScrollMessage")
    }

    @NSManaged var messageDescription: String?
}
