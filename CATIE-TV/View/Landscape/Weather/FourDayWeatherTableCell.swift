//
//  FourDayWeatherTableCell.swift
//  CATIE-TV
//
//  Created by Pavithran on 23/12/19.
//  Copyright © 2019 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import UIKit

@IBDesignable
class FourDayWeatherTableCell: UITableViewCell {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    @IBOutlet var fourDayWeatherDay: UILabel!
    @IBOutlet var fourDayWeatherIcon: UIImageView!
    @IBOutlet var fourDayWeatherTemp: UILabel!
    @IBOutlet var fourDayWeatherDesc: UILabel!

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
            // DDLogDebug("Weather : FourDay Weather Cell position points updated")
            if horizontalMode {
                gradientLayer.startPoint = diagonalMode ? .init(x: 1, y: 0) : .init(x: 0, y: 0.5)
                gradientLayer.endPoint = diagonalMode ? .init(x: 0, y: 1) : .init(x: 1, y: 0.5)
            } else {
                gradientLayer.startPoint = diagonalMode ? .init(x: 0, y: 0) : .init(x: 0.5, y: 0)
                gradientLayer.endPoint = diagonalMode ? .init(x: 1, y: 1) : .init(x: 0.5, y: 1)
            }
        } catch: { exception in
            DDLogDebug("FourDayWeatherTableCell : Exception in updatePoints - \(String(describing: exception))")
        }
    }

    func updateLocations() {
        SwiftTryCatch.try {
            // DDLogDebug("Weather : FourDay Weather Cell gradient location updated")
            gradientLayer.locations = [startLocation as NSNumber, endLocation as NSNumber]
        } catch: { exception in
            DDLogDebug("FourDayWeatherTableCell : Exception in updateLocations - \(String(describing: exception))")
        }
    }

    func updateColors() {
        SwiftTryCatch.try {
            // DDLogDebug("Weather : FourDay Weather Cell color updated")
            gradientLayer.colors = [startColor.cgColor, endColor.cgColor]
        } catch: { exception in
            DDLogDebug("FourDayWeatherTableCell : Exception in updateColors - \(String(describing: exception))")
        }
    }
}
