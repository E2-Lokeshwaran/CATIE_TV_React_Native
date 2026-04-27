//
//  RegistrationModel.swift
//  CATIE-TV
//
//  Created by Admin on 24/04/19.
//  Copyright © 2019 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift

// MARK: - RegistrationViewController + URLSessionDelegate, URLSessionDataDelegate

extension RegistrationViewController: URLSessionDelegate, URLSessionDataDelegate {
    func urlSession(_: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        SwiftTryCatch.try {
            completionHandler(
                URLSession.AuthChallengeDisposition.useCredential,
                URLCredential(trust:
                    challenge.protectionSpace.serverTrust!)
            )
            DDLogDebug("Registration : URLAuthentication Challenge")
        } catch: { exception in
            DDLogDebug("Registration : Exception in URLAuthenticationChallenge - \(String(describing: exception))")
        }
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        SwiftTryCatch.try {
            let response = task.response as? HTTPURLResponse

            DDLogDebug("Registration : Response status - \(String(describing: response?.statusCode))")

            if error != nil {
                DDLogDebug("Registration : NSURLSession connection failed at registrationModel \(String(describing: error?.localizedDescription))")
                DispatchQueue.main.async {
                    self.loadingIndicator?.stopAnimating()
                    if self.isDetailsModified {
                        self.cancel.isHidden = false
                        self.modify.isHidden = false
                    } else {
                        self.save.isHidden = false
                    }
                    AlertMessage().displayAlertMessage(onSource: self, alertMessage: "Please Enter Valid Domain/IP Address")
                }
            }

        } catch: { exception in
            DDLogDebug("Registration : Exception in didCompleteWithError - \(String(describing: exception))")
        }
    }

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
        SwiftTryCatch.try {
            DispatchQueue.main.async {
                self.loadingIndicator?.stopAnimating()
                if self.isDetailsModified {
                    self.cancel.isHidden = false
                    self.modify.isHidden = false
                } else {
                    self.save.isHidden = false
                }
            }

            let decoder = JSONDecoder()
            do {
                let registrationResponse = try decoder.decode(RegistrationResponseModel.self, from: data)
                DDLogDebug("Registration : Parsing Json data from response - \(registrationResponse)")

                if registrationResponse.status == 1 {
                    DispatchQueue.main.async {
                        if self.isDetailsModified {
                            self.mainViewdelegate?.stopHomeViewUpdates()
                            self.mainViewdelegate?.updateRadioIcon(status: false, isNetworkDown: false)
                            self.mainViewdelegate?.deleteLocalStorage()
                            socketConnection.closeSocketConnection()
                            ApplicationState().resetUserDefaults()
                        }
                        self.mainViewdelegate = nil

                        UserDefaults.standard.set(self.domainField.text, forKey: "domainAddress")
                        UserDefaults.standard.set(self.roomNumber.text, forKey: "roomNumber")
                        UserDefaults.standard.set(registrationResponse.userId ?? "", forKey: "userId")
                        UserDefaults.standard.synchronize()
                        DDLogDebug("Registration : Room registration successful")

                        DispatchQueue.main.async {
                            tvStatus = 1
                            updateUIFromLocalData = false
                        }
                        self.dismiss(animated: true, completion: nil)
                    }

                } else {
                    AlertMessage().displayAlertMessage(onSource: self, alertMessage: registrationResponse.message)
                    DDLogDebug("Registration : Room registration Unsuccessful")
                }
            } catch {
                DDLogDebug("Registration : parsing error at urlsession of registrationModel \(error.localizedDescription)")

                AlertMessage().displayAlertMessage(onSource: self, alertMessage: "Unable to register, Please contact admin!")
            }

        } catch: { exception in
            DDLogDebug("Registration : Exception in didReceive - \(String(describing: exception))")
        }
    }
}

// MARK: - RegistrationResponseModel

struct RegistrationResponseModel: Codable {
    enum CodingKeys: String, CodingKey {
        case status
        case message
        case userId
    }

    var status: Int
    var message: String
    var userId: String?
}
