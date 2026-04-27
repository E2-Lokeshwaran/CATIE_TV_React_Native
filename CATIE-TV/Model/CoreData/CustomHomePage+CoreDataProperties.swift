//
//  CustomHomePage+CoreDataProperties.swift
//  CATIE-TV
//
//  Created by Harish on 29/07/25.
//  Copyright © 2025 statusSolutions. All rights reserved.
//
//

import CoreData
import Foundation

public extension CustomHomePage {
    @nonobjc class func fetchRequest() -> NSFetchRequest<CustomHomePage> {
        NSFetchRequest<CustomHomePage>(entityName: "CustomHomePage")
    }

    @NSManaged var catieTvFontColor: String?
    @NSManaged var catieTvFontSize: String?
    @NSManaged var catieTvFontType: String?
    @NSManaged var catieTvType: Int16
    @NSManaged var status: String?
    @NSManaged var tvStatus: Int16
    @NSManaged var tvRadioFlag: Int16
}

extension CustomHomePage: Identifiable {}
