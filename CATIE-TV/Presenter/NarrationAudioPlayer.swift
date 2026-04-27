import AVKit
import CocoaLumberjackSwift

extension Notification.Name {
    static let narrationDidStart = Notification.Name("narrationDidStart")
    static let narrationDidFailToLoad = Notification.Name("narrationDidFailToLoad")
}

// MARK: - NarrationAudioPlayerDelegate

/// This delegate helps us to send the player finished callback to MainScreenViewController
protocol NarrationAudioPlayerDelegate: AnyObject {
    func narrationAudioPlayerDidFinishPlaying()
}

// MARK: - URLSessionDelegateHandler

/// Handles the certificate invalid when fetching the audio file
class URLSessionDelegateHandler: NSObject, URLSessionDelegate {
    func urlSession(_: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
        completionHandler(.useCredential, credential)
    }
}

// MARK: - NarrationAudioPlayer

/// Handles the narration audio playback
class NarrationAudioPlayer: NSObject, AVAudioPlayerDelegate {
    // MARK: Lifecycle

    deinit {
        DDLogDebug("NarrationAudioPlayer: deinit - cleaning up resources")
        // Clean up all resources to prevent memory leaks
        stopCurrentAudio()
        cancelCurrentDownload()

        // Invalidate URLSession to break any potential retain cycles
        currentURLSession?.invalidateAndCancel()
        currentURLSession = nil

        // Clear delegate to prevent potential callbacks to deallocated object
        delegate = nil

        DDLogDebug("NarrationAudioPlayer: deinit - all resources cleaned up")
    }

    // MARK: Internal

    // Add a weak delegate property
    weak var delegate: NarrationAudioPlayerDelegate?
    var audioPlayer: AVAudioPlayer?
    var currentURLSession: URLSession?

    static func sharedInstance() -> NarrationAudioPlayer {
        shared
    }

    func playAudio(from urlString: String, forSlideIndex slideIndex: Int, completion: @escaping (Double) -> Void) {
        DDLogDebug("NarrationAudioPlayer: Request to play audio for slide \(slideIndex), URL: \(urlString)")

        // Cancel any ongoing download if a new audio is requested
        cancelCurrentDownload()

        // Store the slide index we're playing audio for
        requestedSlideIndex = slideIndex

        // Update current audio URL
        currentAudioURL = urlString

        guard !isDownloading else {
            DDLogDebug("NarrationAudioPlayer: Already downloading, ignoring request for slide \(slideIndex)")
            return
        }

        // Validate URL before proceeding
        guard let url = URL(string: urlString) else {
            DDLogDebug("NarrationAudioPlayer: Invalid URL string: \(urlString)")
            notifyDownloadFailure(forSlideIndex: slideIndex)
            completion(0)
            return
        }

        isDownloading = true
        stopCurrentAudio()

        // Create a serial queue for audio operations
        let audioProcessingQueue = DispatchQueue(label: "com.catie.audioProcessing", qos: .userInitiated)

        // Download and process on background thread
        audioProcessingQueue.async { [weak self] in
            guard let self else {
                return
            }

            // Download task implementation - invalidate previous session
            currentURLSession?.invalidateAndCancel()
            currentURLSession = URLSession(configuration: .default, delegate: URLSessionDelegateHandler(), delegateQueue: nil)
            let session = currentURLSession!

            // Prepare completion handlers to capture results for later dispatch to main thread
            var downloadedAudioDuration: Double = 0
            var downloadError: Error?
            var audioPlayer: AVAudioPlayer?
            var tempFileURL: URL?

            let semaphore = DispatchSemaphore(value: 0)

            currentDownloadTask = session.downloadTask(with: url) { location, _, error in
                if let error {
                    downloadError = error
                    semaphore.signal()
                    return
                }

                guard let location else {
                    downloadError = NSError(domain: "NarrationAudioPlayer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Download location is nil"])
                    semaphore.signal()
                    return
                }

                // Create temp file path
                let tempDirectory = FileManager.default.temporaryDirectory
                let fileExtension = url.pathExtension.lowercased().isEmpty ? "wav" : url.pathExtension.lowercased()
                tempFileURL = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)

                guard let tempURL = tempFileURL else {
                    downloadError = NSError(domain: "NarrationAudioPlayer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create temp file URL"])
                    semaphore.signal()
                    return
                }

                do {
                    // Move file
                    try FileManager.default.moveItem(at: location, to: tempURL)

                    // Initialize player off main thread
                    do {
                        audioPlayer = try AVAudioPlayer(contentsOf: tempURL)
                        downloadedAudioDuration = audioPlayer?.duration ?? 0
                    } catch {
                        downloadError = error
                        DDLogDebug("NarrationAudioPlayer: Deleting temp file after player init failure: \(tempURL.lastPathComponent)")
                        _ = Self.deleteFile(at: tempURL)
                    }
                } catch {
                    downloadError = error
                }

                semaphore.signal()
            }

            currentDownloadTask?.resume()

            // Wait for download to complete
            semaphore.wait()

            // Now dispatch results to main thread
            DispatchQueue.main.async {
                self.isDownloading = false

                // If a newer slide was requested while we were downloading,
                // discard this result and clean up the temp file
                if self.requestedSlideIndex != slideIndex {
                    DDLogDebug("NarrationAudioPlayer: Slide changed during download (was \(slideIndex), now \(self.requestedSlideIndex)), discarding result")
                    if let tempURL = tempFileURL {
                        DDLogDebug("NarrationAudioPlayer: Deleting stale temp file for superseded slide \(slideIndex): \(tempURL.lastPathComponent)")
                        _ = Self.deleteFile(at: tempURL)
                    }
                    return
                }

                if let error = downloadError {
                    DDLogDebug("NarrationAudioPlayer: Error downloading audio: \(error.localizedDescription)")
                    self.notifyDownloadFailure(forSlideIndex: slideIndex)
                    completion(0)
                    return
                }

                guard let player = audioPlayer, let tempURL = tempFileURL else {
                    DDLogDebug("NarrationAudioPlayer: Player not created")
                    self.notifyDownloadFailure(forSlideIndex: slideIndex)
                    completion(0)
                    return
                }

                // Set up audio session and player on main thread
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                    try AVAudioSession.sharedInstance().setActive(true)

                    self.currentSlideIndex = slideIndex
                    player.delegate = self

                    // Send duration first for slide timing
                    completion(downloadedAudioDuration)

                    // Then play audio
                    if player.play() {
                        DDLogDebug("NarrationAudioPlayer: Playback started successfully for slide \(slideIndex)")
                        self.audioPlayer = player
                        self.currentTempFileURL = tempURL
                        NotificationCenter.default.post(name: .narrationDidStart,
                                                        object: nil,
                                                        userInfo: ["slideIndex": slideIndex])
                    } else {
                        DDLogDebug("NarrationAudioPlayer: Playback failed")
                        _ = Self.deleteFile(at: tempURL)
                        self.notifyDownloadFailure(forSlideIndex: slideIndex)
                        completion(0)
                    }
                } catch {
                    DDLogDebug("NarrationAudioPlayer: Audio session error: \(error.localizedDescription)")
                    _ = Self.deleteFile(at: tempURL)
                    self.notifyDownloadFailure(forSlideIndex: slideIndex)
                    completion(0)
                }
            }
        }
    }

    func stopCurrentAudio() {
        DDLogDebug("NarrationAudioPlayer: Stopping current audio for slide \(currentSlideIndex)")
        // Clear delegate before stopping to prevent callbacks
        audioPlayer?.delegate = nil
        audioPlayer?.stop()
        audioPlayer = nil
        deleteTempFile()
    }

    /// Cancels any ongoing download
    func cancelCurrentDownload() {
        if let task = currentDownloadTask {
            DDLogDebug("NarrationAudioPlayer: Cancelling download for slide \(requestedSlideIndex)")
            task.cancel()
            currentDownloadTask = nil
            isDownloading = false
            deleteTempFile()
        }

        // Also invalidate the URL session to prevent resource accumulation
        currentURLSession?.invalidateAndCancel()
        currentURLSession = nil
    }

    /// Checks if narration is currently playing for a specific slide
    func isPlayingForSlide(_ slideIndex: Int) -> Bool {
        let isPlaying = currentSlideIndex == slideIndex && audioPlayer?.isPlaying == true
        if isPlaying {
            DDLogDebug("NarrationAudioPlayer: Already playing for slide \(slideIndex)")
        }
        return isPlaying
    }

    func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
        DDLogDebug("NarrationAudioPlayer: Playback finished for slide \(currentSlideIndex)")
        deleteTempFile()
        delegate?.narrationAudioPlayerDidFinishPlaying()
    }

    // MARK: Private

    private static let shared: NarrationAudioPlayer = {
        let instance = NarrationAudioPlayer()
        cleanupStaleTempFiles()
        return instance
    }()

    private static func cleanupStaleTempFiles() {
        let tmpDir = FileManager.default.temporaryDirectory
        do {
            let files = try FileManager.default.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil)
            let audioFiles = files.filter { $0.pathExtension == "mp3" || $0.pathExtension == "wav" }
            if !audioFiles.isEmpty {
                DDLogDebug("NarrationAudioPlayer: Cleaning up \(audioFiles.count) stale temp audio file(s) from previous session")
            }
            for file in audioFiles {
                _ = deleteFile(at: file)
            }
        } catch {
            DDLogDebug("NarrationAudioPlayer: Failed to read temp directory for cleanup: \(error.localizedDescription)")
        }
    }

    private var isDownloading = false
    private var currentDownloadTask: URLSessionDownloadTask?
    private var currentAudioURL: String?
    private var currentTempFileURL: URL?

    // Track both the requested slide index and the currently playing slide index
    private var requestedSlideIndex: Int = -1
    private var currentSlideIndex: Int = -1

    /// Deletes the current temp file and clears the reference on success
    private func deleteTempFile() {
        if let url = currentTempFileURL {
            DDLogDebug("NarrationAudioPlayer: Deleting current temp file: \(url.lastPathComponent)")
            let success = Self.deleteFile(at: url)
            if success {
                currentTempFileURL = nil
            } else {
                // Don't set currentTempFileURL to nil so we can retry deletion later
                DDLogDebug("NarrationAudioPlayer: Keeping reference to failed deletion for retry")
            }
        }
    }

    /// Deletes a specific file with proper error logging
    /// - Parameter url: The URL of the file to delete
    /// - Returns: true if deletion succeeded, false otherwise
    private static func deleteFile(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            DDLogDebug("NarrationAudioPlayer: Successfully deleted temp file: \(url.lastPathComponent)")
            return true
        } catch {
            DDLogDebug("NarrationAudioPlayer: Failed to delete temp file: \(url.lastPathComponent), error: \(error.localizedDescription)")
            return false
        }
    }

    /// Notify about download failure
    private func notifyDownloadFailure(forSlideIndex slideIndex: Int) {
        DispatchQueue.main.async {
            DDLogDebug("NarrationAudioPlayer: Notifying about download failure for slide \(slideIndex)")
            NotificationCenter.default.post(name: .narrationDidFailToLoad,
                                            object: nil,
                                            userInfo: ["slideIndex": slideIndex])
        }
    }
}
