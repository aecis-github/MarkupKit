//
//  MarkupPDFViewController.swift
//  MarkupableDocumentViewer
//
//  Created by Khoai Nguyen on 10/27/22.
//

import Combine
import PDFKit
import PencilKit
import QuickLook
import UIKit

// MARK: EditorEvent

public enum EditorEvent: CustomStringConvertible {
    case none
    case willShowMarkupBar
    case didHideMarkupBar
    case didEndMarkup
    case willEditNote
    case willDeleteFile

    public var description: String {
        switch self {
        case .none: return ".none"
        case .willShowMarkupBar: return ".willBeginMarkup"
        case .didHideMarkupBar: return ".didHideMarkupBar"
        case .didEndMarkup: return ".didEndMarkup"
        case .willEditNote: return ".willEditNote"
        case .willDeleteFile: return ".willDeleteFile"
        }
    }
}

// MARK: PlaceholderViewType

public enum PlaceholderViewType: String {
    case none
    case notSupported
    case loading
    case completed
}

// MARK: UIConfiguration

public struct UIConfiguration {
    /// for back button
    public var backButtonIcon: UIImage?
    public var backButtonTitle: String = ""

    /// for caption text
    public var captionButtonIcon: UIImage?

    /// for delete
    public var deleteButtonIcon: UIImage?

    public var shareButtonHidden: Bool = false
    public var printButtonHidden: Bool = false

    /// navigation
    public var navigationBarTintColor: UIColor = .red

    /// toolbar
    public var toolBarTintColor: UIColor = .red
}

// MARK: DocumentViewControllerDelegate

public protocol DocumentViewControllerDelegate: AnyObject {
    func documentController(_ controller: DocumentViewController, receiveEvent event: EditorEvent)
    func documentController(_ controller: DocumentViewController, viewForItem item: QLPreviewItem) -> UIView?
}

// MARK: DocumentViewController

public class DocumentViewController: QLPreviewController {
    public var items: [QLPreviewItem]! = []
    public var editingMode: QLPreviewItemEditingMode = .createCopy
    public weak var markupDelegate: MarkupDocumentDelegate?
    public weak var markupControllerDelegate: DocumentViewControllerDelegate?
    public var isMarkuping: Bool = false
    private var processing: Bool = false
    
    /// UI/UX Configuration
    public var uiConfiguration = UIConfiguration()

    /// toolbar changes
    private var toolBarChanges = CurrentValueSubject<Bool, Error>(false)
    private var cancellables = Set<AnyCancellable>()

    override public func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never

        /// set back bar item
        let backButtonBarItem = UIBarButtonItem(
            image: uiConfiguration.backButtonIcon,
            style: .plain,
            target: self,
            action: #selector(onTouchBackButton(_:))
        )
        navigationItem.leftBarButtonItem = backButtonBarItem

        /// monitor tool changes
        toolBarChanges.debounce(
            for: .seconds(0.5),
            scheduler: RunLoop.main
        )
        .sink { _ in
        } receiveValue: { [weak self] _ in
            self?.invalidateToolbar()
        }.store(in: &cancellables)
    }

    public func updateData() {
        guard !items.isEmpty, let url = items.first?.previewItemURL else { return }
        guard currentPreviewItem == nil || currentPreviewItem!.previewItemURL != url else { return }

        if delegate == nil {
            dataSource = self
            delegate = self
        }
        reloadData()
    }

    public func invalidateToolbar() {
        guard let toolbar = navigationController?.toolbar else { return }
        toolbar.tintColor = uiConfiguration.navigationBarTintColor

        var items = toolbar.items ?? []
        var shouldUpdateItems = false
        let startPosition: Int = (items.isEmpty ? 0 : 1)

        /// flexibleItem
        let flexibleItem = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        /// add caption button
        if uiConfiguration.captionButtonIcon != nil {
            if !items.contains(where: { $0.tag == 99 }) {
                let captionNote = UIBarButtonItem(
                    image: uiConfiguration.captionButtonIcon,
                    style: .plain,
                    target: self,
                    action: #selector(didNoteItem(_:))
                )
                captionNote.tag = 99
                items.insert(contentsOf: [flexibleItem, captionNote], at: startPosition)
            }
            shouldUpdateItems = true
        }

        if shouldUpdateItems {
            navigationController?.setToolbarItems(items, animated: false)
        }

        /// IsMarkuping = All System Items(Action + FlexibleSpaces)
        /// Otherwise, false
        let isMarkuping = (toolbar.superview == nil)
        self.isMarkuping = isMarkuping
        if isMarkuping {
            markupControllerDelegate?.documentController(self, receiveEvent: .willShowMarkupBar)
        } else {
            markupControllerDelegate?.documentController(self, receiveEvent: .didHideMarkupBar)
        }
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        toolBarChanges.send(true)
    }

    deinit {}
}

// MARK: Events

extension DocumentViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    @objc private func didNoteItem(_ sender: Any) {
        markupControllerDelegate?.documentController(self, receiveEvent: .willEditNote)
    }

    @objc private func didDeleteItem(_ sender: Any) {
        markupControllerDelegate?.documentController(self, receiveEvent: .willDeleteFile)
    }
}

extension DocumentViewController {
    public class func isValidContent(of url: URL) -> Bool {
        return canPreview(url as QLPreviewItem)
    }
}

extension DocumentViewController {
    @objc fileprivate func onTouchBackButton(_ sender: Any) {
        if presentationController != nil {
            navigationController?.dismiss(animated: false)
        } else {
            navigationController?.popViewController(animated: false)
        }
    }
}

extension DocumentViewController: QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return (items != nil ? items.count : 0)
    }

    public func previewController(
        _ controller: QLPreviewController,
        previewItemAt index: Int
    ) -> QLPreviewItem {
        /// delegate to show corresponding view basing status

        return items[index]
    }

    public func previewController(_ controller: QLPreviewController, shouldOpen url: URL, for item: QLPreviewItem) -> Bool {
        return true
    }

    public func previewController(_ controller: QLPreviewController, didUpdateContentsOf previewItem: QLPreviewItem) {
        DispatchQueue.main.async { [weak self] in
            guard let owner = self else { return }
            owner.markupDelegate?.didMarkup(previewItem.previewItemURL, modifiedURL: nil)
        }
    }

    public func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
        return editingMode
    }

    public func previewController(_ controller: QLPreviewController, didSaveEditedCopyOf previewItem: QLPreviewItem, at modifiedContentsURL: URL) {
        DispatchQueue.main.async { [weak self] in
            guard let owner = self else { return }
            owner.markupDelegate?.didMarkup(previewItem.previewItemURL, modifiedURL: modifiedContentsURL)
        }
    }
}
