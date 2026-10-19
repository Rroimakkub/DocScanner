import SwiftUI
import UIKit

/// An image that can be pinched or double-tapped to zoom, backed by UIScrollView.
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> ZoomingImageScrollView {
        ZoomingImageScrollView()
    }

    func updateUIView(_ view: ZoomingImageScrollView, context: Context) {
        view.setImage(image)
    }
}

final class ZoomingImageScrollView: UIScrollView, UIScrollViewDelegate {
    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 5
        bouncesZoom = true
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        backgroundColor = .clear

        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setImage(_ image: UIImage) {
        guard imageView.image !== image else { return }
        imageView.image = image
        setZoomScale(minimumZoomScale, animated: false)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // While unzoomed, the image view fills the visible area; zooming scales it from there.
        if zoomScale == minimumZoomScale, imageView.frame.size != bounds.size {
            imageView.frame = CGRect(origin: .zero, size: bounds.size)
            contentSize = bounds.size
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        if zoomScale > minimumZoomScale {
            setZoomScale(minimumZoomScale, animated: true)
            return
        }
        let point = recognizer.location(in: imageView)
        let scale = min(maximumZoomScale, 2.5)
        let size = CGSize(width: bounds.width / scale, height: bounds.height / scale)
        let rect = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height)
        zoom(to: rect, animated: true)
    }
}
