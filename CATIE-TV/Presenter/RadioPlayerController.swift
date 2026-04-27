//
//  RadioPlayerController.swift
//  CATIE-TV
//
//  Created by Admin on 03/07/19.
//  Copyright © 2019 statusSolutions. All rights reserved.
//

import AVKit
import CocoaLumberjackSwift
import CoreData
import UIKit

class RadioPlayerController: NSObject {
    // MARK: Lifecycle

    deinit {
        DDLogDebug("RadioPlayerController: deinit - cleaning up resources")
        // Clean up all resources to prevent memory leaks
        stopRadio()

        // Invalidate and clear resume timer
        resumeTimer?.invalidate()
        resumeTimer = nil

        // Clear delegate to prevent potential callbacks to deallocated object
        mainViewdelegate = nil

        // Remove all NotificationCenter observers to prevent memory leaks
        NotificationCenter.default.removeObserver(self)

        DDLogDebug("RadioPlayerController: deinit - all resources cleaned up")
    }

    // MARK: Internal

    var radio: AVPlayer?
    var radioPlayerItem: AVPlayerItem?
    /// Used to indicate the radio playing status
    var radioPlayingStatus: Bool!
    /// Used to handle the sara alerts audio when the radio overlaps it/
    var isRadioPausedDueToAlerts = false
    /// Used to handle the sara alerts audio when the radio overlaps it
    var isRadioPausedDueToNarration = false
    /// Radio feed url feed to be played from network
    var radioFeedURL: String?
    weak var mainViewdelegate: MainScreenDelegate?

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context _: UnsafeMutableRawPointer?) {
        SwiftTryCatch.try {
            DDLogDebug("RadioPlayerController : radio keypath observor called with kepath \(String(describing: keyPath)) and object \(String(describing: object))")

            if keyPath == "status" {
                let status = radioPlayerItem?.status
                switch status {
                case .unknown:
                    DDLogDebug("RadioPlayerController : radio player status 1")
                    radioPlayingStatus = false
                    self.mainViewdelegate?.updateRadioIcon(status: false, isNetworkDown: false)

                case .readyToPlay:
                    DDLogDebug("RadioPlayerController : radio player status 2")
                    radioPlayingStatus = true
                    self.mainViewdelegate?.updateRadioIcon(status: true, isNetworkDown: false)

                case .failed:
                    DDLogDebug("RadioPlayerController : radio player status 3")
                    radioPlayingStatus = false
                    self.mainViewdelegate?.updateRadioIcon(status: false, isNetworkDown: false)

                case .none:
                    DDLogDebug("RadioPlayerController : radio player status 4")
                    radioPlayingStatus = false
                    self.mainViewdelegate?.updateRadioIcon(status: false, isNetworkDown: false)

                @unknown default:
                    radioPlayingStatus = false
                    DDLogDebug("RadioPlayerController : Unknown state value received on radio player controller")
                    self.mainViewdelegate?.updateRadioIcon(status: false, isNetworkDown: false)
                }

            } else if keyPath == "rate" {
                DDLogDebug("RadioPlayerController : ratio rate observor called with rate \(String(describing: radio?.rate)) and duration \(String(describing: radioPlayerItem?.duration)) and current time \(String(describing: radioPlayerItem?.currentTime()))")

                if radioPlayerItem?.duration != nil, radioPlayerItem?.currentTime() != nil {
                    if radio?.rate == 0, CMTimeGetSeconds(radioPlayerItem!.duration) != CMTimeGetSeconds((radioPlayerItem?.currentTime())!) {
                        DDLogDebug("RadioPlayerController : Continue playing the radio here")
                    }
                }

            } else if keyPath == "playbackBufferEmpty" {
                DDLogDebug("RadioPlayerController : Playback buffer is empty now")

            } else if keyPath == "playbackLikelyToKeepUp" {
                DDLogDebug("RadioPlayerController : Playback buffer is to keep up so continue the stream")

            } else if keyPath == "playbackBufferFull" {
                DDLogDebug("RadioPlayerController : Radio play back buffer full key value called")
            } else if keyPath == "timeControlStatus" {
                DDLogDebug("RadioPlayerController : Radio play back time control status call back received")

                if keyPath == "timeControlStatus", let change, let newValue = change[NSKeyValueChangeKey.newKey] as? Int, let oldValue = change[NSKeyValueChangeKey.oldKey] as? Int {
                    let oldStatus = AVPlayer.TimeControlStatus(rawValue: oldValue)
                    let newStatus = AVPlayer.TimeControlStatus(rawValue: newValue)
                    if newStatus != oldStatus {
                        if newStatus == .playing {
                            DDLogDebug("RadioPlayerController : Radio keypath timeControlStatus observer status playing called")
                        } else if newStatus == .paused {
                            DDLogDebug("RadioPlayerController : Radio keypath timeControlStatus observer status paused called")
                        } else if newStatus == .waitingToPlayAtSpecifiedRate {
                            DDLogDebug("RadioPlayerController : Radio keypath timeControlStatus observer status waiting to play at speficied rate called")
                        } else {
                            DDLogDebug("RadioPlayerController : Radio keypath timeControlStatus observer status default called")
                        }
                    }
                }
            }
        } catch: { exception in
            DDLogDebug("RadioPlayerController : Exception in observeValue - \(String(describing: exception))")
        }
    }

    func playRadio() {
        SwiftTryCatch.try {
            DDLogDebug("RadioPlayerController : Initiate Radio play")

            // Check if radio is disabled by tvRadioFlag
            if let mainVC = mainViewdelegate as? MainScreenViewController,
               mainVC.tvRadioFlag == 0
            {
                DDLogDebug("RadioPlayerController : Radio playback blocked - tvRadioFlag is disabled")
                return
            }

            do {
                DDLogDebug("RadioPlayerController : Stopping existing radio player before playing it")
                stopRadio() // Stopping existing radio player before playing it.

                try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default)
                try AVAudioSession.sharedInstance().setActive(true)

                let playerURL = URL(string: radioFeedURL?.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "")
                if playerURL != nil {
                    radioPlayerItem = AVPlayerItem(url: playerURL!)
                    radio = AVPlayer(playerItem: radioPlayerItem)
                    radio?.automaticallyWaitsToMinimizeStalling = true
                    DDLogDebug("RadioPlayerController : Adding further notifications to observer the logs on the updates")
                    // Adding further notifications to observer the logs on the updates.
                    radioPlayerItem?.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions(), context: nil)
                    radioPlayerItem?.addObserver(self, forKeyPath: "rate", options: [.old, .new], context: nil)
                    radioPlayerItem?.addObserver(self, forKeyPath: "playbackBufferEmpty", options: [.old, .new], context: nil)
                    radioPlayerItem?.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: [.old, .new], context: nil)
                    radioPlayerItem?.addObserver(self, forKeyPath: "playbackBufferFull", options: [.old, .new], context: nil)
                    radioPlayerItem?.addObserver(self, forKeyPath: "timeControlStatus", options: [.old, .new], context: nil)
                    NotificationCenter.default.addObserver(self, selector: #selector(playerEndedPlaying), name: .AVPlayerItemDidPlayToEndTime, object: radio?.currentItem)
                    NotificationCenter.default.addObserver(self, selector: #selector(playerStalled),
                                                           name: NSNotification.Name.AVPlayerItemPlaybackStalled, object: radio?.currentItem)

                    radio?.volume = 1.0
                    radio?.rate = 1.0
                    radio?.play()
                } else {
                    DDLogDebug("RadioPlayerController : Unable to start the radio since the url is null")
                }

            } catch {
                DDLogDebug("RadioPlayerController : catching error at playeRadio \\(error.localizedDescription)")
            }
        } catch: { _ in
            DDLogDebug("RadioPlayerController : Exception in playRadio - \\(String(describing: exception))")
        }
    }

    func stopRadio() {
        SwiftTryCatch.try {
            DDLogDebug("RadioPlayerController : Stopping Radio")

            // Cancel any pending resume timer
            resumeTimer?.invalidate()
            resumeTimer = nil

            // Ensure status is updated before cleanup
            radioPlayingStatus = false

            // Clean up player if it exists
            if let radio {
                radio.pause()
                // Ensure stream stops completely
                radio.replaceCurrentItem(with: nil)
            }

            // Remove NotificationCenter observers (safe to call even if not registered)
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemPlaybackStalled, object: nil)

            // Safely remove KVO observers if still attached
            if let radioPlayerItem = self.radioPlayerItem {
                // Use try-catch for each observer removal to handle cases where observer wasn't added
                SwiftTryCatch.try {
                    radioPlayerItem.removeObserver(self, forKeyPath: "status", context: nil)
                } catch: { _ in
                    DDLogDebug("RadioPlayerController : Failed to remove 'status' observer, likely wasn't added")
                }
                SwiftTryCatch.try {
                    radioPlayerItem.removeObserver(self, forKeyPath: "rate", context: nil)
                } catch: { _ in
                    DDLogDebug("RadioPlayerController : Failed to remove 'rate' observer, likely wasn't added")
                }
                SwiftTryCatch.try {
                    radioPlayerItem.removeObserver(self, forKeyPath: "playbackBufferEmpty", context: nil)
                } catch: { _ in
                    DDLogDebug("RadioPlayerController : Failed to remove 'playbackBufferEmpty' observer, likely wasn't added")
                }
                SwiftTryCatch.try {
                    radioPlayerItem.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp", context: nil)
                } catch: { _ in
                    DDLogDebug("RadioPlayerController : Failed to remove 'playbackLikelyToKeepUp' observer, likely wasn't added")
                }
                SwiftTryCatch.try {
                    radioPlayerItem.removeObserver(self, forKeyPath: "playbackBufferFull", context: nil)
                } catch: { _ in
                    DDLogDebug("RadioPlayerController : Failed to remove 'playbackBufferFull' observer, likely wasn't added")
                }
                SwiftTryCatch.try {
                    radioPlayerItem.removeObserver(self, forKeyPath: "timeControlStatus", context: nil)
                } catch: { _ in
                    DDLogDebug("RadioPlayerController : Failed to remove 'timeControlStatus' observer, likely wasn't added")
                }
            }

            // Reset variables
            self.radioPlayerItem = nil
            self.radio = nil
            DDLogDebug("RadioPlayerController : Radio stopped successfully")

        } catch: { exception in
            DDLogDebug("RadioPlayerController : Exception in stopRadio - \(String(describing: exception))")
        }
    }

    /// Check if server allows radio playback based on playingStatus flag from Core Data
    func isRadioPlaybackAllowedByServer() -> Bool {
        let appDel = UIApplication.shared.delegate as? AppDelegate
        let managedObjectContext = appDel?.persistentContainer.newBackgroundContext()
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Radio")

        do {
            let radioFeedData = try managedObjectContext?.fetch(request)
            if let radioData = radioFeedData?.first as? Radio {
                let isAllowed = radioData.playingStatus == 1
                DDLogDebug("RadioPlayerController : Server playingStatus check : \(isAllowed)")
                return isAllowed
            } else {
                DDLogDebug("RadioPlayerController : No radio data found - blocking playback as precaution")
                return false
            }
        } catch {
            DDLogDebug("RadioPlayerController : Error fetching radio data for playingStatus check: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Checks if the radio is actually playing using AVPlayer state.
    /// - `rate > 0` indicates the player is actively playing (non-zero playback speed)
    /// - `readyToPlay` ensures the media is loaded and ready for playback
    /// Both conditions together confirm valid and active playback.
    func isRadioActuallyPlaying() -> Bool {
        guard let radio = radio, let playerItem = radioPlayerItem else {
            DDLogDebug("RadioPlayerController : Radio player or item is nil - not playing")
            return false
        }

        let isPlaying = radio.rate > 0 && playerItem.status == .readyToPlay
        DDLogDebug("RadioPlayerController : Actual playing state check - rate: \(radio.rate), status: \(playerItem.status.rawValue), isPlaying: \(isPlaying)")
        return isPlaying
    }

    @objc func playerEndedPlaying(_: Notification) {
        SwiftTryCatch.try {
            DDLogDebug("RadioPlayerController : Radio play ended playing notification call back posted")
            if radioPlayingStatus ?? false, radio != nil, radioPlayerItem != nil {
                DDLogDebug("RadioPlayerController : Radio player paused in between so resuming the play after 60 sec")

                // Cancel any existing resume timer to prevent multiple timers
                resumeTimer?.invalidate()

                // Store timer reference for proper cleanup
                resumeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in
                    DDLogDebug("RadioPlayerController : resume Timer triggered")
                    self?.resumeTimer = nil // Clear reference when timer fires

                    // Check if radio should be active based on UI type and radio flag before resuming
                    if let mainVC = self?.mainViewdelegate as? MainScreenViewController {
                        let shouldPlayRadio = DataFetchingUtility.shouldFetchData(
                            for: .radio,
                            uiType: mainVC.actualUIType,
                            radioFlag: mainVC.tvRadioFlag,
                            context: "RadioPlayerController"
                        )

                        if !shouldPlayRadio {
                            DDLogDebug("RadioPlayerController : Radio resume blocked - UI type \(mainVC.actualUIType) with radioFlag \(mainVC.tvRadioFlag) doesn't support radio")
                            return
                        }
                    }

                    // Check server's playingStatus before resuming radio
                    if self?.isRadioPlaybackAllowedByServer() == true {
                        self?.playRadio()
                    } else {
                        DDLogDebug("RadioPlayerController : Radio resume blocked by server playingStatus")
                    }
                }
            }
        } catch: { exception in
            DDLogDebug("RadioPlayerController : Exception in playerEndedPlaying - \(String(describing: exception))")
        }
    }

    @objc func playerStalled(_: Notification) {
        SwiftTryCatch.try {
            DDLogDebug("RadioPlayerController : Radio play stalled notification call back posted")
        } catch: { exception in
            DDLogDebug("RadioPlayerController : Exception in playerStalled - \(String(describing: exception))")
        }
    }

    // MARK: Private

    /// Timer reference for proper cleanup
    private var resumeTimer: Timer?
}
