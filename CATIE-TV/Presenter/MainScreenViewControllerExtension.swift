//
//  MainScreenViewControllerExtension.swift
//  CATIE-TV
//
//  Created by Pavithran on 24/12/19.
//  Copyright © 2019 statusSolutions. All rights reserved.
//

import AVKit
import CocoaLumberjackSwift
import CoreData
import SwiftUI
import UIKit

// Main view controller extension class that used to handle few events / UI from main view page..

// MARK: Main view screen extension

extension MainScreenViewController {
    // MARK: - Layout design functions

    override open func traitCollectionDidChange(_: UITraitCollection?) {
        SwiftTryCatch.try {
            DDLogDebug("MainscreenExtension :TraitSet Color change occurred please revisit the color models")

            // Views shadow color using cg color property which will be changed automatically when appearance changes so resetting the shadow color property every time.

            headerView?.updateShadowColor(withColor: UIColor(named: "Header_Shadow")!)
            carousalShadowView?.updateShadowColor(withColor: UIColor(named: "Header_Shadow")!)
            footerView?.updateShadowColor(withColor: UIColor(named: "Header_Shadow")!)
            detailedWeatherTable?.reloadData()
            fourDayWeatherTable?.reloadData()
            statusIndicatorCollectionView?.reloadData()
            eventListTable?.reloadData()
            StatusIndicatorPageControl.customPageControl(dotFillColor: UIColor(named: "StatusSelectedPagingEnd")!, dotBorderColor: UIColor(named: "StatusPagingColor")!, dotBorderWidth: 1.0, dotRadius: 5)
        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in traitCollectionDidChange - \(String(describing: exception))")
        }
    }

    func adjustMainScreenLayout() {
        SwiftTryCatch.try {
            // DDLogDebug("MainscreenExtension : Adjust Main Screen Layout")
            detailedWeatherTable?.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)
            fourDayWeatherTable?.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)
            eventListTable?.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)
            statusIndicatorCollectionView?.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in adjustMainScreenLayout - \(String(describing: exception))")
        }
    }

    func adjustStatusIndicatorPageControl(withCurrentPage: Int, andNumberOfPage: Int) {
        SwiftTryCatch.try {
            // DDLogDebug("MainscreenExtension : Adjust Status Indicator Page Control")
            StatusIndicatorPageControl.removeFromSuperview()
            StatusIndicatorPageControl = UIPageControl()
            StatusIndicatorPageControl = UIPageControl(frame: CGRect(x: 0, y: -5, width: StatusIndicatorPageControlSuperView?.frame.width ?? 0, height: (StatusIndicatorPageControlSuperView?.frame.height ?? 0) + 5))
            StatusIndicatorPageControl.isUserInteractionEnabled = false
            StatusIndicatorPageControl.hidesForSinglePage = true

            StatusIndicatorPageControl.numberOfPages = andNumberOfPage
            StatusIndicatorPageControl.currentPage = withCurrentPage

            for subview in StatusIndicatorPageControl.subviews {
                if subview is UIVisualEffectView { // removing default page control background blur effect view to make it transparent.
                    subview.removeFromSuperview()
                }
                else // From iOS 14 the page control blur effect view hierarchy has changed quite a bit, so checking and handling it separately.
                {
                    DDLogDebug("MainscreenExtension : StatusIndicatorPageControl subviews count - \(StatusIndicatorPageControl.subviews.count)")

                    if !StatusIndicatorPageControl.subviews.isEmpty {
                        for subview in StatusIndicatorPageControl.subviews[0].subviews {
                            if subview is UIVisualEffectView {
                                subview.removeFromSuperview()
                            }
                        }
                    }

                    if #available(tvOS 14.0, *) {
                        StatusIndicatorPageControl.currentPageIndicatorTintColor = UIColor(named: "StatusSelectedPagingEnd")!
                    }
                }
            }

            StatusIndicatorPageControlSuperView?.addSubview(StatusIndicatorPageControl)
            for subview in StatusIndicatorPageControl.subviews {
                subview.transform = CGAffineTransform(scaleX: 1.8, y: 1.8)
            }
            StatusIndicatorPageControl.customPageControl(dotFillColor: UIColor(named: "StatusSelectedPagingEnd")!, dotBorderColor: UIColor(named: "StatusPagingColor")!, dotBorderWidth: 1.0, dotRadius: 5)
        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in adjustStatusIndicatorPageControl - \(String(describing: exception))")
        }
    }

    func removeGradientLayer(fromView: UIView) {
        SwiftTryCatch.try {
            // DDLogDebug("MainscreenExtension : Remove Gradient Layer")
            if fromView.layer.sublayers?.count ?? 0 > 0 { // removing added gradient layer view because of cell reusable property
                for subLayer in fromView.layer.sublayers ?? [CALayer()] {
                    if subLayer is CAGradientLayer {
                        subLayer.removeFromSuperlayer()
                    }
                }
            }
        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in removeGradientLayer - \(String(describing: exception))")
        }
    }

    // MARK: - Scrolling message view

    func setScrollableView() {
        SwiftTryCatch.try {
            // DDLogDebug("MainscreenExtension : Set Scrollable View")
            if scrollableTextLabel != nil {
                scrollableTextLabel?.removeFromSuperview()
                scrollableTextLabel = nil
            }

            scrollbarTimer?.invalidate()

            scrollableTextLabel = UILabel(frame: CGRect(x: 0, y: 0, width: scrollableTextView?.frame.width ?? 0, height: scrollableTextView?.frame.height ?? 0))
            scrollableTextLabel?.text = scrollableText
            scrollableTextLabel?.font = UIFont(name: "Avenir Next", size: 38)!
            scrollableTextLabel?.backgroundColor = UIColor.clear
            scrollableTextLabel?.textAlignment = .left
            scrollableTextLabel?.textColor = UIColor(named: "ScollMessage_Text")
            scrollableTextLabel?.numberOfLines = 1

            let textLength = (scrollableTextLabel.text! as NSString).boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: scrollableTextLabel?.frame.size.height ?? 0), options: NSStringDrawingOptions.usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: scrollableTextLabel?.font ?? UIFont.systemFont(ofSize: 18)], context: nil).width

            if textLength > scrollableTextView?.frame.width ?? 0 { // Only add scroll when the text width exceeds the scrolling view size.
                DDLogDebug("MainscreenExtension : Only add scroll when the text width exceeds the scrolling view size")

                scrollbarTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
                    self?.animateScrollingMessage()
                }
            }

            // Extend content size by the scroll view width so the text can scroll completely off screen before resetting
            let scrollViewWidth = scrollableTextView?.frame.width ?? 0
            scrollableTextView?.contentSize = CGSize(width: textLength + scrollViewWidth, height: scrollableTextLabel?.frame.size.height ?? 0)

            scrollableTextLabel?.frame = CGRect(x: scrollableTextLabel?.frame.origin.x ?? 0, y: scrollableTextLabel?.frame.origin.y ?? 0, width: textLength, height: scrollableTextLabel?.frame.size.height ?? 0)

            scrollableTextView?.addSubview(scrollableTextLabel)

            // check condition for scrolling and decide the logic.
            // make configuration values as global scope.
            scrollTextOffset = 0
            scrollableTextView?.contentOffset.x = scrollTextOffset
            scrollableTextView?.isHidden = false
        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in setScrollableView - \(String(describing: exception))")
        }
    }

    @objc func animateScrollingMessage() {
        SwiftTryCatch.try {
            // DDLogDebug("MainscreenExtension : Animate Scrolling Message")

            scrollTextOffset += 200

            if scrollTextOffset > ((scrollableTextLabel?.frame.size.width ?? 0) + CGFloat(100)) {
                scrollableTextView?.isHidden = true
                scrollTextOffset = 0
                scrollableTextView?.contentOffset.x = scrollTextOffset
                scrollableTextView?.isHidden = false
                scrollbarTimer?.invalidate()

                // 2-second pause then immediately kick off the first scroll step and restart the repeating timer
                scrollbarTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    animateScrollingMessage()
                    scrollbarTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
                        self?.animateScrollingMessage()
                    }
                }

            } else {
                scrollableTextView?.isHidden = false
                UIView.animate(withDuration: 4, delay: 0.0, options: .curveLinear, animations: {
                    self.scrollableTextView?.contentOffset.x = CGFloat(self.scrollTextOffset)
                }, completion: nil)
            }
        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in animateScrollingMessage - \(String(describing: exception))")
        }
    }

    @objc func scheduleScrollAnimationWithDuration() {
        SwiftTryCatch.try {
            // DDLogDebug("MainscreenExtension : Schedule Scroll animation with duration")

            scrollbarTimer?.invalidate()

            scrollableTextView?.isHidden = true
            scrollTextOffset = 0
            scrollableTextView?.contentOffset.x = scrollTextOffset
            scrollableTextView?.isHidden = false

            self.scrollbarTimer = Timer.scheduledTimer(timeInterval: 4, target: self, selector: #selector(self.animateScrollingMessage), userInfo: nil, repeats: true)
            scrollTextOffset = 0
        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in scheduleScrollAnimationWithDuration - \(String(describing: exception))")
        }
    }

    // MARK: - SARA Alert Message View Design

    // This function used to draw the sara alert design  for the CATIE TV
    // As of now it was designed for a static alert but once the server data is ready this will function as dynamic...

    func setSaraAlertLayout(
        saraAlertData: [SaraAlert],
        saraAlertHeader: [SaraHeader],
        saraAlertFooter: [SaraFooter],
        saraAlertBody: [SaraBody],
        saraAlertBodyText: [SaraBodyText],
        saraAlertBodyIndividual: [SaraBodyIndividual]
    ) {
        SwiftTryCatch.try {
            DDLogDebug("MainscreenExtension : Set SARA Alert Layout")

            var styleData: [String: String] = [:]
            var headerStyleData: [String: String] = [:]
            var footerStyleData: [String: String] = [:]
            var bodyStyleData: [String: String] = [:]
            var audioData = Data()

            managedContext.performAndWait {
                if !saraAlertData.isEmpty {
                    let data = saraAlertData[0]

                    styleData["width"] = data.width ?? ""
                    styleData["height"] = data.height ?? ""
                    styleData["margin"] = data.margin ?? ""
                    styleData["color"] = data.color ?? ""
                    styleData["textAlign"] = data.textAlign ?? ""
                    styleData["border"] = data.border ?? ""
                    styleData["borderColor"] = data.borderColor ?? ""
                    styleData["fontSize"] = data.fontSize ?? ""
                    styleData["backgroundColor"] = data.backgroundColor ?? ""
                    styleData["fontStyle"] = data.fontStyle ?? ""
                    styleData["fontWeight"] = data.fontWeight ?? ""
                    styleData["flashColor"] = data.flashColor ?? ""
                    styleData["flash"] = data.flash.description
                    audioData = data.audio ?? Data()
                }

                if !saraAlertHeader.isEmpty {
                    let data = saraAlertHeader[0]

                    headerStyleData["width"] = data.width ?? ""
                    headerStyleData["height"] = data.height ?? ""
                    headerStyleData["margin"] = data.margin ?? ""
                    headerStyleData["color"] = data.color ?? ""
                    headerStyleData["textAlign"] = data.textAlign ?? ""
                    headerStyleData["border"] = data.border ?? ""
                    headerStyleData["borderColor"] = data.borderColor ?? ""
                    headerStyleData["fontSize"] = data.fontSize ?? ""
                    headerStyleData["backgroundColor"] = data.backgroundColor ?? ""
                    headerStyleData["fontStyle"] = data.fontStyle ?? ""
                    headerStyleData["fontWeight"] = data.fontWeight ?? ""
                    headerStyleData["headerText"] = data.headerText ?? ""
                }

                DDLogDebug("MainscreenExtension : Set SARA Alert Content View")

                // Update SARA Alert layout for UI Type 5 (carousel-only mode)
                if isCarouselOnlyModeActive {
                    setupSaraAlertFullWidthLayout()
                }

                // Alert Content View
                if !styleData.isEmpty {
                    saraAlertView?.layer.borderWidth = getBoderLine(borderSize: styleData["border"] ?? "".trim(), defaultSize: 10.0)
                    saraAlertView?.layer.borderColor = getBorderColor(borderColor: headerStyleData["borderColor"] ?? "".trim())
                    saraAlertView?.backgroundColor = getBackgroundColor(backgroundColor: styleData["backgroundColor"], defaultColor: UIColor(rgb: 0xFFFFFF))

                    // Apply shadow styling for visual prominence (similar to other UI components)
                    saraAlertView?.updateShadowColor(withColor: UIColor(named: "Header_Shadow") ?? UIColor.black.withAlphaComponent(0.6))
                    saraAlertView?.layer.shadowOpacity = 1.0
                    saraAlertView?.layer.shadowOffset = CGSize(width: 2, height: 2)
                    saraAlertView?.layer.shadowRadius = 8.0
                    // Enable clipping to prevent content overflow onto background
                    saraAlertView?.layer.masksToBounds = true
                    saraAlertView?.clipsToBounds = true
                    saraAlertView?.layer.shouldRasterize = true
                    saraAlertView?.layer.rasterizationScale = UIScreen.main.scale

                    // Alert and Flash option

                    saraAlertFlashFlag = false
                    saraAlertFlashOptions = [CGColor]()

                    self.saraAlertFlashTimer?.invalidate()

                    if saraAlertAudioPlayer != nil {
                        saraAlertAudioPlayer.stop()
                        saraAlertAudioPlayer = nil
                    }
                    DDLogDebug("MainscreenExtension : Check Flash available for SARA Alert")
                    if styleData["flash"] == "1" { // Flash avaialble
                        // Adding flash colors
                        DDLogDebug("MainscreenExtension : Adding Flash to SARA Alert")
                        saraAlertFlashOptions.append(getBorderColor(borderColor: styleData["borderColor"] ?? "".trim()))

                        saraAlertFlashOptions.append(getBorderColor(borderColor: styleData["flashColor"] ?? "".trim()))

                        self.saraAlertFlashTimer = Timer.scheduledTimer(timeInterval: TimeInterval(1), target: self, selector: #selector(self.updateAlertFlash), userInfo: nil, repeats: true)
                    }

                    DDLogDebug("MainscreenExtension : Check Audio Data available for SARA Alert")
                    if !audioData.isEmpty { // Audio data available
                        DDLogDebug("MainscreenExtension : Audio available for SARA Alert totalSize - \(String(format: "%.5f", (audioData.count) / 1_000_000))MB")
                        handleSaraAlertAudioOptions(audioData: audioData)
                    }

                } else {}

                DDLogDebug("MainscreenExtension : Set SARA Alert Header View")
                // Header view
                if !headerStyleData.isEmpty {
                    saraAlertHeaderView?.subviews.forEach { $0.removeFromSuperview() }
                    saraAlertHeaderView?.layer.borderWidth = getBoderLine(borderSize: headerStyleData["border"] ?? "", defaultSize: 5.0)
                    saraAlertHeaderView?.layer.borderColor = getBorderColor(borderColor: headerStyleData["borderColor"] ?? "".trim())
                    saraAlertHeaderView?.backgroundColor = getBackgroundColor(backgroundColor: headerStyleData["backgroundColor"], defaultColor: UIColor(rgb: 0xFFFFFF))
                    saraAlertHeaderView?.clipsToBounds = true

                    DDLogDebug("MainscreenExtension : Adding text in SARA Alert Content View")

                    // Adding header text
                    if headerStyleData["headerText"] != "" {
                        let headerText = getTextViewWithSpecification(xAxis: 5, yAxis: 5, width: (saraAlertHeaderView?.frame.size.width ?? 20) - 20, height: (saraAlertHeaderView?.frame.size.height ?? 5) - 5, text: headerStyleData["headerText"] ?? "", styleData: headerStyleData, defaultStyle: styleData)
                        saraAlertHeaderView?.addSubview(headerText)
                    }

                } else {}

                DDLogDebug("MainscreenExtension : Set SARA Alert Footer View")
                // Footer view

                if !saraAlertFooter.isEmpty {
                    let data = saraAlertFooter[0]

                    saraAlertFooterView?.subviews.forEach { $0.removeFromSuperview() }
                    saraAlertFooterView?.layer.borderWidth = getBoderLine(borderSize: data.border ?? "", defaultSize: 5.0)
                    saraAlertFooterView?.layer.borderColor = getBorderColor(borderColor: data.borderColor?.trim())
                    saraAlertFooterView?.backgroundColor = getBackgroundColor(backgroundColor: data.backgroundColor, defaultColor: UIColor(rgb: 0xFFFFFF))
                    saraAlertFooterView?.clipsToBounds = true

                    DDLogDebug("MainscreenExtension : Adding text in SARA Alert Footer View")

                    footerStyleData["width"] = data.width ?? ""
                    footerStyleData["height"] = data.height ?? ""
                    footerStyleData["margin"] = data.margin ?? ""
                    footerStyleData["color"] = data.color ?? ""
                    footerStyleData["textAlign"] = data.textAlign ?? ""
                    footerStyleData["border"] = data.border ?? ""
                    footerStyleData["borderColor"] = data.borderColor ?? ""
                    footerStyleData["fontSize"] = data.fontSize ?? ""
                    footerStyleData["backgroundColor"] = data.backgroundColor ?? ""
                    footerStyleData["fontStyle"] = data.fontStyle ?? ""
                    footerStyleData["fontWeight"] = data.fontWeight ?? ""

                    // Footer text
                    if data.footerText != "" {
                        let footerText = getTextViewWithSpecification(xAxis: 5, yAxis: 5, width: saraAlertFooterView.frame.size.width - 20, height: saraAlertFooterView.frame.size.height - 5, text: data.footerText ?? "", styleData: footerStyleData, defaultStyle: styleData)
                        saraAlertFooterView?.addSubview(footerText)
                    }

                } else {}

                DDLogDebug("MainscreenExtension : Set SARA Alert Body View")
                // Body view
                if !saraAlertBody.isEmpty {
                    let data = saraAlertBody[0]

                    saraAlertBodyView?.subviews.forEach { $0.removeFromSuperview() }
                    saraAlertBodyView?.layer.borderWidth = getBoderLine(borderSize: data.border ?? "", defaultSize: 5.0)
                    saraAlertBodyView?.layer.borderColor = getBorderColor(borderColor: data.borderColor?.trim())
                    saraAlertBodyView?.backgroundColor = getBackgroundColor(backgroundColor: data.backgroundColor, defaultColor: UIColor(rgb: 0xFFFFFF))
                    saraAlertBodyView?.clipsToBounds = true

                } else {}

                var xAxVal = CGFloat(10.0) // Default x axis position
                var yAxVal = CGFloat(10.0) // Default y axis position
                var numberPointer = 0 // Used display number pointers to text and will get incremented for every new line

                // This function go through each line by line first vertically.
                // The inner for loop go through each line by line horizontally.
                for i in 0 ..< (saraAlertBodyText.count) {
                    let data = saraAlertBodyText[i]

                    // check for the pointer
                    var tempPointer = ""

                    if data.pointers == "bullet" {
                        tempPointer = "\u{2022} "
                    } else if data.pointers == "number" {
                        numberPointer = numberPointer + 1
                        tempPointer = "\(numberPointer). "
                    }

                    bodyStyleData["width"] = data.width ?? ""
                    bodyStyleData["height"] = data.height ?? ""
                    bodyStyleData["margin"] = data.margin ?? ""
                    bodyStyleData["color"] = data.color ?? ""
                    bodyStyleData["textAlign"] = data.textAlign ?? ""
                    bodyStyleData["border"] = data.border ?? ""
                    bodyStyleData["borderColor"] = data.borderColor ?? ""
                    bodyStyleData["fontSize"] = data.fontSize ?? ""
                    bodyStyleData["backgroundColor"] = data.backgroundColor ?? ""
                    bodyStyleData["fontStyle"] = data.fontStyle ?? ""
                    bodyStyleData["fontWeight"] = data.fontWeight ?? ""

                    var modifyData = [Any]()

                    // Add texts in the respective line wise before processing
                    for j in 0 ..< saraAlertBodyIndividual.count {
                        let data = saraAlertBodyIndividual[j]
                        if data.border?.contains("+line\(i + 1)") == true {
                            modifyData.append(saraAlertBodyIndividual[j])
                        }
                    }

                    var modifyStyle = [Any]()
                    modifyStyle.append(saraAlertBodyText[i])

                    let (modifiedText, modifiedHeight) = getBodyTextViewWithSpecification(xAxis: xAxVal, yAxis: yAxVal, width: saraAlertBodyView.frame.size.width - 10, data: modifyData, bodyStyle: modifyStyle, tempPointer: tempPointer, defaultStyle: styleData)
                    saraAlertBodyView?.addSubview(modifiedText)

                    xAxVal = 10.0 // Resetting the x axis value to default.
                    yAxVal = yAxVal + modifiedHeight + 10 // Adding next line text
                }

                // MARK: - Send data to publishers for SwiftUI consumption

                // Determine if we're using rich text
                let hasRichText = !saraAlertBodyIndividual.isEmpty

                // Process main alert properties and publish them
                if !saraAlertData.isEmpty {
                    let data = saraAlertData[0]

                    // Flash setting
                    saraAlertFlashingSubject.send(data.flash == 1)

                    // Border properties
                    if let borderWidth = data.border, !borderWidth.isEmpty {
                        let cleanBorderWidth = borderWidth
                            .replacingOccurrences(of: "solid", with: "")
                            .replacingOccurrences(of: "px", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)

                        if let width = NumberFormatter().number(from: cleanBorderWidth) {
                            saraAlertBorderWidthSubject.send(CGFloat(truncating: width))
                        }
                    }

                    // Colors
                    if let borderColor = data.borderColor, !borderColor.isEmpty {
                        saraAlertBorderColorSubject.send(borderColor)
                    }

                    if let flashColor = data.flashColor, !flashColor.isEmpty {
                        saraAlertFlashColorSubject.send(flashColor)
                    }

                    if let bgColor = data.backgroundColor, !bgColor.isEmpty {
                        saraAlertBodyBackgroundColorSubject.send(bgColor)
                    }

                    if let textColor = data.color, !textColor.isEmpty {
                        saraAlertBodyTextColorSubject.send(textColor)
                    }

                    // Font size
                    if let fontSize = data.fontSize, !fontSize.isEmpty {
                        let cleanFontSize = fontSize.replacingOccurrences(of: "px", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if let size = NumberFormatter().number(from: cleanFontSize) {
                            saraAlertBodyFontSizeSubject.send(CGFloat(truncating: size))
                        }
                    }

                    // Font style
                    if let fontStyle = data.fontStyle {
                        saraAlertBodyFontStyleSubject.send(fontStyle)
                    }
                }

                // Process header content
                if !saraAlertHeader.isEmpty {
                    let header = saraAlertHeader[0]

                    // Header text
                    if let headerText = header.headerText {
                        saraAlertHeaderSubject.send(headerText)
                    }

                    // Header colors
                    if let bgColor = header.backgroundColor, !bgColor.isEmpty {
                        saraAlertHeaderBackgroundColorSubject.send(bgColor)
                    }

                    if let textColor = header.color, !textColor.isEmpty {
                        saraAlertHeaderTextColorSubject.send(textColor)
                    }

                    // Header font size
                    if let fontSize = header.fontSize, !fontSize.isEmpty {
                        let cleanSize = fontSize.replacingOccurrences(of: "px", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if let size = NumberFormatter().number(from: cleanSize) {
                            saraAlertHeaderFontSizeSubject.send(CGFloat(truncating: size))
                        }
                    }

                    // Header font style
                    if let fontStyle = header.fontStyle {
                        saraAlertHeaderFontStyleSubject.send(fontStyle)
                    }
                }

                // Process footer content
                if !saraAlertFooter.isEmpty {
                    let footer = saraAlertFooter[0]

                    // Footer text
                    if let footerText = footer.footerText {
                        saraAlertFooterSubject.send(footerText)
                    }

                    // Footer colors
                    if let bgColor = footer.backgroundColor, !bgColor.isEmpty {
                        saraAlertFooterBackgroundColorSubject.send(bgColor)
                    }

                    if let textColor = footer.color, !textColor.isEmpty {
                        saraAlertFooterTextColorSubject.send(textColor)
                    }

                    // Footer font size/style
                    if let fontSize = footer.fontSize, !fontSize.isEmpty {
                        let cleanSize = fontSize.replacingOccurrences(of: "px", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if let size = NumberFormatter().number(from: cleanSize) {
                            saraAlertFooterFontSizeSubject.send(CGFloat(truncating: size))
                        }
                    }

                    if let fontStyle = footer.fontStyle {
                        saraAlertFooterFontStyleSubject.send(fontStyle)
                    }
                }

                // Process body content for rich text
                saraAlertHasRichTextSubject.send(hasRichText)

                if hasRichText {
                    var bodyComponents = [PortraitViewModel.BodyTextComponent]()

                    // Group individual text items by line
                    var textsByLine: [Int: [SaraBodyIndividual]] = [:]

                    for item in saraAlertBodyIndividual {
                        if let border = item.border, border.contains("+line") {
                            if let rangeStart = border.range(of: "+line"),
                               let lineNumberStr = border[rangeStart.upperBound...].components(separatedBy: CharacterSet.decimalDigits.inverted).first,
                               let lineNumber = Int(lineNumberStr)
                            {
                                if textsByLine[lineNumber] == nil {
                                    textsByLine[lineNumber] = []
                                }
                                textsByLine[lineNumber]?.append(item)
                            }
                        }
                    }

                    // Process each line to build rich text components
                    for line in 1 ... textsByLine.keys.count {
                        if let items = textsByLine[line] {
                            for item in items {
                                // Determine text alignment
                                var alignment: NSTextAlignment = .center
                                if let textAlign = item.textAlign {
                                    if textAlign == "left" {
                                        alignment = .left
                                    } else if textAlign == "right" {
                                        alignment = .right
                                    }
                                }

                                // Convert NSTextAlignment to SwiftUI TextAlignment
                                var swiftUIAlignment: TextAlignment = .center
                                switch alignment {
                                case .left:
                                    swiftUIAlignment = .leading
                                case .right:
                                    swiftUIAlignment = .trailing
                                default:
                                    swiftUIAlignment = .center
                                }

                                // Determine font size
                                var fontSize: CGFloat = 24.0 // Default
                                if let fontSizeStr = item.fontSize, !fontSizeStr.isEmpty {
                                    let cleanSize = fontSizeStr.replacingOccurrences(of: "px", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                                    if let size = NumberFormatter().number(from: cleanSize) {
                                        fontSize = CGFloat(truncating: size)
                                    }
                                }

                                // Parse color
                                var textColor = Color.black // Default color
                                if let colorString = item.color, !colorString.isEmpty {
                                    if colorString.contains("rgb") {
                                        textColor = Color(rgbString: colorString) ?? .black
                                    } else if colorString.contains("#") {
                                        textColor = Color(hex: colorString) ?? .black
                                    }
                                }

                                // Create component and add to array
                                let component = PortraitViewModel.BodyTextComponent(
                                    text: item.bodyText ?? "",
                                    fontSize: fontSize,
                                    fontStyle: item.fontStyle ?? "",
                                    color: textColor,
                                    alignment: swiftUIAlignment
                                )

                                bodyComponents.append(component)
                            }
                        }
                    }

                    // Send the rich text components
                    saraAlertBodyTextComponentsSubject.send(bodyComponents)
                } else {
                    // Use simple text approach - combine all individual texts
                    var simpleText = ""
                    for item in saraAlertBodyIndividual {
                        simpleText += (item.bodyText ?? "") + " "
                    }

                    // Use default message if nothing is found
                    if simpleText.isEmpty {
                        simpleText = "Important information about your facility"
                    }

                    saraAlertMessageSubject.send(simpleText)
                }
            }

        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in setSaraAlertLayout - \(String(describing: exception))")
        }
    }

    /// This method used to convert the hex string to UIcolor object.
    func hexStringToUIColor(hex: String) -> UIColor { // #000000
        var hexStringToUIColor = UIColor()
        SwiftTryCatch.try {
            // DDLogDebug("MainscreenExtension : Hex string to UIcolor conversion")
            var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

            if cString.hasPrefix("#") {
                cString.remove(at: cString.startIndex)
            }

            if (cString.count) != 6 {
                hexStringToUIColor = UIColor.gray
            } else {
                var rgbValue: UInt64 = 0
                Scanner(string: cString).scanHexInt64(&rgbValue)

                hexStringToUIColor = UIColor(
                    red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                    green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
                    blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
                    alpha: CGFloat(1.0)
                )
            }
        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in hexStringToUIColor - \(String(describing: exception))")
        }

        return hexStringToUIColor
    }

    /// This method used to convert the rgb color code to UIColor
    func rgbStringToUIColor(rgb: String) -> UIColor { // rgb(255, 255, 255)
        var rgbStringToUIColor = UIColor()

        SwiftTryCatch.try {
            // DDLogDebug("MainscreenExtension : RGB string to UIcolor conversion")
            var convertedRGBString = rgb.trim()
            convertedRGBString = convertedRGBString.replacingOccurrences(of: "rgb(", with: "")
            convertedRGBString = convertedRGBString.replacingOccurrences(of: ")", with: "")

            let convertedRGBArray = convertedRGBString.split(separator: ",")

            var redValue = 0.0
            var greenValue = 0.0
            var blueValue = 0.0

            if convertedRGBArray.count == 3 {
                redValue = Double(truncating: NumberFormatter().number(from: convertedRGBArray[0].trimmingCharacters(in: [" "])) ?? 0)
                greenValue = Double(truncating: NumberFormatter().number(from: convertedRGBArray[1].trimmingCharacters(in: [" "])) ?? 0)
                blueValue = Double(truncating: NumberFormatter().number(from: convertedRGBArray[2].trimmingCharacters(in: [" "])) ?? 0)
            }

            rgbStringToUIColor = UIColor(
                red: CGFloat(redValue / 255.0),
                green: CGFloat(greenValue / 255.0),
                blue: CGFloat(blueValue / 255.0),
                alpha: CGFloat(1.0)
            )
        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in rgbStringToUIColor - \(String(describing: exception))")
        }

        return rgbStringToUIColor
    }

    /// This function used to generate the text into the text view based on the given style data for header and footer class.
    /// Style data - This will be the style to the particular pointing element
    /// Default data - This will be applied to the element when there is no data in the style class...
    func getTextViewWithSpecification(xAxis: CGFloat, yAxis: CGFloat, width: CGFloat, height: CGFloat, text: String, styleData: [String: String], defaultStyle: [String: String]) -> UILabel {
        // DDLogDebug("MainscreenExtension : getTextViewWithSpecification")
        var margin: CGFloat = 0.0
        var returntextLabel = UILabel()

        SwiftTryCatch.try {
            if !styleData.isEmpty, !defaultStyle.isEmpty {
                if styleData["margin"] != "" {
                    margin = CGFloat(Int((styleData["margin"]?.trim().replacingOccurrences(of: "px", with: "") ?? "0")) ?? 0)
                }

                let textLabel = UILabel(frame: CGRect(x: xAxis + margin, y: yAxis + margin - 5, width: width - margin, height: height - margin - 5))
                textLabel.text = text

                let fontSize = CGFloat(Int(styleData["fontSize"]?.trim().replacingOccurrences(of: "px", with: "") ?? "30") ?? 30)

                let styleArray = styleData["fontStyle"]?.trim().split(separator: ",") // Since a text may have multiple styles combined, we need to use an array

                if styleArray?.count ?? 0 > 0 {
                    if styleArray?.contains("bold") == true {
                        textLabel.font = UIFont.boldSystemFont(ofSize: fontSize)
                    } else if styleArray?.contains("italic") == true {
                        textLabel.font = UIFont.italicSystemFont(ofSize: fontSize)
                    } else {
                        textLabel.font = UIFont.systemFont(ofSize: fontSize)
                    }

                    if styleArray?.contains("underline") == true {
                        textLabel.underline()
                    }

                    if styleArray?.contains("bold") == true, styleArray?.contains("italic") == true {
                        textLabel.font = textLabel.font.with([.traitBold, .traitItalic]) // Adding support to both the bold and italic font style
                    }

                } else {
                    textLabel.font = UIFont.systemFont(ofSize: fontSize)
                }

                // font color
                if styleData["color"] != "" {
                    if styleData["color"]?.contains("rgb") == true { // RGB code
                        textLabel.textColor = rgbStringToUIColor(rgb: (styleData["color"]?.trim() ?? ""))
                    } else { // Hex code
                        textLabel.textColor = hexStringToUIColor(hex: (styleData["color"]?.trim() ?? ""))
                    }
                } else if defaultStyle["color"] != "" { // Check for default color when the style color param has no values
                    if defaultStyle["color"]?.contains("rgb") == true { // RGB code
                        textLabel.textColor = rgbStringToUIColor(rgb: (defaultStyle["color"]?.trim())!)
                    } else if defaultStyle["color"]?.contains("#") == true { // Hex code
                        textLabel.textColor = hexStringToUIColor(hex: (defaultStyle["color"]?.trim())!)
                    } else {
                        textLabel.textColor = UIColor.black
                    }
                } else { // If there is no values find on above two conditions then use the default color
                    textLabel.textColor = UIColor.black
                }

                // text alignment
                if styleData["textAlign"] != "" {
                    if styleData["textAlign"] == "center" {
                        textLabel.textAlignment = .center
                    } else if styleData["textAlign"] == "left" {
                        textLabel.textAlignment = .left
                    } else { // right
                        textLabel.textAlignment = .right
                    }
                } else {
                    if defaultStyle["textAlign"] == "center" {
                        textLabel.textAlignment = .center
                    } else if defaultStyle["textAlign"] == "left" {
                        textLabel.textAlignment = .left
                    } else { // right
                        textLabel.textAlignment = .right
                    }
                }

                returntextLabel = textLabel

            } else {
                DDLogDebug("MainscreenExtension : Sara Alert styling details not available")
            }

        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in getTextViewWithSpecification - \(String(describing: exception))")
        }

        return returntextLabel
    }

    /// This method used to draw the text view inside of the body container based on the given speificiations....
    func getBodyTextViewWithSpecification(xAxis: CGFloat, yAxis: CGFloat, width: CGFloat, data: [Any], bodyStyle: [Any], tempPointer: String, defaultStyle: [String: String]) -> (UITextView, CGFloat) {
        // DDLogDebug("getBodyTextViewWithSpecification")
        var totalText = tempPointer
        var maxFontSize = 0
        var maxNoOfLines = 1
        var allFontWeights = [String]()
        var tempFont = UIFont()
        var margin: CGFloat = 0.0

        var returnrequiredTextView = UITextView()
        var returntextHieght = CGFloat()

        SwiftTryCatch.try {
            if !data.isEmpty, !bodyStyle.isEmpty, !defaultStyle.isEmpty {
                if defaultStyle["margin"] != "" {
                    margin = CGFloat(Int(defaultStyle["margin"]?.trim().replacingOccurrences(of: "px", with: "") ?? "0") ?? 0)
                }

                for i in 0 ..< (data.count) {
                    let individualData = data[i] as? SaraBodyIndividual

                    totalText = totalText + (individualData?.bodyText ?? "")
                    let textFontSize = Int(individualData?.fontSize?.trim().replacingOccurrences(of: "px", with: "") ?? "30") ?? 30

                    if textFontSize > maxFontSize {
                        maxFontSize = textFontSize
                    }
                    allFontWeights.append(individualData?.fontStyle ?? "")
                    allFontWeights.append(individualData?.fontWeight ?? "")
                }

                // Calculating max width and height required from the possible cases

                if allFontWeights.contains("bold") {
                    tempFont = UIFont.boldSystemFont(ofSize: CGFloat(maxFontSize))
                } else if allFontWeights.contains("italic") {
                    tempFont = UIFont.italicSystemFont(ofSize: CGFloat(maxFontSize))
                } else {
                    tempFont = UIFont.systemFont(ofSize: CGFloat(maxFontSize))
                }

                let textWidth = totalText.boundingRect(with: CGSize(width: 9999, height: 9999), options: NSStringDrawingOptions.usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: tempFont], context: nil).width

                var textHieght = totalText.boundingRect(with: CGSize(width: 9999, height: 9999), options: NSStringDrawingOptions.usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: tempFont], context: nil).height

                if textWidth > width { // Need to wrap up the text
                    maxNoOfLines = Int(ceil(textWidth / width))
                    textHieght = (CGFloat(maxNoOfLines) * textHieght) + 15 // Calculating heights for every line
                } else {
                    textHieght = textHieght + 20 // Adding some offset
                }

                returntextHieght = textHieght

                let requiredTextView = UITextView(frame: CGRect(x: xAxis + margin, y: yAxis + margin, width: width, height: textHieght))
                requiredTextView.textContainer.maximumNumberOfLines = maxNoOfLines
                requiredTextView.textContainer.lineBreakMode = NSLineBreakMode.byCharWrapping

                // Formatting text based on the configuration
                let attributedString = NSMutableAttributedString(string: totalText)
                let style = NSMutableParagraphStyle()

                if !bodyStyle.isEmpty {
                    let styleData = bodyStyle[0] as? SaraBodyText
                    if styleData?.textAlign == "center" {
                        style.alignment = .center
                    } else if styleData?.textAlign == "left" {
                        style.alignment = .left
                    } else if styleData?.textAlign == "right" {
                        style.alignment = .right
                    }
                } else {
                    DDLogDebug("MainscreenExtension : Sara Alert body content alignment not available so default alignment left applied")
                    style.alignment = .left
                }

                let fullRange = NSMakeRange(0, attributedString.length)

                attributedString.addAttribute(NSAttributedString.Key.paragraphStyle, value: style, range: fullRange)

                for i in 0 ..< data.count {
                    let individualData = data[i] as? SaraBodyIndividual

                    var tempText = individualData?.bodyText

                    if i == 0 {
                        tempText = tempPointer + (tempText ?? "") // Adding pointer on the first portion
                    }

                    var tempStyleDict: [String: String] = [:]

                    tempStyleDict["width"] = individualData?.width ?? ""
                    tempStyleDict["height"] = individualData?.height ?? ""
                    tempStyleDict["margin"] = individualData?.margin ?? ""
                    tempStyleDict["color"] = individualData?.color ?? ""
                    tempStyleDict["textAlign"] = individualData?.textAlign ?? ""
                    tempStyleDict["border"] = individualData?.border ?? ""
                    tempStyleDict["borderColor"] = individualData?.borderColor ?? ""
                    tempStyleDict["fontSize"] = individualData?.fontSize ?? ""
                    tempStyleDict["backgroundColor"] = individualData?.backgroundColor ?? ""
                    tempStyleDict["fontStyle"] = individualData?.fontStyle ?? ""
                    tempStyleDict["fontWeight"] = individualData?.fontWeight ?? ""

                    // let tempStyle = data.bodyIndividualDataList[i].bodyStyle ?? saraStyleClass()
                    let linkRange = attributedString.mutableString.range(of: tempText ?? "")

                    var tempFont = UIFont()
                    let tempFontSize = CGFloat(Int(tempStyleDict["fontSize"]?.trim().replacingOccurrences(of: "px", with: "") ?? "30") ?? 30)

                    let styleArray = tempStyleDict["fontStyle"]?.trim().split(separator: ",") // Since a text may have multiple styles combined, we need to use an array

                    // "font-style:bold,italic,underline",

                    if styleArray?.count ?? 0 > 0 {
                        if styleArray?.contains("bold") == true {
                            tempFont = UIFont.boldSystemFont(ofSize: tempFontSize)
                        } else if styleArray?.contains("italic") == true {
                            tempFont = UIFont.italicSystemFont(ofSize: tempFontSize)
                        } else { // Normal
                            tempFont = UIFont.systemFont(ofSize: tempFontSize)
                        }

                        if styleArray?.contains("bold") == true, styleArray?.contains("italic") == true {
                            tempFont = tempFont.with([.traitBold, .traitItalic]) // Adding support to both the bold and italic font style
                        }

                        if styleArray?.contains("underline") == true {
                            attributedString.addAttribute(NSAttributedString.Key.underlineStyle,
                                                          value: NSUnderlineStyle.single.rawValue,
                                                          range: linkRange)
                        }

                    } else {
                        tempFont = UIFont.systemFont(ofSize: tempFontSize)
                    }

                    attributedString.addAttribute(NSAttributedString.Key.font, value: tempFont, range: linkRange)

                    var tempColor = UIColor.black

                    if tempStyleDict["color"] != "" {
                        if tempStyleDict["color"]?.contains("rgb") == true { // RGB code
                            tempColor = rgbStringToUIColor(rgb: tempStyleDict["color"]?.trim() ?? "")
                        } else { // Hex code
                            tempColor = hexStringToUIColor(hex: tempStyleDict["color"]?.trim() ?? "")
                        }
                    } else if defaultStyle["color"] != "" { // Check for default color when the style color param has no values
                        if defaultStyle["color"]?.contains("rgb") == true { // RGB code
                            tempColor = rgbStringToUIColor(rgb: (defaultStyle["color"]?.trim() ?? ""))
                        } else if defaultStyle["color"]?.contains("#") == true { // Hex code
                            tempColor = hexStringToUIColor(hex: (defaultStyle["color"]?.trim() ?? ""))
                        } else {
                            tempColor = UIColor.black
                        }
                    } else { // If there is no values find on above two conditions then use the default color
                        tempColor = UIColor.black
                    }

                    attributedString.addAttribute(NSAttributedString.Key.foregroundColor, value: tempColor, range: linkRange)
                }

                requiredTextView.attributedText = attributedString
                returnrequiredTextView = requiredTextView

            } else {
                DDLogDebug("MainscreenExtension : Sara Alert body contents not available ")
            }

        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in getBodyTextViewWithSpecification - \(String(describing: exception))")
        }
        return (returnrequiredTextView, returntextHieght)
    }

    /// This method used to draw the border line based on the given size width
    func getBoderLine(borderSize: String, defaultSize: CGFloat) -> CGFloat {
        // DDLogDebug("MainscreenExtension : getBoderLine")
        var requiredSize: CGFloat = defaultSize

        SwiftTryCatch.try {
            if borderSize != "" {
                if let n = NumberFormatter().number(from: borderSize.replacingOccurrences(of: "solid", with: "").replacingOccurrences(of: "px", with: "").trim()) {
                    requiredSize = CGFloat(truncating: n)
                }
            }
        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in getBoderLine - \(String(describing: exception))")
        }

        return requiredSize
    }

    /// This method used to draw the border color from the given text
    func getBorderColor(borderColor: String?) -> CGColor {
        var requiredBorderColor = UIColor(rgb: 0x000000).cgColor // Default color

        SwiftTryCatch.try {
            if borderColor != "" {
                if (borderColor?.contains("rgb")) ?? false { // RGB code
                    requiredBorderColor = rgbStringToUIColor(rgb: borderColor?.trim() ?? "rgb(0,0,0)").cgColor
                } else if (borderColor?.contains("#")) ?? false { // Hex code
                    requiredBorderColor = hexStringToUIColor(hex: borderColor?.trim() ?? "0x000000").cgColor
                }
            }
        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in getBorderColor - \(String(describing: exception))")
        }

        return requiredBorderColor
    }

    /// This methos used to draw the background color from the given string
    func getBackgroundColor(backgroundColor: String?, defaultColor: UIColor) -> UIColor {
        // DDLogDebug("MainscreenView : getBackgroundColor")
        var requiredBGColor = defaultColor

        SwiftTryCatch.try {
            if backgroundColor != "" {
                if (backgroundColor?.contains("rgb")) ?? false { // RGB code
                    requiredBGColor = rgbStringToUIColor(rgb: backgroundColor?.trim() ?? "rgb(255,255,255)")
                } else if (backgroundColor?.contains("#")) ?? false {
                    requiredBGColor = hexStringToUIColor(hex: backgroundColor?.trim() ?? "0xFFFFFF")
                }
            }
        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in getBackgroundColor - \(String(describing: exception))")
        }

        return requiredBGColor
    }

    /// This function used to update the flash option in alerts
    @objc func updateAlertFlash() {
        SwiftTryCatch.try {
            guard !self.isInPortraitMode() else {
                DDLogDebug("MainScreen: Ignoring updateAlertFlash while in portrait mode")
                self.saraAlertFlashTimer?.invalidate()
                return
            }

            if self.saraAlertFlashFlag { // Original color
                saraAlertView?.layer.borderColor = saraAlertFlashOptions[0]
                saraAlertHeaderView?.layer.borderColor = saraAlertFlashOptions[0]
                saraAlertFooterView?.layer.borderColor = saraAlertFlashOptions[0]
                saraAlertBodyView?.layer.borderColor = saraAlertFlashOptions[0]
            } else { // gray color
                saraAlertView?.layer.borderColor = saraAlertFlashOptions[1]
                saraAlertHeaderView?.layer.borderColor = saraAlertFlashOptions[1]
                saraAlertFooterView?.layer.borderColor = saraAlertFlashOptions[1]
                saraAlertBodyView?.layer.borderColor = saraAlertFlashOptions[1]
            }

            saraAlertFlashFlag = !saraAlertFlashFlag
        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in updateAlertFlash - \(String(describing: exception))")
        }
    }

    /// This method handles the sara alert audio playing options...
    func handleSaraAlertAudioOptions(audioData: Data) {
        SwiftTryCatch.try {
            do {
                // DDLogDebug("MainscreenExtension : SARA Alert Audio parsed")
                try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default)
                try AVAudioSession.sharedInstance().setActive(true)
                saraAlertAudioPlayer = try AVAudioPlayer(data: audioData)
                saraAlertAudioPlayer?.numberOfLoops = -1 // Adds loop to the audio player
                saraAlertAudioPlayer?.prepareToPlay()
                saraAlertAudioPlayer?.play()

            } catch {
                DDLogDebug("catching error at handleSaraAlertAudioOptions \(error.localizedDescription)****")
            }
        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in handleSaraAlertAudioOptions - \(String(describing: exception))")
        }
    }

    // MARK: - Registration delegates

    func presentRegistrationPage() {
        SwiftTryCatch.try {
            DDLogDebug("MainscreenExtension : Navigate to Registration Page")

            DispatchQueue.main.async {
                let vc = self.storyboard?.instantiateViewController(withIdentifier: "RegistrationViewControllerID") as! RegistrationViewController
                vc.mainViewdelegate = self

                // Store the current portrait mode state so it can be restored
                vc.wasInPortraitMode = self.isPortraitModeEnabled

                self.present(vc, animated: true, completion: nil)
            }

        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in presentRegistrationPage - \(String(describing: exception))")
        }
    }

    /// This method will be called when there is a need to stop all the updates on home screen (EX: room number detailed)
    func stopHomeViewUpdates() {
        SwiftTryCatch.try {
            DDLogDebug("MainscreenExtension : stop homeview updates called")

            DispatchQueue.main.async { [self] in
                // Stop loading screen
                safelyShowActivityIndicator(false)

                // Stop data and timer timer
                updateDateTimer?.invalidate()

                //// Stop carousel image view
                carousalView?.image = UIImage(named: "DummyCarousal")
                carousalImageArray = [(Data, Int, String, String)]()
                carousalImageTimer?.invalidate()

                //// Stop weather updates
                todayWeatherArray = [[String: String]]()
                forecastWeatherArray = [(String, String, String, UIImage, String)]()
                fourDayWeatherTable?.reloadData()
                detailedWeatherTable?.reloadData()
                fourDayWeatherView?.isHidden = true
                detailedWeatherView?.isHidden = true
                weatherDisplayTimer?.invalidate()
                todayWeatherIcon?.image = UIImage()
                todayWeatherLocation?.text = ""
                todayWeathertemp?.text = ""

                // Stop webscoket ping server timer
                pingServerTimer.invalidate()

                pingTimer.invalidate()

                // Stop scrolling message posiition movement timer
                scrollbarTimer?.invalidate()
                scrollableTextLabel?.text = ""

                // Stop event list updates
                updateEventList([])
                scheduledEventTimings = [Date]()

                eventAnimationTimer?.invalidate()

                onGoingEventScheduleTimer?.invalidate()

                eventListTable?.reloadData()
                eventListView?.isHidden = true

                //// Stop the status indicator updates.
                statusIndicatorArray = [(String, String, Int)]()
                statusIndicatorSuperView?.isHidden = true
                statusIndicatorCollectionView?.reloadData()

                statusAnimationTimer?.invalidate()

                // Stop the Sara alert updates
                saraAlertView?.isHidden = true
                carousalView?.isHidden = false
                isSaraAlertPresented = false

                saraAlertFlashTimer?.invalidate()

                if saraAlertAudioPlayer != nil {
                    saraAlertAudioPlayer?.stop()
                    saraAlertAudioPlayer = nil
                }

                // Stop clock updates
                setClockTimer?.invalidate()
                clockView?.removeFromSuperview()
                disableClock()

                // SiteLogo
                headerSiteLogo?.image = UIImage(named: "SS")

                // Time&Date
                todayTime?.text = ""
                todayDate?.text = ""

                labelForTime?.text = ""

                labelForDate?.text = ""
            }
        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in stopHomeViewUpdates - \(String(describing: exception))")
        }
    }

    func deleteLocalStorage() {
        SwiftTryCatch.try {
            deleteRecords("SiteLogo")
            deleteRecords("Weather")
            deleteRecords("Carousal")
            deleteRecords("CarousalImages")
            deleteRecords("Event")
            deleteRecords("EventList")
            deleteRecords("StatusIndicator")
            deleteRecords("Radio")
            deleteRecords("CustomHomePage")
            deleteRecords("ScrollMessage")
            deleteRecords("Clock")
            deleteRecords("SaraAlert")
            deleteRecords("SaraHeader")
            deleteRecords("SaraFooter")
            deleteRecords("SaraBody")
            deleteRecords("SaraBodyText")
            deleteRecords("SaraBodyIndividual")

            DDLogDebug("MainscreenExtension : Local storage data deleted successfully")

        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in deleteLocalStorage - \(String(describing: exception))")
        }
    }

    func deleteRecords(_ entityName: String?) {
        SwiftTryCatch.try { [self] in
            if managedContext == nil {
                managedContext = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.newBackgroundContext()
            }

            DataHandler().deleteRecords(entityName, managedContext)

        } catch: { exception in
            DDLogDebug("Mainscreen : Exception in \(String(describing: entityName)) records deletion -  \(String(describing: exception))")
        }
    }
}

// MARK: - MainScreenViewController + UITableViewDelegate, UITableViewDataSource

extension MainScreenViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection _: Int) -> Int {
        if tableView.tag == 1 {
            let safeForecastWeatherArray = getForecastWeatherCopy()
            SwiftTryCatch.try {
                DDLogDebug("MainscreenExtension : Forecast Weather Array details count - \(safeForecastWeatherArray.count)")
            } catch: { exception in
                DDLogDebug("MainscreenExtension : Exception in Forecast Weather Array details count - \(String(describing: exception))")
            }

            return safeForecastWeatherArray.count
        } else if tableView.tag == 2 {
            let safeTodayWeatherArray = getTodayWeatherCopy()
            SwiftTryCatch.try {
                DDLogDebug("MainscreenExtension : Today's Weather Array details count - \(safeTodayWeatherArray.count)")
            } catch: { exception in
                DDLogDebug("MainscreenExtension : Exception in Today's Weather Array details count - \(String(describing: exception))")
            }

            return safeTodayWeatherArray.count
        } else {
            let safeEventListArray = getEventListCopy()
            SwiftTryCatch.try {
                DDLogDebug("MainscreenExtension : Event List Array details count - \(safeEventListArray.count)")
            } catch: { exception in
                DDLogDebug("MainscreenExtension : Exception in Event List Array details count - \(String(describing: exception))")
            }
            return safeEventListArray.count
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        if tableView.tag == 1 {
            90
        } else if tableView.tag == 2 {
            45
        } else {
            if multiCalendarStatus {
                120
            } else {
                90
            }
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView.tag == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "FourDayWeatherTableCell", for: indexPath) as! FourDayWeatherTableCell

            cell.accessibilityIdentifier = "FourDayWeatherTableCell-\(indexPath.row)"

            SwiftTryCatch.try {
                let safeForecastWeatherArray = getForecastWeatherCopy()
                if !safeForecastWeatherArray.isEmpty {
                    cell.updateShadowColor(withColor: UIColor(named: "DetailedWeather_Shadow")!)

                    if indexPath.row < safeForecastWeatherArray.count {
                        DDLogDebug("MainscreenExtension : Forecast Weather Array - \(safeForecastWeatherArray[indexPath.row]) - row - \(indexPath.row)")

                        let forecast = safeForecastWeatherArray[indexPath.row]
                        cell.fourDayWeatherDay.text = forecast.0
                        cell.fourDayWeatherTemp.text = forecast.1
                        cell.fourDayWeatherIcon.image = forecast.3.withRenderingMode(.alwaysTemplate)
                        cell.fourDayWeatherIcon.tintColor = .white
                        cell.fourDayWeatherDesc.text = forecast.4

                    } else {
                        DDLogDebug("MainscreenExtension : Forecast Weather Array contains empty element at row \(indexPath.row)")
                    }
                } else {
                    DDLogDebug("MainscreenExtension : Forecast Weather data not available")
                }

                // DDLogDebug("MainscreenExtension : Forecast Weather Array - \(cell)")
            } catch: { exception in
                DDLogDebug("MainscreenExtension : Exception in Forecast Weather Array - \(String(describing: exception))")
            }

            return cell

        } else if tableView.tag == 2 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "DetailedWeatherTableViewCell", for: indexPath) as! DetailedWeatherTableViewCell

            SwiftTryCatch.try {
                let safeTodayWeatherArray = getTodayWeatherCopy()
                if !safeTodayWeatherArray.isEmpty {
                    cell.updateShadowColor(withColor: UIColor(named: "DetailedWeather_Shadow")!)
                    if safeTodayWeatherArray.indices.contains(indexPath.row) {
                        let weather = safeTodayWeatherArray[indexPath.row]
                        cell.detailedWeatherTemp.text = Array(weather.keys)[0]
                        cell.detailedWeatherDesc.text = weather[Array(weather.keys)[0]]
                    } else {
                        DDLogDebug("MainscreenExtension : today Weather Array contains empty element at row \(indexPath.row)")
                    }

                } else {
                    DDLogDebug("MainscreenExtension : Detailed Weather data not available")
                }

                // DDLogDebug("MainscreenExtension : Detailed Weather - \(cell)")
            } catch: { exception in
                DDLogDebug("MainscreenExtension : Exception in Detailed Weather Array - \(String(describing: exception))")
            }
            return cell

        } else {
            if multiCalendarStatus {
                let cell = tableView.dequeueReusableCell(withIdentifier: "MultipleCalendarEventCell", for: indexPath) as! MultipleCalendarEventCell
                cell.accessibilityIdentifier = "MultipleCalendarEventCell - \(indexPath.row)"
                SwiftTryCatch.try {
                    let safeEventListArray = getEventListCopy()
                    if !safeEventListArray.isEmpty, indexPath.row < safeEventListArray.count {
                        let event = safeEventListArray[indexPath.row]
                        cell.eventStartTime.text = event.0
                        cell.eventName.text = event.2
                        cell.eventCalendar.text = event.3
                        cell.eventDescription.text = event.4
                        removeGradientLayer(fromView: cell)
                        if event.5 { // On going event have to show highlighted cell here
                            cell.addGradientColor(startColor: UIColor(named: "EventsHighlightedStart")!, endColor: UIColor(named: "EventsHighlightedEnd")!, startLocation: 0.1, endLocation: 0.8)
                        } else {
                            cell.addGradientColor(startColor: UIColor(named: "DetailedWeather_Gradiant_Start")!, endColor: UIColor(named: "DetailedWeather_Gradiant_End")!, startLocation: 0.1, endLocation: 0.8)
                        }
                    } else {
                        DDLogDebug("MainscreenExtension : Multi event Array contains invalid element at row \(indexPath.row), array count: \(safeEventListArray.count)")
                    }

                    // DDLogDebug("MainscreenExtension : MultiCalendar events - \(cell)")
                } catch: { exception in
                    DDLogDebug("MainscreenExtension : Exception in multicalendar - \(String(describing: exception))")
                }

                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "SingleCalendarEventCell", for: indexPath) as! SingleCalendarEventCell
                cell.accessibilityIdentifier = "SingleCalendarEventCell - \(indexPath.row)"
                SwiftTryCatch.try {
                    let safeEventListArray = getEventListCopy()
                    if !safeEventListArray.isEmpty, indexPath.row < safeEventListArray.count {
                        let event = safeEventListArray[indexPath.row]
                        cell.eventStartTime.text = event.0
                        cell.eventName.text = event.2
                        cell.eventDescription.text = event.4
                        removeGradientLayer(fromView: cell)
                        if event.5 { // On going event have to show highlighted cell here
                            cell.addGradientColor(startColor: UIColor(named: "EventsHighlightedStart")!, endColor: UIColor(named: "EventsHighlightedEnd")!, startLocation: 0.1, endLocation: 0.8)
                        } else {
                            cell.addGradientColor(startColor: UIColor(named: "DetailedWeather_Gradiant_Start")!, endColor: UIColor(named: "DetailedWeather_Gradiant_End")!, startLocation: 0.1, endLocation: 0.8)
                        }
                    } else {
                        DDLogDebug("MainscreenExtension : Single Event Array contains invalid element at row \(indexPath.row), array count: \(safeEventListArray.count)")
                    }
                    // DDLogDebug("MainscreenExtension : Single Calendar events - \(cell)")
                } catch: { exception in
                    DDLogDebug("MainscreenExtension : Exception in singleCalendar - \(String(describing: exception))")
                }

                return cell
            }
        }
    }
}

// MARK: - MainScreenViewController + UICollectionViewDataSource, UICollectionViewDelegate

extension MainScreenViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        let count = getStatusIndicatorsCopy().count
        DDLogDebug("MainscreenExtension : Status Indicator Array count - \(count)")
        return count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "StatusIndicatorCollectionViewCell",
                                                      for: indexPath) as! StatusIndicatorCollectionViewCell
        cell.accessibilityIdentifier = "Status Indicator Collection - \(indexPath.row)"

        SwiftTryCatch.try {
            // Get a thread-safe copy of the status indicator array
            let safeStatusIndicatorArray = getStatusIndicatorsCopy()

            if !safeStatusIndicatorArray.isEmpty, indexPath.row < safeStatusIndicatorArray.count {
                let item = safeStatusIndicatorArray[indexPath.row]
                cell.StatusTitle.text = item.0
                cell.statusDescription.text = item.1

                // Configure title label for multi-line display (max 2 lines for 45 character limit)
                cell.StatusTitle.numberOfLines = 2
                cell.StatusTitle.lineBreakMode = .byCharWrapping

                // Override UIKit font size with enhanced dynamic sizing for capitals (14-20 range)
                let titleText = item.0
                let uppercaseRatio = Double(titleText.filter(\.isUppercase).count) / Double(titleText.count)
                let hasManyCaps = uppercaseRatio > 0.6 // More than 60% capitals

                let baseFontSize: CGFloat =
                    if hasManyCaps {
                        // Extra small fonts for texts with many capitals
                        titleText.count > 35 ? 12 : (titleText.count > 25 ? 14 : 16)
                    } else {
                        // Normal sizing for mixed case
                        titleText.count > 30 ? 14 : (titleText.count > 20 ? 16 : 18)
                    }

                let finalFontSize = max(12, min(20, baseFontSize)) // Allow down to 12pt for very long text
                cell.StatusTitle.font = UIFont(name: "Avenir Next Bold", size: finalFontSize) ?? UIFont.systemFont(ofSize: finalFontSize)

                // Enable auto-sizing as backup
                cell.StatusTitle.adjustsFontSizeToFitWidth = true
                cell.StatusTitle.minimumScaleFactor = 0.7 // 14/20 = 0.7

                if item.2 == 1 { // status indicator available
                    cell.layer.borderWidth = 0.0
                    cell.layer.borderColor = UIColor.clear.cgColor
                    cell.StatusTitle.textColor = UIColor(named: "StatusIndicatorHighlightedTextColor")
                    cell.statusDescription.textColor = UIColor(named: "StatusIndicatorHighlightedTextColor")
                    removeGradientLayer(fromView: cell)
                    cell.addGradientColor(startColor: UIColor(named: "StatusIndicatorHighlightedEnd")!, endColor: UIColor(named: "StatusIndicatorHighlightedStart")!, startLocation: 0.15, endLocation: 0.85)
                    cell.statusIcon.image = UIImage(named: "USMail")
                } else {
                    cell.layer.borderWidth = 1.0
                    cell.StatusTitle.textColor = UIColor(named: "StatusIndicatorText")
                    cell.statusDescription.textColor = UIColor(named: "StatusIndicatorText")
                    cell.layer.borderColor = UIColor(named: "StatusIndicatorText")?.cgColor
                    cell.backgroundColor = UIColor.clear
                    cell.statusIcon.image = UIImage(named: "TechTalk")
                    removeGradientLayer(fromView: cell)
                }
            } else {
                // Reset cell to empty state when no data is available or index is out of bounds
                cell.StatusTitle.text = ""
                cell.statusDescription.text = ""

                // Configure title label for multi-line display (max 2 lines for 45 character limit)
                cell.StatusTitle.numberOfLines = 2
                cell.StatusTitle.lineBreakMode = .byCharWrapping

                // Set default font size for empty cells
                cell.StatusTitle.font = UIFont(name: "Avenir Next Bold", size: 20) ?? UIFont.systemFont(ofSize: 20) // Default max size

                // Enable auto-sizing as backup
                cell.StatusTitle.adjustsFontSizeToFitWidth = true
                cell.StatusTitle.minimumScaleFactor = 0.7 // 14/20 = 0.7
                cell.statusIcon.image = nil
                removeGradientLayer(fromView: cell)
                cell.backgroundColor = UIColor.clear
                cell.layer.borderWidth = 0.0
                DDLogDebug("MainscreenExtension : No status indicator data for index \(indexPath.row), array count: \(safeStatusIndicatorArray.count)")
            }

            // DDLogDebug("MainscreenExtension : Status Indicator Cell - \(cell)")
        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in collectionView - \(String(describing: exception))")
        }

        return cell
    }

    // MARK: - UICollectionViewDelegateFlowLayout - Smart Spacing Implementation

    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, minimumLineSpacingForSectionAt _: Int) -> CGFloat {
        var spacing: CGFloat = 15 // Default spacing

        SwiftTryCatch.try {
            let totalItems = getStatusIndicatorsCopy().count
            let itemsPerPage = 2

            // Calculate spacing based on total items and page structure
            if totalItems <= itemsPerPage {
                // Single page - use smart spacing for centering
                let collectionViewWidth = collectionView.frame.width
                let cellWidth: CGFloat = 180

                if totalItems == 1 {
                    spacing = 0 // No spacing needed for single item
                } else if totalItems == 2 {
                    // Calculate spacing to center 2 items
                    let totalCellWidth = cellWidth * 2
                    let availableSpace = collectionViewWidth - totalCellWidth
                    spacing = availableSpace / 3 // Equal spacing before, between, and after
                }
            } else {
                // Multiple pages - use consistent spacing for proper paging
                spacing = 15 // Fixed spacing that works well with paging
            }
        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in minimumLineSpacingForSectionAt - \(String(describing: exception))")
        }

        return spacing
    }

    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, insetForSectionAt _: Int) -> UIEdgeInsets {
        var insets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10) // Default insets

        SwiftTryCatch.try {
            let totalItems = getStatusIndicatorsCopy().count
            let collectionViewWidth = collectionView.frame.width
            let cellWidth: CGFloat = 180

            if totalItems == 1 {
                // Align single item to left
                insets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: collectionViewWidth - cellWidth - 10)
            } else {
                // For multiple items, let the flow layout handle positioning with minimal insets
                insets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
            }
        } catch: { exception in
            DDLogDebug("MainscreenExtension : Exception in insetForSectionAt - \(String(describing: exception))")
        }

        return insets
    }
}
