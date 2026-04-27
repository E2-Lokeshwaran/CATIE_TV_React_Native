//
//  Weather+CoreDataProperties.swift
//  CATIE-TV
//
//  Created by Karthick Perumal on 10/03/23.
//  Copyright © 2023 statusSolutions. All rights reserved.
//
//

import CoreData
import Foundation

public extension Weather {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Weather> {
        NSFetchRequest<Weather>(entityName: "Weather")
    }

    @NSManaged var city: String?
    @NSManaged var date: String?
    @NSManaged var status: String?
    @NSManaged var temperature: String?
    @NSManaged var temperatureText: String?
    @NSManaged var weatherIcon: Data?
    @NSManaged var webSource: String?
}
