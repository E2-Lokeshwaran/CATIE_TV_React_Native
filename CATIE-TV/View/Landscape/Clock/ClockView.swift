//
//  ClockView.swift
//  UICAnalogClock
//
//  Created by Onur Işık on 20.03.2019.
//  Copyright © 2019 Onur Işık. All rights reserved.
//

import UIKit

class ClockViews: UIView {
    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        isOpaque = true
        backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    // MARK: Internal

    let hourLayer = CALayer()
    let minuteLayer = CALayer()
    let secondsLayer = CALayer()
    let minCircleLayer = CAShapeLayer()

    override func draw(_ rect: CGRect) {
        if hour == nil, minute == nil, second == nil {
            hour = cal.component(.hour, from: date)
            minute = cal.component(.minute, from: date)
            second = cal.component(.second, from: date)
        }

        drawBorderCircle(forRectangle: rect)
    }

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

    // static let clockSingleton = ClockViews()

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
                let font = UIFont(name: "Times New Roman", size: radius / 5)!

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

        let hourAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        hourAnimation.repeatCount = .infinity
        hourAnimation.duration = CFTimeInterval(60 * 60 * 12)
        hourAnimation.isRemovedOnCompletion = false
        hourAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        hourAnimation.fromValue = (hourAngle + 180.0) * CGFloat(Double.pi / 180.0)
        hourAnimation.byValue = 2 * Double.pi
        hourLayer.add(hourAnimation, forKey: "HourAnimationKey")

        minuteLayer.backgroundColor = UIColor.white.cgColor
        minuteLayer.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        minuteLayer.position = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        minuteLayer.bounds = CGRect(x: 0, y: 0, width: 18, height: mainLayer.frame.size.width * 0.37)
        minuteLayer.transform = CATransform3DMakeRotation(minuteAngle / CGFloat(180 * Double.pi), 0, 0, 1)
        minuteLayer.shouldRasterize = true
        minuteLayer.cornerRadius = 10
        minuteLayer.contentsScale = UIScreen.main.scale

        mainLayer.addSublayer(minuteLayer)

        let minutesAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        minutesAnimation.repeatCount = .infinity
        minutesAnimation.duration = CFTimeInterval(60 * 60)
        minutesAnimation.isRemovedOnCompletion = false
        minutesAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        minutesAnimation.fromValue = (minuteAngle + 180.0) * CGFloat(Double.pi / 180.0)
        minutesAnimation.byValue = 2 * Double.pi

        minuteLayer.add(minutesAnimation, forKey: "MinuteAnimationKey")

        secondsLayer.backgroundColor = UIColor.white.cgColor
        secondsLayer.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        secondsLayer.position = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        secondsLayer.bounds = CGRect(x: 0, y: 0, width: 8, height: mainLayer.frame.size.width * 0.38)
        secondsLayer.transform = CATransform3DMakeRotation(secondsAngle / CGFloat(180 * Double.pi), 0, 0, 1)
        secondsLayer.shouldRasterize = true
        secondsLayer.contentsScale = UIScreen.main.scale
        secondsLayer.cornerRadius = 5
        mainLayer.addSublayer(secondsLayer)

        let secondsAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        secondsAnimation.repeatCount = .infinity
        secondsAnimation.duration = CFTimeInterval(60)
        secondsAnimation.isRemovedOnCompletion = false
        secondsAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        secondsAnimation.fromValue = (secondsAngle + 180.0) * CGFloat(Double.pi / 180.0)
        secondsAnimation.byValue = 2 * Double.pi
        secondsLayer.add(secondsAnimation, forKey: "SecondAnimationKey")

        let radiusForMinCircle: CGFloat = radius / 10
        minCircleLayer.path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: radiusForMinCircle, height: radiusForMinCircle), cornerRadius: radius).cgPath
        minCircleLayer.position = CGPoint(x: x - radiusForMinCircle / 2, y: y - radiusForMinCircle / 2)
        minCircleLayer.shadowOpacity = 0.8
        minCircleLayer.fillColor = UIColor.white.cgColor
        mainLayer.addSublayer(minCircleLayer)

        //        let bounds = radius / 10
        //        context.setFillColor(UIColor.red.cgColor)
        //        context.fillEllipse(in: CGRect(x: x - bounds / 2, y: y - bounds / 2, width: bounds, height: bounds))
    }

    fileprivate func drawBorderCircle(forRectangle: CGRect) {
        let context = UIGraphicsGetCurrentContext()!

        let radius = forRectangle.width / 2.4
//        let endAngle = CGFloat(Double.pi * 2)
//        let centerPoint = CGPoint(x: forRectangle.midX, y: forRectangle.midY)
//        context.addArc(center: centerPoint, radius: radius, startAngle: 0, endAngle: endAngle, clockwise: true)
//        context.setFillColor(UIColor.lightGray.cgColor)
//        context.setStrokeColor(UIColor.white.cgColor)
//        context.setLineWidth(4.0)
//        context.drawPath(using: .fillStroke)

//        let clockColor = UIColor.white
//        let clockColorWithAlpha = clockColor.withAlphaComponent(0.8)

//
        drawSecondsMarker(context: context, x: forRectangle.midX, y: forRectangle.midY, radius: radius, sides: 60, color: .white)

        drawNumbers(rect: forRectangle, context: context, x: forRectangle.midX, y: forRectangle.midY, radius: radius + 15, sides: 12, color: .white)

        drawHands(rect: forRectangle, context: context, x: forRectangle.midX, y: forRectangle.midY, radius: radius)
    }

    // MARK: Private

    private let date = Date()
    private let cal = Calendar.current
    private var hour: Int!
    private var minute: Int!
    private var second: Int!
}
