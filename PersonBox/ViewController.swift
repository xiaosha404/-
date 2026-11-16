import AVFoundation
import UIKit
import UltralyticsYOLO

final class ViewController: UIViewController {
    private var yoloView: YOLOView!
    private let boxOverlayView = BoxOverlayView()
    private var notificationTokens: [NSObjectProtocol] = []
    private var watchdogTimer: Timer?
    private var lastInferenceAt: Date?
    private var activeSince = Date()
    private var restartInProgress = false

    override func viewDidLoad() {
        super.viewDidLoad()

        yoloView = YOLOView(
            frame: view.bounds,
            modelPathOrName: "yolo26n",
            task: .detect
        )
        yoloView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        yoloView.showOverlays = false
        yoloView.labelName.isHidden = true
        yoloView.labelFPS.isHidden = true
        yoloView.labelBreakdown.isHidden = true
        yoloView.labelZoom.isHidden = true
        yoloView.toolbar.isHidden = true
        yoloView.playButton.isHidden = true
        yoloView.pauseButton.isHidden = true
        yoloView.switchCameraButton.isHidden = true
        yoloView.shareButton.isHidden = true
        yoloView.infoButton.isHidden = true
        yoloView.onDetection = { result in
            self.lastInferenceAt = Date()
            let personBoxes = result.boxes
                .filter { $0.cls.lowercased() == "person" }
                .map { prediction in
                    Self.displayRect(
                        prediction.xywhn,
                        imageSize: result.orig_shape,
                        viewSize: self.view.bounds.size
                    )
                }
            self.boxOverlayView.boxes = personBoxes
        }

        view.addSubview(yoloView)
        boxOverlayView.frame = view.bounds
        boxOverlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        boxOverlayView.isUserInteractionEnabled = false
        view.addSubview(boxOverlayView)

        observeCameraLifecycle()
        startCameraWatchdog()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        yoloView?.resume()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        watchdogTimer?.invalidate()
        watchdogTimer = nil
        yoloView?.stop()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        activeSince = Date()
        lastInferenceAt = nil
        startCameraWatchdog()
        restartCamera()
    }

    deinit {
        watchdogTimer?.invalidate()
        notificationTokens.forEach(NotificationCenter.default.removeObserver)
    }

    private func startCameraWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) {
            [weak self] _ in
            self?.checkCameraHealth()
        }
    }

    private func checkCameraHealth() {
        guard view.window != nil,
              UIApplication.shared.applicationState == .active,
              !restartInProgress else {
            return
        }

        let now = Date()
        let hasStartedInference = lastInferenceAt != nil
        let inferenceTimedOut = lastInferenceAt.map {
            now.timeIntervalSince($0) > 4
        } ?? now.timeIntervalSince(activeSince) > 8

        guard hasStartedInference ? inferenceTimedOut : now.timeIntervalSince(activeSince) > 8 else {
            return
        }

        restartInProgress = true
        lastInferenceAt = nil
        yoloView.stop()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            self.yoloView.resume()
            self.restartInProgress = false
        }
    }

    private func observeCameraLifecycle() {
        let center = NotificationCenter.default

        notificationTokens.append(
            center.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.restartCamera()
            }
        )

        notificationTokens.append(
            center.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.yoloView?.stop()
            }
        )

        notificationTokens.append(
            center.addObserver(
                forName: .AVCaptureSessionWasInterrupted,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.yoloView?.stop()
            }
        )

        notificationTokens.append(
            center.addObserver(
                forName: .AVCaptureSessionInterruptionEnded,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.restartCamera()
            }
        )

        notificationTokens.append(
            center.addObserver(
                forName: .AVCaptureSessionRuntimeError,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.restartCamera()
            }
        )
    }

    private func restartCamera() {
        guard isViewLoaded, view.window != nil else {
            return
        }

        yoloView?.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.yoloView?.resume()
        }
    }

    private static func displayRect(
        _ normalizedRect: CGRect,
        imageSize: CGSize,
        viewSize: CGSize
    ) -> CGRect {
        guard imageSize.width > 0,
              imageSize.height > 0,
              viewSize.width > 0,
              viewSize.height > 0 else {
            return .zero
        }

        let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let scaledImageSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        let offset = CGPoint(
            x: (scaledImageSize.width - viewSize.width) / 2,
            y: (scaledImageSize.height - viewSize.height) / 2
        )

        return CGRect(
            x: normalizedRect.minX * imageSize.width * scale - offset.x,
            y: normalizedRect.minY * imageSize.height * scale - offset.y,
            width: normalizedRect.width * imageSize.width * scale,
            height: normalizedRect.height * imageSize.height * scale
        )
    }
}

