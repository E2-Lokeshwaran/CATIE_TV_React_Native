//
//  DetailedWeather+CoreDataProperties.swift
//  CATIE-TV
//
//  Created by Karthick Perumal on 10/03/23.
//  Copyright © 2023 statusSolutions. All rights reserved.
//
//

import CoreData
import Foundation

public extension DetailedWeather {
    @nonobjc class func fetchRequest() -> NSFetchRequest<DetailedWeather> {
        NSFetchRequest<DetailedWeather>(entityName: "DetailedWeather")
    }

    @NSManaged var currentDayHigh: String?
    @NSManaged var currentDayLow: String?
    @NSManaged var feelsLike: String?
    @NSManaged var humidity: String?
    @NSManaged var pressure: String?
    @NSManaged var sunRise: String?
    @NSManaged var sunSet: String?
    @NSManaged var visibilty: String?
    @NSManaged var wind: String?
}
