//
//  WeatherModel.swift
//  CATIE-TV
//
//  Created by Admin on 25/04/19.
//  Copyright © 2019 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import CoreData
import Foundation

// MARK: - WeatherModel

class WeatherModel: NSObject {
    // MARK: Lifecycle

    deinit {
        DDLogDebug("WeatherModel: deinit - cleaning up resources")

        // Cancel any running data task to prevent memory leaks
        if let task = weatherDataTask {
            if task.state == .running {
                task.cancel()
                DDLogDebug("WeatherModel: cancelled running weatherDataTask")
            }
        }

        // Invalidate URLSession to break delegate retain cycle
        urlSession?.invalidateAndCancel()
        urlSession = nil

        // Clean up all resources
        reset()

        DDLogDebug("WeatherModel: deinit - all resources cleaned up")
    }

    // MARK: Internal

    weak var mainViewdelegate: MainScreenDelegate?
    weak var tempMainViewDelegate: MainScreenDelegate?

    var weatherDataTask: URLSessionDataTask?
    var urlSession: URLSession?
    var weatherData: Data!
    var managedObjectContext: NSManagedObjectContext?
    var appDel: AppDelegate?
    var weather: Weather?
    var detailedWeather: DetailedWeather?
    var forecastWeather: ForeCastWeather?

    func getWeatherData() {
        SwiftTryCatch.try {
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                if appDel == nil {
                    appDel = UIApplication.shared.delegate as? AppDelegate
                }

                managedObjectContext = appDel!.persistentContainer.newBackgroundContext()
            }

            tempMainViewDelegate = mainViewdelegate

            DDLogDebug("Weather : Get Weather Data from server")

            let weatherAPI = URL(string: API.networkAPI().weatherURL.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "")
            let request = URLRequest(url: weatherAPI!)

            var canMakeNewWeatherRequest = false
            if weatherDataTask != nil {
                switch weatherDataTask!.state {
                case .running:
                    DDLogDebug("Weather : weatherDataTask state is running ")
                    canMakeNewWeatherRequest = false

                case .suspended:
                    DDLogDebug("Weather : weatherDataTask state is suspended ")
                    canMakeNewWeatherRequest = true

                case .canceling:
                    DDLogDebug("Weather : weatherDataTask state is canceling ")
                    canMakeNewWeatherRequest = true

                case .completed:
                    DDLogDebug("Weather : weatherDataTask state is completed ")
                    canMakeNewWeatherRequest = true

                default:
                    DDLogDebug("Weather : weatherDataTask state is default ")
                    canMakeNewWeatherRequest = true
                }
            } else {
                canMakeNewWeatherRequest = true
            }

            if canMakeNewWeatherRequest {
                weatherDataTask = nil
                weatherData = Data()

                DDLogDebug("Weather : Calling weather API with url \(String(describing: weatherAPI))")

                // Invalidate previous session to prevent accumulation
                urlSession?.invalidateAndCancel()
                urlSession = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
                weatherDataTask = urlSession?.dataTask(with: request)
                weatherDataTask?.resume()
            } else {
                DDLogDebug("Weather : Already scheduled weather task is in-progress ignoring new coming task...")
            }
        } catch: { exception in
            DDLogDebug("Weather : Exception in getWeatherData - \(String(describing: exception))")
        }
    }

    func reset() {
        appDel = nil
        weather = nil
        detailedWeather = nil
        forecastWeather = nil
        weatherDataTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        managedObjectContext = nil
        tempMainViewDelegate = nil
        weatherData = Data()
    }
}

// MARK: URLSessionDelegate, URLSessionDataDelegate

extension WeatherModel: URLSessionDelegate, URLSessionDataDelegate {
    func urlSession(_: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        SwiftTryCatch.try {
            completionHandler(
                URLSession.AuthChallengeDisposition.useCredential,
                URLCredential(trust:
                    challenge.protectionSpace.serverTrust!)
            )
            DDLogDebug("Weather : URLAuthentication Challenge")
        } catch: { exception in
            DDLogDebug("Weather : Exception in URLAuthenticationChallenge - \(String(describing: exception))")
        }
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        SwiftTryCatch.try {
            if mainViewdelegate == nil {
                mainViewdelegate = tempMainViewDelegate
            }
            if managedObjectContext == nil {
                if appDel == nil {
                    DispatchQueue.main.async { [weak self] in
                        guard let self else {
                            return
                        }

                        appDel = UIApplication.shared.delegate as? AppDelegate
                        managedObjectContext = appDel?.persistentContainer.newBackgroundContext()
                    }
                } else {
                    managedObjectContext = appDel?.persistentContainer.newBackgroundContext()
                }
            }

            DDLogDebug("Weather : MainViewDelegate - \(String(describing: mainViewdelegate))")

            let response = task.response as? HTTPURLResponse

            let safeDict = StatusCodeDict.shared
            safeDict.setObject(key: "statusCodeForWeather", value: response?.statusCode ?? 0)

            DDLogDebug("Weather : Response status - \(String(describing: response?.statusCode))")

            if error != nil {
                DDLogDebug("Weather : NSURLSession connection error at weatherModel \(String(describing: error?.localizedDescription))")

                reset()
                if tvStatus == 1 {
                    self.mainViewdelegate?.weatherFailureResponse(message: error?.localizedDescription ?? "", isNetworkError: true)
                } else {
                    DDLogDebug("Weather : No room is registered")
                }
            } else {
                if tvStatus == 1 {
                    if OngoingAPICallDict.shared.getValue(key: "Weather") == false {
                        DDLogDebug("Weather : Process Weather Data")
                        OngoingAPICallDict.shared.setObject(key: "Weather", value: true)
                        processWeatherResponseData()
                    } else {
                        DDLogDebug("Weather : Ongoing weather process available")
                        PendingAPICallRequestDict.shared.setObject(key: "Weather", value: true)
                    }

                } else {
                    DDLogDebug("Weather : No room is registered so not saving weather response")
                    reset()
                    OngoingAPICallDict.shared.setObject(key: "Weather", value: false)
                }
            }
        } catch: { exception in
            DDLogDebug("Weather : Exception in didCompleteWithError - \(String(describing: exception))")
            reset()
        }
    }

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
        SwiftTryCatch.try {
            if !data.isEmpty {
                weatherData.append(data)
                DDLogDebug("Weather : Received data successfully")
            } else {
                DDLogDebug("Weather : Received empty value on didReceive data at WeatherModel")
            }
        } catch: { exception in
            DDLogDebug("Weather : Exception in didReceive - \(String(describing: exception))")
        }
    }

    func downloadWeatherIcons(weatherResponse: WeatherResponseModel?) {
        SwiftTryCatch.try {
            if managedObjectContext == nil {
                DDLogDebug("Weather : Error in downloadWeatherIcons managedObjectContext is nil")
                if appDel == nil {
                    DispatchQueue.main.async { [weak self] in
                        guard let self else {
                            return
                        }

                        appDel = UIApplication.shared.delegate as? AppDelegate
                        managedObjectContext = appDel?.persistentContainer.newBackgroundContext()
                    }
                } else {
                    managedObjectContext = appDel?.persistentContainer.newBackgroundContext()
                }
            }

            for index in 0 ..< (weatherResponse?.data.foreCastBeans.count ?? 0) {
                let iconURL = API.networkAPI().imageDownloadURL + (weatherResponse?.data.foreCastBeans[index].url ?? "")
                let day = weatherResponse?.data.foreCastBeans[index].day ?? ""
                if let context = managedObjectContext {
                    fileDownloader().downloadData(key: day, value: iconURL, entity: "ForeCastWeather", managedObjectContext: context)
                } else {
                    DDLogDebug("managedObjectContext is nil - Cannot download data for ForeCastWeather.")
                }
            }

        } catch: { exception in
            DDLogDebug("Weather : Exception in downloadWeatherIcons - \(String(describing: exception))")
        }
    }

    func processWeatherResponseData() {
        SwiftTryCatch.try {
            if managedObjectContext == nil {
                DDLogDebug("Weather : Error in processWeatherResponseData managedObjectContext is nil")
                if appDel == nil {
                    DispatchQueue.main.async { [weak self] in
                        guard let self else {
                            return
                        }

                        appDel = UIApplication.shared.delegate as? AppDelegate
                        managedObjectContext = appDel?.persistentContainer.newBackgroundContext()
                    }
                } else {
                    managedObjectContext = appDel?.persistentContainer.newBackgroundContext()
                }
            }

            if weatherData != nil, !weatherData.isEmpty {
                let jsonData = String(decoding: weatherData, as: UTF8.self)
                DDLogDebug("Weather : Data - \(jsonData)")
                let decoder = JSONDecoder()

                do {
                    DDLogDebug("Weather : Parsing Json data from response")
                    let weatherResponse = try decoder.decode(WeatherResponseModel.self, from: weatherData)

                    DDLogDebug("Weather : Weather Json Data - \(weatherResponse)")

                    if weatherResponse.status == "success" {
                        DataHandler().deleteRecords("Weather", managedObjectContext)

                        let iconURL = API.networkAPI().imageDownloadURL + (weatherResponse.data.url ?? "")

                        managedObjectContext?.performAndWait {
                            weather = NSEntityDescription.insertNewObject(forEntityName: "Weather", into: managedObjectContext!) as? Weather

                            weather?.temperature = weatherResponse.data.temperature ?? ""
                            weather?.city = weatherResponse.data.city ?? ""
                            weather?.temperatureText = weatherResponse.data.temperatureText ?? ""
                            weather?.date = weatherResponse.data.date ?? ""
                            weather?.webSource = weatherResponse.data.webSource ?? ""
                            weather?.status = weatherResponse.status

                            do {
                                try managedObjectContext?.save()
                                DDLogDebug("Weather : Saved Weather response in coredata")
                            } catch {
                                DDLogDebug("Weather : Unable to save Weather response in coredata")
                            }
                            DDLogDebug("Weather : Weather data - \(String(describing: weather))")
                        }

                        weatherIconsDownloaded = 0

                        if let context = managedObjectContext {
                            fileDownloader().downloadData(key: weatherResponse.data.date ?? "", value: iconURL, entity: "Weather", managedObjectContext: context)
                        } else {
                            DDLogDebug("managedObjectContext is nil - Cannot download data for Weather.")
                        }

                        DataHandler().deleteRecords("DetailedWeather", managedObjectContext)

                        managedObjectContext?.performAndWait {
                            detailedWeather = NSEntityDescription.insertNewObject(forEntityName: "DetailedWeather", into: managedObjectContext!) as? DetailedWeather

                            detailedWeather?.feelsLike = weatherResponse.data.weatherDetailBean.feelsLike ?? ""
                            detailedWeather?.pressure = weatherResponse.data.weatherDetailBean.pressure ?? ""
                            detailedWeather?.humidity = weatherResponse.data.weatherDetailBean.humidity ?? ""
                            detailedWeather?.wind = weatherResponse.data.weatherDetailBean.wind ?? ""
                            detailedWeather?.visibilty = weatherResponse.data.weatherDetailBean.visiblity ?? ""
                            detailedWeather?.sunRise = weatherResponse.data.weatherDetailBean.sunRise ?? ""
                            detailedWeather?.sunSet = weatherResponse.data.weatherDetailBean.sunSet ?? ""
                            detailedWeather?.currentDayHigh = weatherResponse.data.weatherDetailBean.currentDayHigh ?? ""
                            detailedWeather?.currentDayLow = weatherResponse.data.weatherDetailBean.currentDayLow ?? ""

                            do {
                                try managedObjectContext?.save()
                                DDLogDebug("Weather : Saved DetailedWeather response in coredata")
                            } catch {
                                DDLogDebug("Weather : Unable to save DetailedWeather response in coredata")
                            }
                            DDLogDebug("Weather : detailedWeather data - \(String(describing: detailedWeather))")
                        }

                        DDLogDebug("Weather :  ForeCastWeather icons - \(weatherResponse.data.foreCastBeans.count)")

                        DataHandler().deleteRecords("ForeCastWeather", managedObjectContext)

                        for index in 0 ..< weatherResponse.data.foreCastBeans.count {
                            managedObjectContext?.performAndWait {
                                forecastWeather = NSEntityDescription.insertNewObject(forEntityName: "ForeCastWeather", into: managedObjectContext!) as? ForeCastWeather
                                forecastWeather?.day = weatherResponse.data.foreCastBeans[index].day ?? ""
                                forecastWeather?.high = weatherResponse.data.foreCastBeans[index].high ?? ""
                                forecastWeather?.low = weatherResponse.data.foreCastBeans[index].low ?? ""
                                forecastWeather?.des = weatherResponse.data.foreCastBeans[index].summary ?? ""

                                do {
                                    try managedObjectContext?.save()
                                    DDLogDebug("Weather : Saved forecastWeather response in coredata")
                                } catch {
                                    DDLogDebug("Weather : Unable to save forecastWeather response in coredata")
                                }
                                DDLogDebug("Weather : forecastWeather data - \(String(describing: forecastWeather))")
                            }
                        }

                        DDLogDebug("Weather : Weather fetching was successful")
                        weatherDataTask = nil
                        weatherData = Data()

                        if !weatherResponse.data.foreCastBeans.isEmpty {
                            downloadWeatherIcons(weatherResponse: weatherResponse)
                            reset()
                        } else {
                            reset()
                            self.mainViewdelegate?.weatherSuccessResponse()
                        }

                    } else {
                        DDLogDebug("Weather : Weather fetching was unsuccessful")
                        reset()
                        self.mainViewdelegate?.weatherFailureResponse(message: "Unable to fetch weather!")
                    }

                } catch {
                    reset()
                    DDLogDebug("Weather : parsing error at urlsession of weatherModel \(error)")
                    self.mainViewdelegate?.weatherFailureResponse(message: error.localizedDescription)
                }
            } else {
                reset()
                DDLogDebug("Weather : Received empty value on didCompleteEror at WeatherModel")
                self.mainViewdelegate?.weatherFailureResponse(message: "Unable to fetch weather!")
            }
        } catch: { exception in
            DDLogDebug("Weather : Exception in processWeatherResponseData - \(String(describing: exception))")
        }
    }
}

// MARK: - WeatherResponseModel

struct WeatherResponseModel: Codable {
    var data: WeatherData
    var status: String
}

// MARK: - WeatherData

struct WeatherData: Codable {
    var url: String?
    var temperature: String?
    var temperatureText: String?
    var date: String?
    var city: String?
    var webSource: String?
    var weatherDetailBean: DetailedData
    var foreCastBeans: [ForeCastData]
}

// MARK: - DetailedData

struct DetailedData: Codable {
    var feelsLike: String?
    var pressure: String?
    var humidity: String?
    var wind: String?
    var visiblity: String?
    var sunRise: String?
    var sunSet: String?
    var currentDayHigh: String?
    var currentDayLow: String?
}

// MARK: - ForeCastData

struct ForeCastData: Codable {
    var day: String?
    var high: String?
    var low: String?
    var url: String?
    var summary: String?
}
