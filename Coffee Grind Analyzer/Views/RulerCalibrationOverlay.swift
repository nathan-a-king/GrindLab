import SwiftUI

struct RulerCalibrationOverlay: View {
    let image: UIImage
    @Binding var startPoint: CGPoint?
    @Binding var endPoint: CGPoint?
    @Binding var isDragging: Bool
    
    var lineWidth: CGFloat = 3
    var color: Color = .red
    
    // Track which handle is being dragged
    @State private var draggingHandle: DragHandle?
    
    // Zoom state
    @State private var currentZoom: CGFloat = 1.0
    @State private var totalZoom: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    
    enum DragHandle {
        case start
        case end
        case line // dragging the line itself
    }
    
    // Offset to position line above finger
    private let fingerOffset: CGFloat = 60
    
    var body: some View {
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
                // The displayed image with zoom and pan
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(totalZoom * currentZoom)
                    .offset(x: offset.width + dragOffset.width,
                            y: offset.height + dragOffset.height)
                    .frame(width: container.width, height: container.height)
                    .clipped()
                
                // Overlay for dragging line
                Color.clear
                    .frame(width: container.width, height: container.height)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        // Apply finger offset and zoom - move tap point up by offset amount
                        let currentTotalZoom = totalZoom * currentZoom
                        let offsetLocation = CGPoint(x: location.x, y: location.y - fingerOffset / currentTotalZoom)
                        let imageLocation = viewToImageCoordinatesWithZoom(
                            viewPoint: offsetLocation,
                            containerSize: container,
                            imageSize: imgSize,
                            scale: scale * currentTotalZoom,
                            origin: origin,
                            zoom: currentTotalZoom,
                            panOffset: CGSize(width: offset.width + dragOffset.width,
                                             height: offset.height + dragOffset.height)
                        )
                        
                        if startPoint == nil {
                            startPoint = imageLocation
                        } else if endPoint == nil {
                            endPoint = imageLocation
                        } else {
                            // Reset and start new measurement
                            startPoint = imageLocation
                            endPoint = nil
                        }
                    }
                    .gesture(
                        // Line dragging gesture with higher minimum distance to avoid conflicts
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                isDragging = true
                                
                                // Apply finger offset and zoom - move drag point up by offset amount
                                let currentTotalZoom = totalZoom * currentZoom
                                let offsetLocation = CGPoint(x: value.location.x, y: value.location.y - fingerOffset / currentTotalZoom)
                                let imageLocation = viewToImageCoordinatesWithZoom(
                                    viewPoint: offsetLocation,
                                    containerSize: container,
                                    imageSize: imgSize,
                                    scale: scale * currentTotalZoom,
                                    origin: origin,
                                    zoom: currentTotalZoom,
                                    panOffset: CGSize(width: offset.width + dragOffset.width,
                                                     height: offset.height + dragOffset.height)
                                )
                                
                                if draggingHandle == nil {
                                    // Starting new line or determine which handle to drag
                                    if let start = startPoint, let end = endPoint {
                                        // Check which endpoint is closer to drag start
                                        let startViewPoint = imageToViewCoordinatesWithZoom(
                                            imagePoint: start,
                                            scale: scale * currentTotalZoom,
                                            origin: origin,
                                            zoom: currentTotalZoom,
                                            panOffset: CGSize(width: offset.width + dragOffset.width,
                                                             height: offset.height + dragOffset.height)
                                        )
                                        let endViewPoint = imageToViewCoordinatesWithZoom(
                                            imagePoint: end,
                                            scale: scale * currentTotalZoom,
                                            origin: origin,
                                            zoom: currentTotalZoom,
                                            panOffset: CGSize(width: offset.width + dragOffset.width,
                                                             height: offset.height + dragOffset.height)
                                        )
                                        
                                        let distToStart = distance(from: value.startLocation, to: startViewPoint)
                                        let distToEnd = distance(from: value.startLocation, to: endViewPoint)
                                        
                                        if distToStart < 30 {
                                            draggingHandle = .start
                                        } else if distToEnd < 30 {
                                            draggingHandle = .end
                                        } else {
                                            draggingHandle = .line
                                        }
                                    } else {
                                        draggingHandle = .line
                                    }
                                }
                                
                                // Handle the drag based on what's being dragged
                                switch draggingHandle {
                                case .start:
                                    startPoint = imageLocation
                                case .end:
                                    endPoint = imageLocation
                                case .line, .none:
                                    if startPoint == nil {
                                        startPoint = imageLocation
                                        endPoint = imageLocation
                                    } else {
                                        endPoint = imageLocation
                                    }
                                }
                            }
                            .onEnded { value in
                                isDragging = false
                                draggingHandle = nil
                            }
                    )
                
                // Draw the measurement line
                if let start = startPoint, let end = endPoint {
                    let currentTotalZoom = totalZoom * currentZoom
                    let viewStart = imageToViewCoordinatesWithZoom(
                        imagePoint: start,
                        scale: scale * currentTotalZoom,
                        origin: origin,
                        zoom: currentTotalZoom,
                        panOffset: CGSize(width: offset.width + dragOffset.width,
                                         height: offset.height + dragOffset.height)
                    )
                    let viewEnd = imageToViewCoordinatesWithZoom(
                        imagePoint: end,
                        scale: scale * currentTotalZoom,
                        origin: origin,
                        zoom: currentTotalZoom,
                        panOffset: CGSize(width: offset.width + dragOffset.width,
                                         height: offset.height + dragOffset.height)
                    )
                    
                    // Draw line
                    Path { path in
                        path.move(to: viewStart)
                        path.addLine(to: viewEnd)
                    }
                    .stroke(color, lineWidth: lineWidth)
                    
                    // Draw start point handle (larger when dragging)
                    Circle()
                        .fill(color)
                        .frame(
                            width: draggingHandle == .start ? 16 : 12,
                            height: draggingHandle == .start ? 16 : 12
                        )
                        .position(viewStart)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                    
                    // Draw end point handle (larger when dragging)
                    Circle()
                        .fill(color)
                        .frame(
                            width: draggingHandle == .end ? 16 : 12,
                            height: draggingHandle == .end ? 16 : 12
                        )
                        .position(viewEnd)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                    
                    // Draw grab areas to make handles easier to tap
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 30, height: 30)
                        .position(viewStart)
                    
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 30, height: 30)
                        .position(viewEnd)
                    
                    // Draw distance text
                    let midPoint = CGPoint(
                        x: (viewStart.x + viewEnd.x) / 2,
                        y: (viewStart.y + viewEnd.y) / 2 - 20
                    )
                    
                    // Calculate pixel distance from original image coordinates
                    let pixelDistance = sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2))
                    
                    Text("\(Int(pixelDistance)) pixels")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .position(midPoint)
                }
                
                // Zoom indicator
                if totalZoom * currentZoom > 1.0 {
                    VStack {
                        HStack {
                            Text(String(format: "%.1fx", totalZoom * currentZoom))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            
                            Button(action: {
                                withAnimation(.spring()) {
                                    totalZoom = 1.0
                                    offset = .zero
                                    dragOffset = .zero
                                }
                            }) {
                                Text("Reset")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        
                        Spacer()
                    }
                }
                
                // Draw instructions
                if startPoint == nil {
                    VStack(spacing: 8) {
                        Image(systemName: "ruler")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Tap or drag to measure 1 inch on the ruler")
                            .font(.caption)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Line appears above your finger")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        
                        if totalZoom == 1.0 {
                            Text("Pinch to zoom for precision")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    .position(x: container.width / 2, y: container.height - 100)
                } else if startPoint != nil && endPoint != nil {
                    VStack(spacing: 4) {
                        Text("Drag the red circles to adjust")
                            .font(.caption2)
                            .foregroundColor(.white)
                        
                        Text("Tap anywhere to start over")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
                    .position(x: container.width / 2, y: 40)
                }
            }
            .frame(width: container.width, height: container.height)
            .gesture(
                // Prioritize magnification gesture
                MagnificationGesture()
                    .onChanged { value in
                        currentZoom = value
                    }
                    .onEnded { value in
                        totalZoom *= value
                        currentZoom = 1.0
                        
                        // Limit zoom range
                        totalZoom = min(max(totalZoom, 1.0), 5.0)
                    }
            )
            .gesture(
                // Pan gesture for moving zoomed image (only when zoomed)
                DragGesture(minimumDistance: totalZoom * currentZoom > 1.0 ? 0 : 20)
                    .onChanged { value in
                        if totalZoom * currentZoom > 1.0 {
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        let currentTotalZoom = totalZoom * currentZoom
                        if currentTotalZoom > 1.0 {
                            offset.width += value.translation.width
                            offset.height += value.translation.height
                            dragOffset = .zero
                            
                            // Limit panning to keep image partially visible
                            let maxOffset = container.width * (currentTotalZoom - 1) / 2
                            offset.width = min(max(offset.width, -maxOffset), maxOffset)
                            let maxOffsetY = container.height * (currentTotalZoom - 1) / 2
                            offset.height = min(max(offset.height, -maxOffsetY), maxOffsetY)
                        }
                    }
            )
        }
    }
    
    // Convert view coordinates to image pixel coordinates with zoom
    private func viewToImageCoordinatesWithZoom(
        viewPoint: CGPoint,
        containerSize: CGSize,
        imageSize: CGSize,
        scale: CGFloat,
        origin: CGPoint,
        zoom: CGFloat,
        panOffset: CGSize
    ) -> CGPoint {
        // Adjust for pan offset and origin
        let adjustedX = viewPoint.x - origin.x - panOffset.width
        let adjustedY = viewPoint.y - origin.y - panOffset.height
        
        // Convert to image coordinates
        let imageX = adjustedX / scale
        let imageY = adjustedY / scale
        
        // Clamp to image bounds
        let clampedX = max(0, min(imageSize.width, imageX))
        let clampedY = max(0, min(imageSize.height, imageY))
        
        return CGPoint(x: clampedX, y: clampedY)
    }
    
    // Convert image pixel coordinates to view coordinates with zoom
    private func imageToViewCoordinatesWithZoom(
        imagePoint: CGPoint,
        scale: CGFloat,
        origin: CGPoint,
        zoom: CGFloat,
        panOffset: CGSize
    ) -> CGPoint {
        let viewX = origin.x + imagePoint.x * scale + panOffset.width
        let viewY = origin.y + imagePoint.y * scale + panOffset.height
        
        return CGPoint(x: viewX, y: viewY)
    }
    
    // Helper function to calculate distance between two points
    private func distance(from point1: CGPoint, to point2: CGPoint) -> CGFloat {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }
}

#if DEBUG
struct RulerCalibrationOverlay_Previews: PreviewProvider {
    static var previews: some View {
        let uiImage = UIImage(systemName: "ruler")!.withTintColor(.gray, renderingMode: .alwaysOriginal)
        RulerCalibrationOverlay(
            image: uiImage,
            startPoint: .constant(nil),
            endPoint: .constant(nil),
            isDragging: .constant(false)
        )
        .frame(width: 300, height: 300)
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif