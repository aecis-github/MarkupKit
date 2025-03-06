//
//  MarkupImageViewController.swift
//  MarkupableDocumentViewer
//
//  Created by Khoai Nguyen on 10/26/22.
//

import Foundation
import PencilKit
import UIKit

public protocol MarkupDocumentDelegate: AnyObject {
    func didMarkup(_ originalURL: URL?, modifiedURL: URL?)
}

public protocol MarkupImageDelegate: MarkupDocumentDelegate {
    func didFinishRender()
    func didMarkup(_ originalImage: UIImage?, modifiedImage: UIImage?)
}

public final class MarkupImageViewController: MarkupingViewController {
    /// view to show image
    fileprivate weak var imgView: UIImageView!
    private var isFirstTimeZoome: Bool = true

    /// image
    public var imageURL: URL? {
        didSet {
            guard let url = imageURL else { return }
            if let data = UIImage(contentsOfFile: url.path) {
                image = data
            }
        }
    }

    /// image
    public var image: UIImage? {
        didSet {
            clear()
            imgView?.image = image
            updateContentSizeForDrawing()
        }
    }

    /// handle zoom
    fileprivate var imageContentOffset: CGPoint!
    fileprivate var currentZoomScale: CGFloat!

    // delegate
    public var markupDelegate: MarkupImageDelegate?

    override public func viewDidLoad() {
        super.viewDidLoad()

        /// support orientation
        if #available(iOS 16.0, *) {
            setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    public func hasModified() -> Bool {
        return hasModifiedDrawing
    }

    public func save() {
        if hasModifiedDrawing {
            /// set scale to 1.0 to get correct image
            canvasView.setZoomScale(1.0, animated: false)

            /// drawing
            let drawing = canvasView.drawing.image(from: imgView.frame, scale: 1)

            if let modifiedImage = saveImage(drawing: drawing, inRect: .init(origin: .zero, size: drawing.size)) {
                markupDelegate?.didMarkup(image, modifiedImage: modifiedImage)
            } else {
                markupDelegate?.didMarkup(image, modifiedImage: drawing)
            }
        } else {
            markupDelegate?.didMarkup(image, modifiedImage: nil)
        }
    }

    override public func setupAdditionalThings() {
        /// add image
        let imgView = UIImageView(image: image)
        imgView.contentMode = .scaleAspectFit
        imgView.isUserInteractionEnabled = false

        canvasView.insertSubview(imgView, at: 0)
        canvasView.sendSubviewToBack(imgView)
        self.imgView = imgView
    }

    override func handleRestoredStateFromBackground() {
        if currentZoomScale != nil && imageContentOffset != nil {
            canvasView.contentOffset = imageContentOffset
            canvasView.zoomScale = currentZoomScale
        }
    }

    override func zoomableView() -> UIView? { imgView }

    override func updateContentSizeForDrawing() {
        guard canvasView != nil, let img = image else { return }

        /// calculate scale to fit in center
        canvasView.contentSize = CGSize.getAspectFitSize(
            canvasView.frame.size,
            originalSize: img.size
        )

        /// update image size
        updateImageViewCenter(in: canvasView)
    }

    fileprivate func updateImageViewCenter(in scrollView: UIScrollView) {
        guard let imgView = imgView, let img = image else { return }
        let contentSize = scrollView.contentSize

        let imgViewRect = CGSize.getAspectFitRect(
            scrollView.frame.size * scrollView.zoomScale,
            originalSize: img.size
        )

        /// calculate image size fit in center
        imgView.frame = imgViewRect
        imgView.center = CGPoint(contentSize.width * 0.5, contentSize.height * 0.5)

        /// store to handle whenener appreance
        imageContentOffset = scrollView.contentOffset
        currentZoomScale = scrollView.zoomScale
    }

    override func didZoom(in scrollView: UIScrollView) {
        if scrollView == canvasView {
            updateImageViewCenter(in: canvasView)
        }
    }

    override func didScroll(in scrollView: UIScrollView) {
        if scrollView == canvasView {
            /// store to handle whenener appreance
            imageContentOffset = canvasView.contentOffset
            currentZoomScale = canvasView.zoomScale
        }
    }

    override func canvasViewDidFinishRendering() {
        markupDelegate?.didFinishRender()
    }
}

extension MarkupImageViewController {
    public func saveImage(drawing: UIImage, inRect rect: CGRect) -> UIImage? {
        guard let image = image else { return nil }
        return autoreleasepool { () -> UIImage? in
            let format = UIGraphicsImageRendererFormat()
            format.scale = UIScreen.current?.scale ?? 1.0

            return UIGraphicsImageRenderer(size: rect.size, format: format).image { _ in
                image.draw(in: rect)
                drawing.draw(in: rect)
            }
        }
    }
}
