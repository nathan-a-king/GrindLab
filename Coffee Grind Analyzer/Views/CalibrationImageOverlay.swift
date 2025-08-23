
import SwiftUI

/// Draws coin detections (in *image pixel* coordinates) over a UIImage that is displayed with `.scaledToFit`.
/// - Parameters:
///   - image: The source UIImage used for detection.
///   - detections: Circles where `center` is in image pixels (UIKit coords) and `radius` is in pixels.
///   - lineWidth: Stroke width for the overlay circle.
///   - color: Stroke color (defaults to system green).
public struct CalibrationImageOverlay: View {
    public let image: UIImage
    let detections: [DetectedCircle]
    public var lineWidth: CGFloat = 3
    public var color: Color = .green

    init(image: UIImage, detections: [DetectedCircle], lineWidth: CGFloat = 3, color: Color = .green) {
        self.image = image
        self.detections = detections
        self.lineWidth = lineWidth
        self.color = color
    }

    public var body: some View {
        GeometryReader { geo in
            let container = geo.size
            let imgSize = image.size

            // Compute fitted rect for .scaledToFit
            let scale = min(container.width / max(imgSize.width, 1e-6),
                            container.height / max(imgSize.height, 1e-6))
            let fittedSize = CGSize(width: imgSize.width * scale, height: imgSize.height * scale)
            let origin = CGPoint(
                x: (container.width - fittedSize.width) / 2.0,
                y: (container.height - fittedSize.height) / 2.0
            )

            ZStack {
                // The displayed image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: container.width, height: container.height)
                    .clipped()

                // Overlays
                ForEach(Array(detections.enumerated()), id: \.offset) { _, d in
                    let vx = origin.x + d.center.x * scale
                    let vy = origin.y + d.center.y * scale
                    let vr = CGFloat(d.radius) * scale

                    Circle()
                        .strokeBorder(color, lineWidth: lineWidth)
                        .frame(width: vr * 2, height: vr * 2)
                        .position(x: vx, y: vy)
                }
            }
            .frame(width: container.width, height: container.height)
        }
    }
}

// MARK: - Preview (Optional - can be removed)
#if DEBUG
struct CalibrationImageOverlay_Previews: PreviewProvider {
    static var previews: some View {
        let uiImage = UIImage(systemName: "circle")!.withTintColor(.gray, renderingMode: .alwaysOriginal)
        let sample = DetectedCircle(center: CGPoint(x: 100, y: 100),
                                    radius: 60,
                                    circularity: 0.9,
                                    averageColor: .clear,
                                    edgeStrength: 1.0)
        CalibrationImageOverlay(image: uiImage, detections: [sample])
            .frame(width: 300, height: 300)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif
