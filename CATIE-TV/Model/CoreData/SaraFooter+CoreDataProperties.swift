//
//  SaraFooter+CoreDataProperties.swift
//  CATIE-TV
//
//  Created by Karthick Perumal on 16/03/23.
//  Copyright © 2023 statusSolutions. All rights reserved.
//
//

import CoreData
import Foundation

public extension SaraFooter {
    @nonobjc class func fetchRequest() -> NSFetchRequest<SaraFooter> {
        NSFetchRequest<SaraFooter>(entityName: "SaraFooter")
    }

    @NSManaged var footerText: String?
    @NSManaged var width: String?
    @NSManaged var height: String?
    @NSManaged var margin: String?
    @NSManaged var color: String?
    @NSManaged var textAlign: String?
    @NSManaged var border: String?
    @NSManaged var borderColor: String?
    @NSManaged var fontSize: String?
    @NSManaged var backgroundColor: String?
    @NSManaged var fontStyle: String?
    @NSManaged var fontWeight: String?
}
