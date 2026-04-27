//
//  SiteLogo+CoreDataProperties.swift
//  CATIE-TV
//
//  Created by Karthick Perumal on 10/03/23.
//  Copyright © 2023 statusSolutions. All rights reserved.
//
//

import CoreData
import Foundation

public extension SiteLogo {
    @nonobjc class func fetchRequest() -> NSFetchRequest<SiteLogo> {
        NSFetchRequest<SiteLogo>(entityName: "SiteLogo")
    }

    @NSManaged var imageData: Data?
    @NSManaged var imageName: String?
}
