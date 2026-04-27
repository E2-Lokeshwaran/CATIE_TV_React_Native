//
//  RegistrationViewController.swift
//  CATIE-TV
//
//  Created by Admin on 24/04/19.
//  Copyright © 2019 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import UIKit

class RegistrationViewController: UIViewController {
    // MARK: - UI Interfaces

    var mainViewdelegate: MainScreenDelegate?

    @IBOutlet var domainField: UITextField!

    @IBOutlet var roomNumber: UITextField!

    @IBOutlet var save: UIButton!

    @IBOutlet var cancel: UIButton!

    @IBOutlet var modify: UIButton!

    @IBOutlet var loadingIndicator: UIActivityIndicatorView!

    @IBOutlet var versionNumber: UILabel!

    var isDetailsModified: Bool = false

    var SettingsChangeObservor: Any?
    var isMDMPushReceived = false

    var wasInPortraitMode: Bool = false

    // MARK: - View Controller Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        SwiftTryCatch.try {
            DDLogDebug("---------------RegistrationVC : viewDidLoad---------------")
        } catch: { exception in
            DDLogDebug("RegistrationVC : Exception in viewDidLoad - \(String(describing: exception))")
        }
    }

    override func viewDidAppear(_: Bool) {
        super.viewDidAppear(true)

        SwiftTryCatch.try {
            DDLogDebug("---------------RegistrationVC : viewDidAppear---------------")

            // Check before release, need to do modification in displaying version number for AppStore release.
            let version = Bundle.main.infoDictionary!["CFBundleShortVersionString"]! as! String
            let build = Bundle.main.infoDictionary!["CFBundleVersion"] as! String

            versionNumber?.text = "V " + version + "-" + build

            if UserDefaults.standard.value(forKey: "roomNumber") as? String != "" {
                cancel?.isHidden = false
                modify?.isHidden = false

                domainField?.text = UserDefaults.standard.value(forKey: "domainAddress") as? String
                roomNumber?.text = UserDefaults.standard.value(forKey: "roomNumber") as? String

            } else {
                save?.isHidden = false
            }

            DDLogDebug("RegistrationVC : Notification added to observe MDM Changes")
            SettingsChangeObservor = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: OperationQueue.main, using: { [weak self] _ in
                guard let self else {
                    return
                }

                DDLogDebug("RegistrationVC : readAppConfigValues notification received")
                readAppConfigValues()
            })

            readAppConfigValues() // to trigger MDM Push changes
        } catch: { exception in
            DDLogDebug("RegistrationVC : Exception in viewDidAppear - \(String(describing: exception))")
        }
    }

    override func viewWillDisappear(_: Bool) {
        super.viewWillDisappear(true)

        SwiftTryCatch.try {
            DDLogDebug("---------------Registration : viewWillDisappear---------------")
            DDLogDebug("RegistrationVC : observe MDM Changes Notification Removed")
            if SettingsChangeObservor != nil {
                NotificationCenter.default.removeObserver(SettingsChangeObservor!)
            }

        } catch: { exception in
            DDLogDebug("RegistrationVC : Exception in viewWillDisappear - \(String(describing: exception))")
        }
    }

    func readAppConfigValues() {
        SwiftTryCatch.try {
            DDLogDebug("RegistrationVC : readAppConfigValues() Called")

            if let managedConf = UserDefaults.standard.object(forKey: "com.apple.configuration.managed") as? [String: Any?] {
                DDLogDebug("RegistrationVC : TmanagedConfig value received \(managedConf)")

                if let serverURL = managedConf["serverIP"] as? String {
                    if let roomNum = managedConf["roomNumber"] as? String {
                        DDLogDebug("RegistrationVC : Printing MDM Values to the console")
                        DDLogDebug("RegistrationVC : managedConfig value serverIP \(serverURL)")
                        DDLogDebug("RegistrationVC : managedConfig value roomNumber \(roomNum)")

                        if serverURL != "", roomNum != "" {
                            if !isMDMPushReceived {
                                isMDMPushReceived = true // to load MDM configuration values on a valid first time alone

                                if UserDefaults.standard.value(forKey: "roomNumber") as? String != "" {
                                    DDLogDebug("RegistrationVC : calling modify details")
                                    modifyMDMValues(withServerIP: serverURL, andRoomNumber: roomNum)
                                } else {
                                    DDLogDebug("RegistrationVC : calling save details")
                                    saveMDMValues(withServerIP: serverURL, andRoomNumber: roomNum)
                                }
                            } else {
                                DDLogDebug("RegistrationVC : MDM Push Values already received")
                            }
                        } else {
                            DDLogDebug("RegistrationVC : MDM Push Values validation failed")
                        }

                    } else {
                        DDLogDebug("RegistrationVC : Unable to find roomNumber value")
                    }
                } else {
                    DDLogDebug("RegistrationVC : Unable to find serverIP value")
                }
            } else {
                DDLogDebug("RegistrationVC : Unable to find manged configuration values")
            }
        } catch: { exception in
            DDLogDebug("RegistrationVC : Exception in readAppConfigValues - \(String(describing: exception))")
        }
    }

    // MARK: - Registration Actions

    /// Registration by clicking save button
    @IBAction func save(_: UIButton) {
        SwiftTryCatch.try {
            DDLogDebug("RegistrationVC : save details Button Pressed ")

            if domainField?.text != "", roomNumber?.text != "" {
                isDetailsModified = false
                save?.isHidden = true
                registerRoomNumber()
            } else {
                AlertMessage().displayAlertMessage(onSource: self, alertMessage: "Enter  Valid IP Address / Device Number")
                DDLogDebug("RegistrationVC : save details failed")
            }
        } catch: { exception in
            DDLogDebug("RegistrationVC : Exception in save - \(String(describing: exception))")
        }
    }

    /// Registration by applying Save MDM Values
    func saveMDMValues(withServerIP: String, andRoomNumber: String) {
        SwiftTryCatch.try {
            DDLogDebug("RegistrationVC : saveMDMValues Called")

            DispatchQueue.main.async {
                self.domainField?.text = withServerIP
                self.roomNumber?.text = andRoomNumber
                self.save?.isHidden = true
            }
            isDetailsModified = false
            registerRoomNumberWithMDMValues(serverIP: withServerIP, roomNumber: andRoomNumber)
        } catch: { exception in
            DDLogDebug("RegistrationVC : Exception in saveMDMValues - \(String(describing: exception))")
        }
    }

    @IBAction func cancel(_: UIButton) {
        SwiftTryCatch.try {
            DDLogDebug("RegistrationVC : cancel details button pressed")

            // Before dismissing, check if we need to return to portrait mode
            if wasInPortraitMode, let mainVC = mainViewdelegate as? MainScreenViewController {
                DDLogDebug("RegistrationVC : Returning to portrait mode after cancellation")
                mainVC.isPortraitModeEnabled = true
            }

            self.dismiss(animated: true, completion: nil)
        } catch: { exception in
            DDLogDebug("RegistrationVC : Exception in cancel - \(String(describing: exception))")
        }
    }

    /// Registration by clicking modify button
    @IBAction func modify(_: UIButton) {
        SwiftTryCatch.try {
            DDLogDebug("RegistrationVC : Modify details called")

            if domainField?.text != "", roomNumber?.text != "" {
                if domainField?.text == UserDefaults.standard.value(forKey: "domainAddress") as? String, roomNumber?.text == UserDefaults.standard.value(forKey: "roomNumber") as? String {
                    AlertMessage().displayAlertMessage(onSource: self, alertMessage: "Details are not modified")
                    DDLogDebug("RegistrationVC : Modify details failed with existing values")
                } else {
                    isDetailsModified = true
                    cancel?.isHidden = true
                    modify?.isHidden = true
                    registerRoomNumber()
                }

            } else {
                AlertMessage().displayAlertMessage(onSource: self, alertMessage: "Enter  Valid IP Address / Device Number")
                DDLogDebug("RegistrationVC : Modify details failed")
            }
        } catch: { exception in
            DDLogDebug("RegistrationVC : Exception in modify - \(String(describing: exception))")
        }
    }

    /// Registration by applying Modify MDM Values
    func modifyMDMValues(withServerIP: String, andRoomNumber: String) {
        SwiftTryCatch.try {
            DDLogDebug("RegistrationVC : modifyMDMValues Called")

            DispatchQueue.main.async {
                self.domainField?.text = withServerIP
                self.roomNumber?.text = andRoomNumber
            }

            if withServerIP == UserDefaults.standard.value(forKey: "domainAddress") as? String, andRoomNumber == UserDefaults.standard.value(forKey: "roomNumber") as? String {
                AlertMessage().displayAlertMessage(onSource: self, alertMessage: "Details are not modified")
                DDLogDebug("RegistrationVC : MDM Modify details failed with existing values")
            } else {
                DispatchQueue.main.async {
                    self.cancel?.isHidden = true
                    self.modify?.isHidden = true
                }
                isDetailsModified = true
                registerRoomNumberWithMDMValues(serverIP: withServerIP, roomNumber: andRoomNumber)
            }
        } catch: { exception in
            DDLogDebug("RegistrationVC : Exception in modifyMDMValues - \(String(describing: exception))")
        }
    }

    func registerRoomNumber() {
        SwiftTryCatch.try {
            DDLogDebug("RegistrationVC : registerRoomNumber Called")

            DispatchQueue.main.async {
                self.loadingIndicator?.startAnimating()
            }

            if domainField?.text != nil, roomNumber?.text != nil {
                let registrationURL = "https://\(domainField?.text ?? "")/catie/api/user/tvLogin"

                var request = URLRequest(url: URL(string: registrationURL.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "")!)

                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpMethod = "POST"
                let requestBodyParameters = ["roomNo": roomNumber?.text ?? ""]

                DDLogDebug("RegistrationVC : Register Room is called with request \(request)****")

                do {
                    let body = try JSONSerialization.data(withJSONObject: requestBodyParameters, options: .prettyPrinted)
                    request.httpBody = body

                } catch {
                    DDLogDebug("RegistrationVC : Parsing error at registerRoomNumber \(error.localizedDescription)****")
                }

                let defaultURLSession = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)

                let registrationTask = defaultURLSession.dataTask(with: request)
                registrationTask.resume()
                defaultURLSession.finishTasksAndInvalidate()
            } else {
                DDLogDebug("RegistrationVC : Domain & Room no are nil unable to do registration")
            }

        } catch: { exception in
            DDLogDebug("RegistrationVC : Exception in registerRoomNumber - \(String(describing: exception))")
        }
    }

    func registerRoomNumberWithMDMValues(serverIP: String, roomNumber: String) {
        SwiftTryCatch.try {
            DispatchQueue.main.async {
                self.loadingIndicator?.startAnimating()
            }

            let registrationURL = "https://\(serverIP)/catie/api/user/tvLogin"

            var request = URLRequest(url: URL(string: registrationURL.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "")!)

            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpMethod = "POST"
            let requestBodyParameters = ["roomNo": roomNumber]

            DDLogDebug("RegistrationVC : MDM Register Room is called with request \(request)****")

            do {
                let body = try JSONSerialization.data(withJSONObject: requestBodyParameters, options: .prettyPrinted)
                request.httpBody = body

            } catch {
                DDLogDebug("RegistrationVC : Parsing error at mdm registerRoomNumber\(error.localizedDescription)****")
            }

            let defaultURLSession = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)

            let registrationTask = defaultURLSession.dataTask(with: request)
            registrationTask.resume()
            defaultURLSession.finishTasksAndInvalidate()

        } catch: { exception in
            DDLogDebug("RegistrationVC : Exception in registerRoomNumberWithMDMValues - \(String(describing: exception))")
        }
    }
}
