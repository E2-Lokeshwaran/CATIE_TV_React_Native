//
//  DataHandler.swift
//  CATIE-TV
//
//  Created by Karthick on 30/06/23.
//  Copyright © 2023 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import CoreData
import Foundation

class DataHandler: NSObject {
    func deleteRecords(_ entityName: String?, _ managedObjectContext: NSManagedObjectContext?) {
        SwiftTryCatch.try {
            DDLogDebug("DataHandler : Delete Records Called for the \(String(describing: entityName)) model")

            managedObjectContext?.performAndWait {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
                fetchRequest.entity = NSEntityDescription.entity(forEntityName: entityName!, in: managedObjectContext!)
                // fetchRequest.includesPropertyValues = false //only fetch the managedObjectID
                var rows: [Any]? = nil
                do {
                    rows = try managedObjectContext?.fetch(fetchRequest)
                } catch {
                    DDLogDebug("DataHandler : Exception in \(String(describing: entityName)) records fetching - \(String(describing: error))")
                }

                if rows?.isEmpty != true {
                    for eachrow in rows! {
                        managedObjectContext?.delete(eachrow as! NSManagedObject)
                    }

                    do {
                        try managedObjectContext?.save()
                        DDLogDebug("DataHandler : Existing \(String(describing: entityName)) records deleted succesfully")
                    } catch {
                        DDLogDebug("DataHandler : Exception in \(String(describing: entityName)) records deletion - \(String(describing: error))")
                    }

                } else {
                    DDLogDebug("DataHandler : No records of \(String(describing: entityName)) available in local storage")
                }
            }

        } catch: { exception in
            DDLogDebug("DataHandler : Exception in \(String(describing: entityName)) records deletion -  \(String(describing: exception))")
        }
    }

    func fetchData(_ entityName: String, _ managedObjectContext: NSManagedObjectContext?) -> [Any]? {
        var rows: [Any]? = nil
        SwiftTryCatch.try {
            DDLogDebug("DataHandler : Fetch Records Called for the \(String(describing: entityName)) model")

            managedObjectContext?.performAndWait {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
                fetchRequest.entity = NSEntityDescription.entity(forEntityName: entityName, in: managedObjectContext!)
                //            fetchRequest.includesPropertyValues = false //only fetch the managedObjectID
                fetchRequest.returnsObjectsAsFaults = false
                do {
                    rows = try (managedObjectContext)?.fetch(fetchRequest)

                } catch {
                    DDLogDebug("DataHandler : Exception in Fetching \(entityName) details - \(String(describing: error))")
                }
                if !(rows?.isEmpty ?? true) {
                    DDLogDebug("DataHandler : Fetching \(entityName) data successfully - \(String(describing: rows))")
                } else {
                    DDLogDebug("DataHandler : No \(entityName) data available in local storage")
                }
            }

        } catch: { exception in
            DDLogDebug("DataHandler : Exception in \(String(describing: entityName)) Fetching records -  \(String(describing: exception))")
        }
        return rows ?? []
    }
}
