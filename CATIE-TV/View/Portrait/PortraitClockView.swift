//
//  PortraitClockView.swift
//  CATIE-TV
//
//  Created by Harish on 30/04/25.
//  Copyright © 2025 statusSolutions. All rights reserved.
//

import SwiftUI
import UIKit

// MARK: - PortraitClockView

struct PortraitClockView: View {
    /// Message to display beneath the clock
    var message: String

    /// Font for the message text
    var customFontName: String = "Poppins-Bold"

    /// Font size for the message text
    var customFontSize: CGFloat = 100

    /// Whether the clock should be visible
    var isVisible: Bool = true

    /// Whether a Sara Alert is being presented (used to determine if clock should be hidden)
    var isSaraAlertPresented: Bool = false

    // MARK: - Body

    var body: some View {
        Group {
            if isVisible, !isSaraAlertPresented {
                GeometryReader { geometry in
                    ZStack {
                        // Background
                        Color.black
                            .opacity(0.9)
                            .edgesIgnoringSafeArea(.all)
                            .accessibilityIdentifier("clockBackground")

                        VStack(spacing: 0) {
                            // Efficient UIKit clock implementation wrapped for SwiftUI
                            UIKitClockWrapper()
                                .frame(
                                    width: min(geometry.size.width * 0.9, geometry.size.height * 0.6),
                                    height: min(geometry.size.width * 0.9, geometry.size.height * 0.6)
                                )
                                .padding(.bottom, 40)
                                .accessibilityIdentifier("clockFace")

                            // Message text
                            Text(message)
                                .font(.custom(customFontName, size: min(customFontSize, geometry.size.width * 0.07)))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 40)
                                .frame(maxWidth: geometry.size.width * 0.9)
                                .accessibilityIdentifier("clockMessage")
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .accessibilityIdentifier("clockContentContainer")
                    }
                    .accessibilityIdentifier("clockZStack")
                }
                .accessibilityIdentifier("clockGeometryReader")
                .transition(.opacity)
            }
        }

        .animation(.default, value: isVisible)
        .frame(width: UIScreen.main.bounds.height, height: UIScreen.main.bounds.width)
        // Use an ID to ensure the view is recreated when visibility changes
        .id("ClockOverlay_\(isVisible)_\(isSaraAlertPresented)")
        .accessibilityIdentifier("portraitClockView")
    }
}

// MARK: - UIKitClockWrapper

/// SwiftUI wrapper for the efficient UIKit clock implementation
struct UIKitClockWrapper: UIViewRepresentable {
    func makeUIView(context _: Context) -> ClockViews2 {
        ClockViews2(frame: .zero)
    }

    func updateUIView(_: ClockViews2, context _: Context) {
        // No update needed as the ClockViews handles its own animation
    }
}

// MARK: - ClockViews2

/// The original UIKit implementation that uses only 2% CPU
class ClockViews2: UIView {
    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        isOpaque = true
        backgroundColor = .clear

        // Initialize time components once
        hour = cal.component(.hour, from: date)
        minute = cal.component(.minute, from: date)
        second = cal.component(.second, from: date)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    // MARK: Internal

    let hourLayer = CALayer()
    let minuteLayer = CALayer()
    let secondsLayer = CALayer()
    let minCircleLayer = CAShapeLayer()

    // MARK: Drawing

    override func draw(_ rect: CGRect) {
        drawBorderCircle(forRectangle: rect)
    }

    // MARK: Helper Methods

    func circleCircumferencePoints(sides: Int, x: CGFloat, y: CGFloat, radius: CGFloat, adjustment: CGFloat = 0) -> [CGPoint] {
        let angle = degreeToRadian(degree: 360 / CGFloat(sides))
        let cx = x // x origin
        let cy = y // y origin
        let r = radius // radius of circle
        var i = sides
        var points = [CGPoint]()
        while points.count <= sides {
            let xpo = cx - r * cos(angle * CGFloat(i) + degreeToRadian(degree: adjustment))
            let ypo = cy - r * sin(angle * CGFloat(i) + degreeToRadian(degree: adjustment))
            points.append(CGPoint(x: xpo, y: ypo))
            i -= 1
        }
        return points
    }

    // MARK: Fileprivate

    fileprivate func degreeToRadian(degree: CGFloat) -> CGFloat {
        CGFloat(Double.pi) * degree / 180
    }

    fileprivate func drawSecondsMarker(context _: CGContext, x: CGFloat, y: CGFloat, radius: CGFloat, sides: Int, color: UIColor) {
        let points = circleCircumferencePoints(sides: sides, x: x, y: y, radius: radius)
        let pointsIN = circleCircumferencePoints(sides: sides, x: x, y: y, radius: radius - 4)

        let path = UIBezierPath()
        let pathOut = UIBezierPath()

        let shapeLayerIN = CAShapeLayer()
        let shapeLayerOut = CAShapeLayer()
        var divider: CGFloat = 1 / 16

        for (index, point) in points.enumerated() {
            // Seconds Marker with thick lineWidth
            if index % 5 == 0 {
                divider = 1 / 14
                let xn = point.x + divider * (x - point.x)
                let yn = point.y + divider * (y - point.y)

                path.move(to: CGPoint(x: point.x - 1.1, y: point.y))
                path.addLine(to: CGPoint(x: xn, y: yn))

                shapeLayerIN.strokeColor = color.cgColor
                shapeLayerIN.path = path.cgPath
                shapeLayerIN.lineWidth = 16
                shapeLayerIN.lineCap = .round

                layer.addSublayer(shapeLayerIN)
            }
        }

        for (index, point) in pointsIN.enumerated() {
            // Seconds Marker with thin lineWidth
            if index % 5 != 0 {
                divider = 1 / 26
                let xnn = point.x + divider * (x - point.x)
                let ynn = point.y + divider * (y - point.y)

                pathOut.move(to: CGPoint(x: point.x - 1.1, y: point.y))
                pathOut.addLine(to: CGPoint(x: xnn, y: ynn))

                shapeLayerOut.strokeColor = color.cgColor
                shapeLayerOut.path = pathOut.cgPath
                shapeLayerOut.lineWidth = 6
                shapeLayerOut.lineCap = .round

                layer.addSublayer(shapeLayerOut)
            }
        }
    }

    fileprivate func drawNumbers(rect: CGRect, context: CGContext, x: CGFloat, y: CGFloat, radius: CGFloat, sides: Int, color _: UIColor) {
        context.translateBy(x: 0, y: rect.height)
        context.scaleBy(x: 1.0, y: -1.0)

        let inset: CGFloat = radius / 4.2
        let points = circleCircumferencePoints(sides: sides, x: x, y: y, radius: radius - inset, adjustment: 270)

        for (index, point) in points.enumerated() {
            if index > 0 {
                let font = UIFont(name: "Poppins-Medium", size: radius / 5)!
                let attributes = [NSAttributedString.Key.font: font, NSAttributedString.Key.foregroundColor: UIColor.white]
                let attributedString = NSAttributedString(string: index.description, attributes: attributes)
                let line = CTLineCreateWithAttributedString(attributedString)
                let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

                context.setLineWidth(1)
                context.setTextDrawingMode(.fill)

                let xn = point.x - bounds.width / 2
                let yn = point.y - bounds.midY

                context.textPosition = CGPoint(x: xn, y: yn)
                CTLineDraw(line, context)
            }
        }
    }

    fileprivate func drawHands(rect: CGRect, context _: CGContext, x: CGFloat, y: CGFloat, radius: CGFloat) {
        let hourAngle = CGFloat(hour * (360 / 12)) + CGFloat(minute) * (1.0 / 60) * (360 / 12)
        let minuteAngle = CGFloat(minute * (360 / 60))
        let secondsAngle = CGFloat(second * (360 / 60))

        let mainLayer = CALayer()
        mainLayer.frame = rect

        // Hour hand setup
        hourLayer.backgroundColor = UIColor.white.cgColor
        hourLayer.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        hourLayer.position = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        hourLayer.bounds = CGRect(x: 0, y: 0, width: 30, height: mainLayer.frame.size.width * 0.30)
        hourLayer.transform = CATransform3DMakeRotation(hourAngle / CGFloat(180 * Double.pi), 0, 0, 1)
        hourLayer.shouldRasterize = true
        hourLayer.contentsScale = UIScreen.main.scale
        hourLayer.cornerRadius = 15
        mainLayer.addSublayer(hourLayer)
        layer.addSublayer(mainLayer)

        // Hour animation
        let hourAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        hourAnimation.repeatCount = .infinity
        hourAnimation.duration = CFTimeInterval(60 * 60 * 12)
        hourAnimation.isRemovedOnCompletion = false
        hourAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        hourAnimation.fromValue = (hourAngle + 180.0) * CGFloat(Double.pi / 180.0)
        hourAnimation.byValue = 2 * Double.pi
        hourLayer.add(hourAnimation, forKey: "HourAnimationKey")

        // Minute hand setup
        minuteLayer.backgroundColor = UIColor.white.cgColor
        minuteLayer.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        minuteLayer.position = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        minuteLayer.bounds = CGRect(x: 0, y: 0, width: 18, height: mainLayer.frame.size.width * 0.37)
        minuteLayer.transform = CATransform3DMakeRotation(minuteAngle / CGFloat(180 * Double.pi), 0, 0, 1)
        minuteLayer.shouldRasterize = true
        minuteLayer.cornerRadius = 10
        minuteLayer.contentsScale = UIScreen.main.scale
        mainLayer.addSublayer(minuteLayer)

        // Minute animation
        let minutesAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        minutesAnimation.repeatCount = .infinity
        minutesAnimation.duration = CFTimeInterval(60 * 60)
        minutesAnimation.isRemovedOnCompletion = false
        minutesAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        minutesAnimation.fromValue = (minuteAngle + 180.0) * CGFloat(Double.pi / 180.0)
        minutesAnimation.byValue = 2 * Double.pi
        minuteLayer.add(minutesAnimation, forKey: "MinuteAnimationKey")

        // Second hand setup
        secondsLayer.backgroundColor = UIColor.white.cgColor
        secondsLayer.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        secondsLayer.position = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        secondsLayer.bounds = CGRect(x: 0, y: 0, width: 8, height: mainLayer.frame.size.width * 0.38)
        secondsLayer.transform = CATransform3DMakeRotation(secondsAngle / CGFloat(180 * Double.pi), 0, 0, 1)
        secondsLayer.shouldRasterize = true
        secondsLayer.contentsScale = UIScreen.main.scale
        secondsLayer.cornerRadius = 5
        mainLayer.addSublayer(secondsLayer)

        // Second animation
        let secondsAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        secondsAnimation.repeatCount = .infinity
        secondsAnimation.duration = CFTimeInterval(60)
        secondsAnimation.isRemovedOnCompletion = false
        secondsAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        secondsAnimation.fromValue = (secondsAngle + 180.0) * CGFloat(Double.pi / 180.0)
        secondsAnimation.byValue = 2 * Double.pi
        secondsLayer.add(secondsAnimation, forKey: "SecondAnimationKey")

        // Center circle
        let radiusForMinCircle: CGFloat = radius / 10
        minCircleLayer.path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: radiusForMinCircle, height: radiusForMinCircle), cornerRadius: radius).cgPath
        minCircleLayer.position = CGPoint(x: x - radiusForMinCircle / 2, y: y - radiusForMinCircle / 2)
        minCircleLayer.shadowOpacity = 0.8
        minCircleLayer.fillColor = UIColor.white.cgColor
        mainLayer.addSublayer(minCircleLayer)
    }

    fileprivate func drawBorderCircle(forRectangle: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        let radius = forRectangle.width / 2.4

        // Draw tick marks
        drawSecondsMarker(context: context, x: forRectangle.midX, y: forRectangle.midY, radius: radius, sides: 60, color: .white)

        // Draw hour numbers
        drawNumbers(rect: forRectangle, context: context, x: forRectangle.midX, y: forRectangle.midY, radius: radius + 15, sides: 12, color: .white)

        // Draw hands
        drawHands(rect: forRectangle, context: context, x: forRectangle.midX, y: forRectangle.midY, radius: radius)
    }

    // MARK: Private

    private let date = Date()
    private let cal = Calendar.current
    private var hour: Int!
    private var minute: Int!
    private var second: Int!
}

// MARK: - Preview

#if DEBUG
    struct PortraitClockView_Previews: PreviewProvider {
        static var previews: some View {
            PortraitClockView(
                message: "This is a system\ngenerated mail.\nPlease do not send\nreply email.",
                isVisible: true
            )
            // Preview in vertical orientation to simulate the rotated view
            .rotationEffect(.degrees(90)) // rotate the view 90°
            .previewLayout(.fixed(width: 1080, height: 1920)) // swapped dimensions
        }
    }
#endif
