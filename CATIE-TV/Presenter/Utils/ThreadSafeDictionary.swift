// MARK: - StatusCodeDict

class StatusCodeDict {
    // MARK: Internal

    // MARK: Singleton Instance

    static let shared = StatusCodeDict()

    func getValue(key: String) -> Int? {
        var result: Int?
        dispatchQueue.sync {
            result = threadUnsafeDict[key]
        }
        return result
    }

    func setObject(key: String, value: Int?) {
        dispatchQueue.async(flags: .barrier) {
            self.threadUnsafeDict[key] = value
        }
    }

    // MARK: Private

    private var threadUnsafeDict = [String: Int]()
    private let dispatchQueue = DispatchQueue(label: "com.statussolutions.catietv.StatusCodeDict", attributes: .concurrent)
}

// MARK: - OngoingAPICallDict

class OngoingAPICallDict {
    // MARK: Internal

    // MARK: Singleton Instance

    static let shared = OngoingAPICallDict()

    func getValue(key: String) -> Bool? {
        var result: Bool?
        dispatchQueue.sync {
            result = threadUnsafeDict[key]
        }
        return result
    }

    func setObject(key: String, value: Bool?) {
        dispatchQueue.async(flags: .barrier) {
            self.threadUnsafeDict[key] = value
        }
    }

    // MARK: Private

    private var threadUnsafeDict = [
        "Weather": false,
        "Events": false,
        "StatusIndicator": false,
        "Carousal": false,
        "Radio": false,
        "SiteLogo": false,
        "ScrollMessage": false,
        "SaraAlert": false,
        "Clock": false,
        "CustomPage": false,
    ]
    private let dispatchQueue = DispatchQueue(label: "com.statussolutions.catietv.OngoingAPICallDict", attributes: .concurrent)
}

// MARK: - PendingAPICallRequestDict

class PendingAPICallRequestDict {
    // MARK: Internal

    // MARK: Singleton Instance

    static let shared = PendingAPICallRequestDict()

    func getValue(key: String) -> Bool? {
        var result: Bool?
        dispatchQueue.sync {
            result = threadUnsafeDict[key]
        }
        return result
    }

    func setObject(key: String, value: Bool?) {
        dispatchQueue.async(flags: .barrier) {
            self.threadUnsafeDict[key] = value
        }
    }

    // MARK: Private

    private var threadUnsafeDict = [
        "Weather": false,
        "Events": false,
        "StatusIndicator": false,
        "Carousal": false,
        "Radio": false,
        "SiteLogo": false,
        "ScrollMessage": false,
        "SaraAlert": false,
        "Clock": false,
        "CustomPage": false,
    ]
    private let dispatchQueue = DispatchQueue(label: "com.statussolutions.catietv.PendingAPICallRequestDict", attributes: .concurrent)
}
