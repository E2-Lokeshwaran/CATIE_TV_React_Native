import CocoaLumberjackSwift
import Combine
import SwiftUI
import UIKit

class PortraitViewController: UIViewController {
    // MARK: Lifecycle

    deinit {
        // Ensure all Combine subscriptions are cancelled
        cancellables.removeAll()

        // Explicitly cleanup the viewModel's subscriptions to prevent memory leaks
        viewModel.cleanup()

        // Release hosting controller to free up SwiftUI resources
        hostingController = nil

        // Log for debugging
        DDLogDebug("PortraitViewController: deinit - all resources released")
    }

    // MARK: Internal

    /// Reference to the main view controller containing the data
    weak var mainViewController: MainScreenViewController?

    // MARK: - Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // Setup SwiftUI portrait view
        setupPortraitView()

        // Setup Combine subscriptions if mainVC is available
        if let mainVC = mainViewController {
            viewModel.setupSubscriptions(from: mainVC)
        }

        // Add log for debugging
        DDLogDebug("PortraitViewController: viewDidLoad complete - Subscriptions set up")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // No longer need timer or forced update here
        DDLogDebug("PortraitViewController: viewWillAppear")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // No longer need forced update here
        DDLogDebug("PortraitViewController: viewDidAppear")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Timer invalidated automatically by Combine cancellables in ViewModel's deinit
        DDLogDebug("PortraitViewController: viewDidDisappear - cleanup complete")
    }

    /// Handle orientation changes
    override func viewWillTransition(
        to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate { _ in
            // Update any animations if needed during rotation
            DDLogDebug("PortraitViewController: viewWillTransition - animating")
        } completion: { _ in
            // Ensure the hosting controller fills the view after rotation
            if let hostingView = self.hostingController?.view {
                hostingView.frame = self.view.bounds
                DDLogDebug("PortraitViewController: viewWillTransition - resized hostingView")
            }
        }
    }

    // MARK: - Public Methods

    /// Set the main view controller reference and set up subscriptions
    func setMainViewController(_ controller: MainScreenViewController) {
        mainViewController = controller
        // Setup subscriptions when the controller is set
        viewModel.setupSubscriptions(from: controller)
        DDLogDebug("PortraitViewController: MainViewController reference set and subscriptions updated")
    }

    /// Set the UI type for the portrait view
    func setUIType(_ uiType: Int16) {
        if Thread.isMainThread {
            viewModel.uiType = uiType
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.viewModel.uiType = uiType
            }
        }
    }

    /// Set the radio flag for the portrait view
    func setRadioFlag(_ radioFlag: Int) {
        if Thread.isMainThread {
            viewModel.tvRadioFlag = radioFlag
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.viewModel.tvRadioFlag = radioFlag
            }
        }
    }

    // MARK: Private

    private var cancellables = Set<AnyCancellable>()

    /// SwiftUI hosting controller
    private var hostingController: UIHostingController<PortraitView>?

    /// View model that bridges data between UIKit and SwiftUI
    private let viewModel = PortraitViewModel()

    /// Setup the SwiftUI PortraitView within a UIHostingController
    private func setupPortraitView() {
        hostingController = UIHostingController(rootView: PortraitView(viewModel: viewModel))
        guard let hostingView = hostingController?.view else {
            return
        }

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addChild(hostingController!)
        view.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        hostingController?.didMove(toParent: self)
        DDLogDebug("PortraitViewController: PortraitView setup complete")
    }

}
