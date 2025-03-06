//
//  File.swift
//
//
//  Created by Khoai Nguyen on 3/14/23.
//

import QuickLook

public protocol MarkupPreviewItem: QLPreviewItem {
    var placeHolderType: PlaceholderViewType { get }
}

public class PreviewItem: NSObject, MarkupPreviewItem {
    public var placeHolderType: PlaceholderViewType { .none }
    public var previewItemURL: URL?
    public var previewItemTitle: String?

    public init(url: URL? = nil, title: String? = nil) {
        previewItemURL = url
        previewItemTitle = title
    }

    override public func isEqual(_ object: Any?) -> Bool {
        if let object = object as? PreviewItem {
            return previewItemURL == object.previewItemURL
        }
        return false
    }

    public static func == (lhs: PreviewItem, rhs: PreviewItem) -> Bool {
        return lhs.previewItemURL == rhs.previewItemURL
    }
}
