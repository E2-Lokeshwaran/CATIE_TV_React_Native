//
//  LogHandlingModel.swift
//  CATIE-TV
//
//  Created by Pavithran on 16/10/19.
//  Copyright © 2019 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import Foundation

// MARK: - LogHandlingModel

class LogHandlingModel: NSObject {
    func getFilesFromLocalDirectory() -> [String] {
        var paths = [String]()

        DDLogDebug("LogHandling : Get files from local directory")

        let docDirectory: NSString = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0] as NSString
        let logpath = docDirectory.appendingPathComponent("/DebugLogs")

        if FileManager.default.fileExists(atPath: logpath) {
            let fileManager = FileManager.default
            guard let enumerator: FileManager.DirectoryEnumerator = fileManager.enumerator(atPath: logpath) else {
                return paths
            }

            while let element = enumerator.nextObject() as? String {
                if element.hasSuffix("log") { // checks the extension
                    paths.append(logpath + "/" + element)
                }
            }
        } else {
            DDLogDebug("LogHandling : logpath directory doesn't exist")
        }
        DDLogDebug("LogHandling : Path for Log file : \(paths)")
        return paths
    }

    func pushLogsToServerusingJson() {
        SwiftTryCatch.try {
            DDLogDebug("LogHandling : sending upload request to server")

            let pathValues = getFilesFromLocalDirectory()

            var logData = Data()

            if !pathValues.isEmpty {
                for i in 0 ..< pathValues.count {
                    do {
                        try logData.append(NSData(contentsOfFile: pathValues[i]) as Data)
                    } catch {
                        DDLogDebug("LogHandling : error has been cached in file manager log creation \(error.localizedDescription)")
                    }
                }
            }
            // encoding raw data using base64 to transmit over network.
            let base64String = logData.base64EncodedString(options: .endLineWithLineFeed)

            guard let logUploadAPI = URL(string: API.networkAPI().logFileUploadJson.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "") else {
                return
            }

            var request = URLRequest(url: logUploadAPI)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let requestBodyParameters: [String: Any] = ["roomNumber": roomNo!, "logFile": base64String]

            do {
                let body = try JSONSerialization.data(withJSONObject: requestBodyParameters, options: .prettyPrinted)
                DDLogDebug("LogHandling : Data at pushLogsToServerUsingJson : \(body)")

                let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
                let task = session.uploadTask(with: request, from: body) { data, _, error in
                    if error == nil {
                        DDLogDebug("LogHandling : log upload file response \(String(describing: String(data: data!, encoding: String.Encoding.utf8)))")
                    } else {
                        DDLogDebug("LogHandling : Error while uploading files to server")
                    }
                    // Invalidate session after completion to prevent retain cycles
                    session.finishTasksAndInvalidate()
                }
                task.resume()
            } catch {
                DDLogDebug("LogHandling : Error at pushLogsToServerusingJson: \(error.localizedDescription)")
            }

            // Sending file to server using Multi-Form data

            //    func generateBoundaryString() -> String {
            //        return "Boundary-\(NSUUID().uuidString)"
            //    }

            //     func pushLogsToServerUsingMultiForm(){
            //
            //        let pathValues = getFilesFromLocalDirectory()
            ////        print("the log path values \(pathValues)")
            //
            //        var logData = Data()
            //
            //        if(pathValues.count > 0){
            //
            //            for i in (0..<pathValues.count){
            //                do{
            //                    try logData.append(NSData(contentsOfFile: pathValues[i]) as Data)
            //                }catch let error{
            //                    print("error has been cached in file manager log creation \(error)")
            //                }
            //            }
            //        }
            //
            //        let filePath = Bundle.main.url(forResource: "SUR", withExtension: "png")
            //
            //        let audioData = NSData(contentsOf: filePath!)
            //
            //        print("sending upload request to server")
            //        let logUploadAPI = URL(string: API.networkAPI().logFileUploadMultiForm.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "")
            //        var request = URLRequest(url: logUploadAPI!)
            //
            //        // post request configuration
            //        request.httpMethod = "POST"
            //        let boundary = "-------ZveNCE7Ptg3J2HaVLDfN579434247"
            //        request.setValue("multipart/form-data;boundary=--\(boundary)\r\n", forHTTPHeaderField: "Content-Type")
            //
            //        let body = NSMutableData();
            //        body.appendString("--\(boundary)\r\n")
            //        body.appendString("Content-Disposition: form-data; name=\"roomNumber\"\r\n\r\n")
            //        body.appendString("E2TV\r\n")
            //        body.appendString("--\(boundary)\r\n")
            //        body.appendString("Content-Disposition: form-data; name=\"name\"; filename=\"SUR.png\"\r\n")
            //        body.appendString("Content-Type: image/png\r\n\r\n")
            //        body.append(audioData! as Data)
            //        body.appendString("--\(boundary)\r\n")
            //
            //        request.httpBody = body as Data
            //
            //        let postLength = String(format: "%lu", UInt(body.length))
            //
            //        request.setValue(postLength, forHTTPHeaderField: "Content-Length")
            //
            //
            //        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
            //        let task = session.uploadTask(with: request, from: nil, completionHandler: { (data, response, error) in
            //
            //            if(error == nil){
            //                print("data values \(String(describing: String(data: data!, encoding: String.Encoding.utf8)))")
            //            }else{
            //                print("Error while uploading files to server")
            //            }
            //        })
            //        task.resume()
            //    }

        } catch: { exception in
            DDLogDebug("LogHandling : Exception in pushLogsToServerusingJson - \(String(describing: exception))")
        }
    }
}

// MARK: URLSessionDelegate, URLSessionDataDelegate

extension LogHandlingModel: URLSessionDelegate, URLSessionDataDelegate {
    func urlSession(_: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        SwiftTryCatch.try {
            completionHandler(
                URLSession.AuthChallengeDisposition.useCredential,
                URLCredential(trust:
                    challenge.protectionSpace.serverTrust!)
            )
            DDLogDebug("LogHandling : URLAuthentication Challenge Success")
        } catch: { exception in
            DDLogDebug("LogHandling : Exception in URLAuthenticationChallenge - \(String(describing: exception))")
        }
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError _: Error?) {
        SwiftTryCatch.try {
            DDLogDebug("LogHandling : NSURLSession completed with error delegate called")
            let response = task.response as? HTTPURLResponse
            DDLogDebug("LogHandling : Response status - \(String(describing: response?.statusCode))")
        } catch: { exception in
            DDLogDebug("LogHandling : Exception in didCompleteWithError - \(String(describing: exception))")
        }
    }

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive _: Data) {
        SwiftTryCatch.try {
            DDLogDebug("LogHandling : NSURLSession did receive delegate called")
        } catch: { exception in
            DDLogDebug("LogHandling : Exception in didReceive- \(String(describing: exception))")
        }
    }
}
