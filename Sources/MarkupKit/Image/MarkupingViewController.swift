//
//  MarkupingViewController.swift
//  MarkupableDocumentViewer
//
//  Created by Khoai Nguyen on 10/26/22.
//

import Foundation
import PencilKit

// MARK: Constants

public struct MarkupingConfiguration {
    let canvasWidth: CGFloat
    let canvasOverscrollHeight: CGFloat
    let fingerDrawingEnabledLabel: String
    let fingerDrawingDisabledLabel: String

    public init(
        canvasWidth: CGFloat,
        canvasOverscrollHeight: CGFloat,
        fingerDrawingEnabledLabel: String = "Enable Finger Drawing",
        fingerDrawingDisabledLabel: String = "Disable Finger Drawing"
    ) {
        self.canvasWidth = canvasWidth
        self.canvasOverscrollHeight = canvasOverscrollHeight
        self.fingerDrawingEnabledLabel = fingerDrawingEnabledLabel
        self.fingerDrawingDisabledLabel = fingerDrawingDisabledLabel
    }
}

// MARK: MarkupingViewController

open class MarkupingViewController: UIViewController {
    internal var canvasView: PKCanvasView! {
        return view.viewWithTag(99) as? PKCanvasView
    }

    public var isReadyForDrawing: Bool = false

    fileprivate var toolPicker: PKToolPicker!

    /// for iPhone screen
    fileprivate var undoBarButtonitem: UIBarButtonItem!
    fileprivate var redoBarButtonItem: UIBarButtonItem!

    /// On iOS 14.0, this is no longer necessary as the finger vs pencil toggle is a global setting in the toolpicker
    fileprivate var pencilFingerBarButtonItem: UIBarButtonItem!

    /// a flag is turned on whenever any modification from drawing
    internal var hasModifiedDrawing: Bool {
        if #available(iOS 14.0, *) {
            return (canvasView?.drawing.strokes.count ?? 0) > 0
        } else {
            return true
        }
    }

    /// flag to handle app state
    fileprivate var restoredStateFromBackground: Bool = false
    fileprivate var isFirstUpdateFrame: Bool = true

    /// configuration
    public var configuration: MarkupingConfiguration = .init(
        canvasWidth: 500,
        canvasOverscrollHeight: 700
    )

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupCanvas()
    }

    /// When the view is resized, adjust the canvas scale so that it is zoomed to the default `canvasWidth`.
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        /// handle layout
        if restoredStateFromBackground {
            handleRestoredStateFromBackground()
            restoredStateFromBackground = false
        } else if isFirstUpdateFrame {
            isFirstUpdateFrame = false
            layoutSubviews()
        }
    }

    /// When the view is removed, save the modified drawing, if any.
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Remove this view controller as the screenshot delegate.
        view.window?.windowScene?.screenshotService?.delegate = nil
    }

    override open func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
    }

    /// Hide the home indicator, as it will affect latency.
    override open var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    // MARK: Setup PencilCanvas, PickerTool

    open func setupAdditionalThings() {}

    open func setupCanvas() {
        guard canvasView == nil else { return }

        /// monitor didAppInBackground
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restoredStateFromBackground = true
        }

        /// canvas
        let canvasView = PKCanvasView()
        canvasView.tag = 99
        canvasView.contentInsetAdjustmentBehavior = .never
        canvasView.bouncesZoom = false
        canvasView.maximumZoomScale = 5
        canvasView.isOpaque = false
        canvasView.backgroundColor = .clear
        canvasView.contentOffset = CGPoint.zero
        view.addSubview(canvasView)

        canvasView.translatesAutoresizingMaskIntoConstraints = false
        let guide = canvasView.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            guide.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            guide.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            guide.topAnchor.constraint(equalTo: view.topAnchor),
            guide.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // more setup
        setupAdditionalThings()

        // Set up the canvas view with the first drawing from the data model.
        canvasView.delegate = self
        canvasView.alwaysBounceVertical = true

        // Set up the tool picker
        if #available(iOS 14.0, *) {
            toolPicker = PKToolPicker()
        } else {
            // Set up the tool picker, using the window of our parent because our view has not
            // been added to a window yet.
            let window = parent?.view.window
            toolPicker = PKToolPicker.shared(for: window!)
        }

        toolPicker.addObserver(canvasView)
        toolPicker.addObserver(self)
        updateLayout(for: toolPicker)

        isReadyForDrawing = true
        canvasView.becomeFirstResponder()

        // Before iOS 14, add a button to toggle finger drawing.
        if #available(iOS 14.0, *) { } else {
            pencilFingerBarButtonItem = UIBarButtonItem(
                title: configuration.fingerDrawingEnabledLabel,
                style: .plain,
                target: self,
                action: #selector(toggleFingerPencilDrawing(_:))
            )
            navigationItem.rightBarButtonItems?.append(pencilFingerBarButtonItem)
            canvasView.allowsFingerDrawing = false
        }

        if UIDevice.current.userInterfaceIdiom != .pad {
            undoBarButtonitem = UIBarButtonItem(
                barButtonSystemItem: .undo,
                target: self,
                action: #selector(onUndo(_:))
            )

            redoBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .redo,
                target: self,
                action: #selector(onRedo(_:))
            )
        }

        // Always show a back button.
        navigationItem.leftItemsSupplementBackButton = true

        // Set this view controller as the delegate for creating full screenshots.
        parent?.view.window?.windowScene?.screenshotService?.delegate = self
    }

    /// Helper method to set a suitable content size for the canvas view.
    func layoutSubviews() {
        // Scroll to the top.
        updateContentSizeForDrawing()
    }

    func handleRestoredStateFromBackground() {}

    func updateContentSizeForDrawing() {
        // Update the content size to match the drawing.
        let drawing = canvasView.drawing
        let contentHeight: CGFloat

        // Adjust the content size to always be bigger than the drawing height.
        if !drawing.bounds.isNull {
            contentHeight = max(canvasView.bounds.height, (drawing.bounds.maxY + configuration.canvasOverscrollHeight) * canvasView.zoomScale)
        } else {
            contentHeight = canvasView.bounds.height
        }
        canvasView.contentSize = CGSize(width: configuration.canvasWidth * canvasView.zoomScale, height: contentHeight)
    }

    // MARK: Handle Zoom

    func zoomableView() -> UIView? { nil }
    func didZoom(in scrollView: UIScrollView) {}
    func didScroll(in scrollView: UIScrollView) {}

    // MARK: Actions

    /// Action method: Turn finger drawing on or off, but only on devices before iOS 14.0
    @objc func toggleFingerPencilDrawing(_ sender: Any) {
        if #available(iOS 14.0, *) { } else {
            canvasView.allowsFingerDrawing.toggle()
            let title = canvasView.allowsFingerDrawing ? configuration.fingerDrawingDisabledLabel : configuration.fingerDrawingEnabledLabel
            pencilFingerBarButtonItem.title = title
        }
    }

    @objc func onUndo(_ sender: Any) {
        undoManager?.undo()
    }

    @objc func onRedo(_ sender: Any) {
        undoManager?.redo()
    }

    public func clear() {
        canvasView?.drawing = PKDrawing()
    }

    public func toggleMarkupTool() {
        enableMarkupTool(!toolPicker.isVisible)
    }

    public func enableMarkupTool(_ status: Bool) {
        if status {
            isReadyForDrawing = true
            canvasView.becomeFirstResponder()
        } else {
            isReadyForDrawing = false
            canvasView.resignFirstResponder()
        }
        toolPicker.setVisible(status, forFirstResponder: canvasView)
    }

    func canvasViewDidFinishRendering() {}
}

// MARK: Helpers

extension MarkupingViewController {
    /// Helper method to adjust the canvas view size when the tool picker changes which part
    /// of the canvas view it obscures, if any.
    ///
    /// Note that the tool picker floats over the canvas in regular size classes, but docks to
    /// the canvas in compact size classes, occupying a part of the screen that the canvas
    /// could otherwise use.
    fileprivate func updateLayout(for toolPicker: PKToolPicker) {
        let obscuredFrame = toolPicker.frameObscured(in: view)

        // If the tool picker is floating over the canvas, it also contains
        // undo and redo buttons.
        if obscuredFrame.isNull {
            canvasView.contentInset = .zero
            navigationItem.leftBarButtonItems = []
        }

        // Otherwise, the bottom of the canvas should be inset to the top of the
        // tool picker, and the tool picker no longer displays its own undo and
        // redo buttons.
        else {
            guard let undoBarButtonitem = undoBarButtonitem, let redoBarButtonItem = redoBarButtonItem else {
                return
            }
            canvasView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: view.bounds.maxY - obscuredFrame.minY, right: 0)
            navigationItem.leftBarButtonItems = [undoBarButtonitem, redoBarButtonItem]
        }
        canvasView.scrollIndicatorInsets = canvasView.contentInset
    }

    /// Helper method to set a new drawing, with an undo action to go back to the old one.
    fileprivate func setNewDrawingUndoable(_ newDrawing: PKDrawing) {
        let oldDrawing = canvasView.drawing
        undoManager?.registerUndo(withTarget: self) {
            $0.setNewDrawingUndoable(oldDrawing)
        }
        canvasView.drawing = newDrawing
    }
}

// MARK: PKCanvasViewDelegate

extension MarkupingViewController: PKCanvasViewDelegate {
    public func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
    }

    public func canvasViewDidFinishRendering(_ canvasView: PKCanvasView) {
        canvasViewDidFinishRendering()
    }

    public func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
    }

    public func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
    }

    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        zoomableView()
    }

    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        didZoom(in: scrollView)
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        didScroll(in: scrollView)
    }
}

// MARK: PKToolPickerObserver

extension MarkupingViewController: PKToolPickerObserver {
    /// Delegate method: Note that the tool picker has changed which part of the canvas view
    /// it obscures, if any.
    public func toolPickerFramesObscuredDidChange(_ toolPicker: PKToolPicker) {
        updateLayout(for: toolPicker)
    }

    /// Delegate method: Note that the tool picker has become visible or hidden.
    public func toolPickerVisibilityDidChange(_ toolPicker: PKToolPicker) {
        updateLayout(for: toolPicker)
    }
}

// MARK: UIScreenshotServiceDelegate

extension MarkupingViewController: UIScreenshotServiceDelegate {
    // MARK: Screenshot Service Delegate

    /// Delegate method: Generate a screenshot as a PDF.
    public func screenshotService(
        _ screenshotService: UIScreenshotService,
        generatePDFRepresentationWithCompletion completion:
        @escaping (_ PDFData: Data?, _ indexOfCurrentPage: Int, _ rectInCurrentPage: CGRect) -> Void) {
        // Find out which part of the drawing is actually visible.
        let drawing = canvasView.drawing
        let visibleRect = canvasView.bounds

        // Convert to PDF coordinates, with (0, 0) at the bottom left hand corner,
        // making the height a bit bigger than the current drawing.
        let pdfWidth = configuration.canvasWidth
        let pdfHeight = drawing.bounds.maxY + 100
        let canvasContentSize = canvasView.contentSize.height - configuration.canvasOverscrollHeight

        let xOffsetInPDF = pdfWidth - (pdfWidth * visibleRect.minX / canvasView.contentSize.width)
        let yOffsetInPDF = pdfHeight - (pdfHeight * visibleRect.maxY / canvasContentSize)
        let rectWidthInPDF = pdfWidth * visibleRect.width / canvasView.contentSize.width
        let rectHeightInPDF = pdfHeight * visibleRect.height / canvasContentSize

        let visibleRectInPDF = CGRect(
            x: xOffsetInPDF,
            y: yOffsetInPDF,
            width: rectWidthInPDF,
            height: rectHeightInPDF)

        // Generate the PDF on a background thread.
        DispatchQueue.global(qos: .background).async {
            // Generate a PDF.
            let bounds = CGRect(x: 0, y: 0, width: pdfWidth, height: pdfHeight)
            let mutableData = NSMutableData()
            UIGraphicsBeginPDFContextToData(mutableData, bounds, nil)
            UIGraphicsBeginPDFPage()

            // Generate images in the PDF, strip by strip.
            var yOrigin: CGFloat = 0
            let imageHeight: CGFloat = 1024
            while yOrigin < bounds.maxY {
                let imgBounds = CGRect(
                    x: 0,
                    y: yOrigin,
                    width: self.configuration.canvasWidth,
                    height: min(imageHeight, bounds.maxY - yOrigin)
                )
                let img = drawing.image(from: imgBounds, scale: 2)
                img.draw(in: imgBounds)
                yOrigin += imageHeight
            }

            UIGraphicsEndPDFContext()

            // Invoke the completion handler with the generated PDF data.
            completion(mutableData as Data, 0, visibleRectInPDF)
        }
    }
}
