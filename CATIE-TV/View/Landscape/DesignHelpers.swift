//
//  DesignHelpers.swift
//  CATIE-TV
//
//  Created by Admin on 24/04/19.
//  Copyright © 2019 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import os.log
import UIKit

// MARK: - AlertMessage

class AlertMessage: NSObject {
    func displayAlertMessage(onSource: UIViewController, alertMessage: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "", message: alertMessage, preferredStyle: UIAlertController.Style.alert)
            let action1 = UIAlertAction(title: "Ok", style: .default) { (_: UIAlertAction) in
                alert.dismiss(animated: true, completion: nil)
            }
            alert.addAction(action1)
            onSource.present(alert, animated: true, completion: nil)
            DDLogDebug("DesignHelpers : displayAlertMessage")
        }
    }
}

// MARK: - UIView customization (cornerRadius,shadowColor)

extension UIView {
    @IBInspectable var cornerRadius: CGFloat {
        get {
            layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
        }
    }

    @IBInspectable var borderWidth: CGFloat {
        get {
            layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
        }
    }

    @IBInspectable var borderColor: UIColor? {
        set {
            guard let uiColor = newValue else {
                return
            }

            layer.borderColor = uiColor.cgColor
        }
        get {
            guard let color = layer.borderColor else {
                return nil
            }

            return UIColor(cgColor: color)
        }
    }

    @IBInspectable var shadowColor: UIColor? {
        set {
            guard let uiColor = newValue else {
                return
            }

            layer.shadowColor = uiColor.cgColor
        }
        get {
            guard let color = layer.shadowColor else {
                return nil
            }

            return UIColor(cgColor: color)
        }
    }

    @IBInspectable var shadowOpacity: Float {
        set {
            layer.shadowOpacity = newValue
        }
        get {
            layer.shadowOpacity
        }
    }

    @IBInspectable var shadowOffset: CGSize {
        set {
            layer.shadowOffset = newValue
        }
        get {
            layer.shadowOffset
        }
    }

    @IBInspectable var shadowRadius: CGFloat {
        set {
            layer.shadowRadius = newValue
        }
        get {
            layer.shadowRadius
        }
    }

    @IBInspectable var updateShadow: Bool {
        set {
            layer.masksToBounds = false
            layer.shadowPath = UIBezierPath(rect: bounds).cgPath
            layer.shouldRasterize = true
            layer.rasterizationScale = UIScreen.main.scale
        }
        get {
            false
        }
    }

    func updateShadowColor(withColor: UIColor) {
        // DDLogDebug("DesignHelpers : updateShadowColor")
        layer.shadowColor = withColor.cgColor
    }

    func addGradientColor(startColor: UIColor, endColor: UIColor, startLocation: Double, endLocation: CGFloat) {
        // DDLogDebug("DesignHelpers : addGradientColor")
        let gradient = CAGradientLayer()
        gradient.frame = bounds
        gradient.locations = [startLocation as NSNumber, endLocation as NSNumber]
        gradient.colors = [startColor.cgColor, endColor.cgColor]
        gradient.startPoint = .init(x: 0.5, y: 0)
        gradient.endPoint = .init(x: 0.5, y: 1)
        gradient.cornerRadius = 7.0
        layer.insertSublayer(gradient, at: 0)
    }
}

// MARK: - GradientView

@IBDesignable
class GradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

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
        // DDLogDebug("DesignHelpers : GradientView Customization update Points")
        if horizontalMode {
            gradientLayer.startPoint = diagonalMode ? .init(x: 1, y: 0) : .init(x: 0, y: 0.5)
            gradientLayer.endPoint = diagonalMode ? .init(x: 0, y: 1) : .init(x: 1, y: 0.5)
        } else {
            gradientLayer.startPoint = diagonalMode ? .init(x: 0, y: 0) : .init(x: 0.5, y: 0)
            gradientLayer.endPoint = diagonalMode ? .init(x: 1, y: 1) : .init(x: 0.5, y: 1)
        }
    }

    func updateLocations() {
        // DDLogDebug("DesignHelpers : GradientView Customization update Locations")
        gradientLayer.locations = [startLocation as NSNumber, endLocation as NSNumber]
    }

    func updateColors() {
        // DDLogDebug("DesignHelpers : GradientView Customization update Colors")
        gradientLayer.colors = [startColor.cgColor, endColor.cgColor]
    }
}

// MARK: - UIColor extension to get the colors from rgb and hex code

extension UIColor {
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")

        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }

    convenience init(rgb: Int) {
        self.init(
            red: (rgb >> 16) & 0xFF,
            green: (rgb >> 8) & 0xFF,
            blue: rgb & 0xFF
        )
    }
}

// MAKR:- UILabel extension to draw the underline text
extension UILabel {
    func underline() {
        if let textString = text {
            let attributedString = NSMutableAttributedString(string: textString)
            attributedString.addAttribute(NSAttributedString.Key.underlineStyle,
                                          value: NSUnderlineStyle.single.rawValue,
                                          range: NSRange(location: 0, length: attributedString.length))
            attributedText = attributedString
        }
    }
}

// MARK: - String extension to get the trim the string and decoding the url

extension String {
    func trim() -> String {
        trimmingCharacters(in: NSCharacterSet.whitespaces)
    }
}

// MARK: - UIPageControl dot color customization

extension UIPageControl {
    func customPageControl(dotFillColor: UIColor, dotBorderColor: UIColor, dotBorderWidth: CGFloat, dotRadius: CGFloat) {
        if #available(iOS 14.0, *) { // iOS 14 have some changes on the page control dot view which is different than previous version, so adding handlings here specifically.
            if !self.subviews.isEmpty, !self.subviews[0].subviews.isEmpty {
                for (pageIndex, dotView) in self.subviews[0].subviews[0].subviews.enumerated() {
                    for dotView in self.subviews {
                        dotView.transform = CGAffineTransform(scaleX: 1.65, y: 1.65)
                    }
                    if self.currentPage == pageIndex {
                        dotView.backgroundColor = dotFillColor
                        dotView.layer.cornerRadius = dotRadius
                        dotView.layer.borderWidth = 0.0
                    } else {
                        dotView.backgroundColor = .clear
                        dotView.tintColor = .clear
                        dotView.layer.cornerRadius = dotRadius
                        dotView.layer.borderColor = dotBorderColor.cgColor
                        dotView.layer.borderWidth = dotBorderWidth
                    }
                }
            }

        } else {
            for (pageIndex, dotView) in subviews.enumerated() {
                if currentPage == pageIndex {
                    dotView.backgroundColor = dotFillColor
                    dotView.layer.cornerRadius = dotRadius
                    dotView.layer.borderWidth = 0.0
                } else {
                    dotView.backgroundColor = .clear
                    dotView.layer.cornerRadius = dotRadius
                    dotView.layer.borderColor = dotBorderColor.cgColor
                    dotView.layer.borderWidth = dotBorderWidth
                }
            }
        }
    }
}

/// Extension of UI font to add both the bold and italic style to text
extension UIFont {
    func with(_ traits: UIFontDescriptor.SymbolicTraits...) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(UIFontDescriptor.SymbolicTraits(traits).union(fontDescriptor.symbolicTraits)) else {
            return self
        }

        return UIFont(descriptor: descriptor, size: 0)
    }
}
