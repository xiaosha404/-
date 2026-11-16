import UIKit

@MainActor
final class BoxOverlayView: UIView {
    private let boxLayer = CAShapeLayer()

    var boxes: [CGRect] = [] {
        didSet {
            updatePath()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false

        boxLayer.fillColor = UIColor.clear.cgColor
        boxLayer.strokeColor = UIColor.systemGreen.cgColor
        boxLayer.lineWidth = 3
        boxLayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(boxLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        boxLayer.frame = bounds
        updatePath()
    }

    private func updatePath() {
        let path = CGMutablePath()
        boxes.forEach { path.addRect($0) }
        boxLayer.path = path
    }
}

