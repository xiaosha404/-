import AVFoundation
import UIKit
import UltralyticsYOLO

final class ViewController: UIViewController {
    private var yoloView: YOLOView!

    override func viewDidLoad() {
        super.viewDidLoad()

        yoloView = YOLOView(
            frame: view.bounds,
            modelPathOrName: "yolo26n",
            task: .detect
        )
        yoloView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        yoloView.onDetection = { result in
            _ = result
        }

        view.addSubview(yoloView)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        yoloView?.resume()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        yoloView?.stop()
    }
}

