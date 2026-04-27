import CocoaLumberjackSwift
import GameController
import SwiftUI

struct RegistrationTapHandler: UIViewControllerRepresentable {
    class RegistrationTapViewController: UIViewController {
        // MARK: Lifecycle

        deinit {
            resetTimer?.invalidate()
            NotificationCenter.default.removeObserver(self)
        }

        // MARK: Internal

        var tapCount = 0
        var lastTapTime: Date?
        var resetTimer: Timer?
        var onRegistrationTaps: (() -> Void)?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear

            // Set up a visible debug label (comment for production)
            //            let label = UILabel(frame: CGRect(x: 20, y: 20, width: 300, height: 50))
            //            label.text = "Tap Count: 0"
            //            label.textColor = .white
            //            label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            //            label.tag = 100
            //            view.addSubview(label)

            setupGameController()
            startResetTimer()
            DDLogDebug("RegistrationTapViewController: viewDidLoad")
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)

            // Cleanup timer when view disappears
            if let timer = resetTimer, timer.isValid {
                timer.invalidate()
                resetTimer = nil
                DDLogDebug("RegistrationTapViewController: Timer invalidated in viewDidDisappear")
            }
        }

        /// Backup method using standard UIKit press handling
        override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            var handled = false

            for press in presses {
                DDLogDebug("RegistrationTapViewController: Press ended with type \(press.type.rawValue)")

                if press.type.rawValue == 2 { // Select button
                    handleButtonPress()
                    handled = true
                }
            }

            if !handled {
                super.pressesEnded(presses, with: event)
            }
        }

        func setupGameController() {
            // Register for controller connection notifications
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(connectControllers),
                name: NSNotification.Name.GCControllerDidConnect,
                object: nil
            )

            // Check for already-connected controllers
            connectControllers()
        }

        @objc func connectControllers() {
            DDLogDebug("RegistrationTapViewController: Connecting controllers")

            // Get all connected controllers
            let controllers = GCController.controllers()
            DDLogDebug("RegistrationTapViewController: Found \(controllers.count) controllers")

            for controller in controllers {
                if let microGamepad = controller.microGamepad {
                    DDLogDebug("RegistrationTapViewController: Found microGamepad controller")

                    // Setup button handler
                    microGamepad.buttonA.valueChangedHandler = { [weak self] _, _, pressed in
                        guard let self else {
                            return
                        }

                        if pressed {
                            DDLogDebug("RegistrationTapViewController: ButtonA pressed")
                            handleButtonPress()
                        }
                    }

                    // Alternative handler for select button
                    microGamepad.buttonX.valueChangedHandler = { [weak self] _, _, pressed in
                        guard let self else {
                            return
                        }

                        if pressed {
                            DDLogDebug("RegistrationTapViewController: ButtonX pressed")
                            handleButtonPress()
                        }
                    }
                }
            }
        }

        func startResetTimer() {
            resetTimer?.invalidate()
            resetTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                guard let self else {
                    return
                }

                // Update debug label
                if let label = view.viewWithTag(100) as? UILabel {
                    label.text = "Tap Count: \(tapCount)"
                }

                // Reset tap count if inactive
                if let lastTap = lastTapTime, Date().timeIntervalSince(lastTap) > 7.0 {
                    DDLogDebug("RegistrationTapViewController: Reset tap count due to inactivity")
                    tapCount = 0
                }
            }
        }

        func stopResetTimer() {
            if let timer = resetTimer, timer.isValid {
                timer.invalidate()
                resetTimer = nil
                DDLogDebug("RegistrationTapViewController: Timer explicitly stopped")
            }
        }

        func handleButtonPress() {
            tapCount += 1
            lastTapTime = Date()

            DDLogDebug("RegistrationTapViewController: Button press registered - count is now \(tapCount)")

            // Update debug label
            if let label = view.viewWithTag(100) as? UILabel {
                label.text = "Tap Count: \(tapCount)"
            }

            if tapCount >= 5 {
                DDLogDebug("RegistrationTapViewController: Required taps reached! Executing callback")
                tapCount = 0

                // Stop the timer before executing the callback
                stopResetTimer()

                DispatchQueue.main.async { [weak self] in
                    self?.onRegistrationTaps?()
                }
            }
        }
    }

    var onRegistrationTaps: () -> Void

    static func dismantleUIViewController(_ uiViewController: RegistrationTapViewController, coordinator _: ()) {
        // Ensure timer is invalidated when view is dismantled
        uiViewController.stopResetTimer()
        DDLogDebug("RegistrationTapViewController: Dismantled and timer stopped")
    }

    func makeUIViewController(context _: Context) -> RegistrationTapViewController {
        let viewController = RegistrationTapViewController()
        viewController.onRegistrationTaps = onRegistrationTaps
        DDLogDebug("RegistrationTapViewController: Created RegistrationTapViewController")
        return viewController
    }

    func updateUIViewController(_ uiViewController: RegistrationTapViewController, context _: Context) {
        uiViewController.onRegistrationTaps = onRegistrationTaps
    }
}
