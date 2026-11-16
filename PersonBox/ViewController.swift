import AVFoundation
import UIKit
import Vision

final class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "personbox.camera.session")
    private let videoQueue = DispatchQueue(label: "personbox.camera.video")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let overlayView = BoxOverlayView()
    private var isProcessingFrame = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        overlayView.backgroundColor = .clear
        overlayView.isUserInteractionEnabled = false
        view.addSubview(overlayView)

        requestCameraAccess()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        overlayView.frame = view.bounds
    }

    private func requestCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else { return }
                DispatchQueue.main.async {
                    self?.configureCamera()
                }
            }
        default:
            showCameraPermissionMessage()
        }
    }

    private func showCameraPermissionMessage() {
        let label = UILabel()
        label.text = "请在设置中允许 PersonBox 使用相机"
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func configureCamera() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard let camera = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .back
            ) else {
                self.session.commitConfiguration()
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }

                self.videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                self.videoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)

                if self.session.canAddOutput(self.videoOutput) {
                    self.session.addOutput(self.videoOutput)
                }

                self.videoOutput.connection(with: .video)?.videoOrientation = .portrait
                self.session.commitConfiguration()

                DispatchQueue.main.async {
                    self.previewLayer.session = self.session
                }
                self.session.startRunning()
            } catch {
                self.session.commitConfiguration()
                print("Camera setup failed: \(error)")
            }
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard !isProcessingFrame,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        isProcessingFrame = true
        let request = VNDetectHumanRectanglesRequest()
        if #available(iOS 15.0, *) {
            request.upperBodyOnly = false
            request.revision = VNDetectHumanRectanglesRequestRevision2
        }
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .right,
            options: [:]
        )

        do {
            try handler.perform([request])
            let boxes = (request.results ?? [])
                .filter { $0.confidence >= 0.35 }
                .map { observation in
                    let box = observation.boundingBox
                    return CGRect(
                        x: box.minX,
                        y: 1 - box.maxY,
                        width: box.width,
                        height: box.height
                    )
                }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.overlayView.boxes = boxes.map {
                    self.previewLayer.layerRectConverted(fromMetadataOutputRect: $0)
                }
            }
        } catch {
            print("Human detection failed: \(error)")
        }

        isProcessingFrame = false
    }
}

