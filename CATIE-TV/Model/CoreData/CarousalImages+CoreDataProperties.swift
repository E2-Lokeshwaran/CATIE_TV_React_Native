//
//  CarousalImages+CoreDataProperties.swift
//  CATIE-TV
//
//  Created by Harish on 03/03/25.
//  Copyright © 2025 statusSolutions. All rights reserved.
//
//

import CoreData
import Foundation

public extension CarousalImages {
    @nonobjc class func fetchRequest() -> NSFetchRequest<CarousalImages> {
        NSFetchRequest<CarousalImages>(entityName: "CarousalImages")
    }

    @NSManaged var carousalImage: Data?
    @NSManaged var carouselType: Int16
    @NSManaged var imageName: String?
    @NSManaged var slotTime: Int16
    @NSManaged var audioPath: String?
}

extension CarousalImages: Identifiable {}
