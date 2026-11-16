import UIKit

final class BoxOverlayView: UIView {
    var boxes: [CGRect] = [] {
        didSet {
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        context.setStrokeColor(UIColor.systemGreen.cgColor)
        context.setLineWidth(3)

        for box in boxes {
            context.stroke(box)
        }
    }
}

