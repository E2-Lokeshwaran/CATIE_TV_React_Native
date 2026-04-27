//
//  MultipleCalendarEventCell.swift
//  CATIE-TV
//
//  Created by Pavithran on 31/12/19.
//  Copyright © 2019 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import UIKit

@IBDesignable
class MultipleCalendarEventCell: UITableViewCell {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    @IBOutlet var eventStartTime: UILabel!
    @IBOutlet var eventName: UILabel!
    @IBOutlet var eventCalendar: UILabel!
    @IBOutlet var eventDescription: UILabel!

    @IBInspectable var startColor: UIColor = .black { didSet { updateColors() }}
    @IBInspectable var endColor: UIColor = .white { didSet { updateColors() }}
    @IBInspectable var startLocation: Double = 0.05 { didSet { updateLocations() }}
    @IBInspectable var endLocation: Double = 0.95 { didSet { updateLocations() }}
    @IBInspectable var horizontalMode: Bool = false { didSet { updatePoints() }}
    @IBInspectable var diagonalMode: Bool = false { didSet { updatePoints() }}

    var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePoints()
        updateLocations()
        updateColors()
    }

    func updatePoints() {
        SwiftTryCatch.try {
            if horizontalMode {
                // DDLogDebug("Event : MultipleCalendar Event Cell position points updated")
                gradientLayer.startPoint = diagonalMode ? .init(x: 1, y: 0) : .init(x: 0, y: 0.5)
                gradientLayer.endPoint = diagonalMode ? .init(x: 0, y: 1) : .init(x: 1, y: 0.5)
            } else {
                gradientLayer.startPoint = diagonalMode ? .init(x: 0, y: 0) : .init(x: 0.5, y: 0)
                gradientLayer.endPoint = diagonalMode ? .init(x: 1, y: 1) : .init(x: 0.5, y: 1)
            }
        } catch: { exception in
            DDLogDebug("MultipleCalendarEventCell : Exception in updatePoints - \(String(describing: exception))")
        }
    }

    func updateLocations() {
        SwiftTryCatch.try {
            // DDLogDebug("Event : MultipleCalendar Event Cell gradient location updated")
            gradientLayer.locations = [startLocation as NSNumber, endLocation as NSNumber]
        } catch: { exception in
            DDLogDebug("MultipleCalendarEventCell : Exception in updateLocations - \(String(describing: exception))")
        }
    }

    func updateColors() {
        SwiftTryCatch.try {
            // DDLogDebug("Event : MultipleCalendar Event Cell color updated")
            gradientLayer.colors = [startColor.cgColor, endColor.cgColor]
        } catch: { exception in
            DDLogDebug("MultipleCalendarEventCell : Exception in updateColors - \(String(describing: exception))")
        }
    }
}
