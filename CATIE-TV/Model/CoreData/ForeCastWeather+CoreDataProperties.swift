//
//  ForeCastWeather+CoreDataProperties.swift
//  CATIE-TV
//
//  Created by Karthick Perumal on 10/03/23.
//  Copyright © 2023 statusSolutions. All rights reserved.
//
//

import CoreData
import Foundation

public extension ForeCastWeather {
    @nonobjc class func fetchRequest() -> NSFetchRequest<ForeCastWeather> {
        NSFetchRequest<ForeCastWeather>(entityName: "ForeCastWeather")
    }

    @NSManaged var day: String?
    @NSManaged var des: String?
    @NSManaged var high: String?
    @NSManaged var low: String?
    @NSManaged var weatherIcons: Data?
}
