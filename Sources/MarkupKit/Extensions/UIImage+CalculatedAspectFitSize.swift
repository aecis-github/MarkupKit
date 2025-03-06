//
//  File.swift
//  MarkupKit
//
//  Created by Khoai Nguyen on 11/22/24.
//

import UIKit

public extension UIImage {
    func getFitSize(_ targetSize: CGSize) -> CGSize {
        let imageSize = size
        if imageSize.width > imageSize.height {
            return getAspectFitWidth(targetSize.width)
        }
        return getAspectFitHeight(targetSize.height)
    }

    func getAspectFitWidth(_ width: CGFloat) -> CGSize {
        CGSize.getAspectFitWidth(width, originalSize: size)
    }

    func getAspectFitHeight(_ height: CGFloat) -> CGSize {
        CGSize.getAspectFitHeight(height, originalSize: size)
    }
}

public extension CGSize {
    static func getAspectFitHeight(_ height: CGFloat, originalSize: CGSize) -> CGSize {
        let ratio = height / originalSize.height
        let newWidth = ratio * originalSize.width
        let size = CGSize(width: newWidth, height: height)
        return size
    }

    static func getAspectFitWidth(_ width: CGFloat, originalSize: CGSize) -> CGSize {
        let ratio = width / originalSize.width
        let newHeight = ratio * originalSize.height
        let size = CGSize(width: width, height: newHeight)

        return size
    }

    static func getAspectFitRect(_ targetSize: CGSize, originalSize: CGSize) -> CGRect {
        let aspectWidth = targetSize.width / originalSize.width
        let aspectHeight = targetSize.height / originalSize.height
        let aspectRatio = min(aspectWidth, aspectHeight)

        let newWidth = aspectRatio * originalSize.width
        let newHeight = aspectRatio * originalSize.height
        let x = (targetSize.width - newWidth) * 0.5
        let y = (targetSize.height - newHeight) * 0.5

        return CGRect(x: x, y: y, width: newWidth, height: newHeight)
    }

    static func getAspectFitSize(_ targetSize: CGSize, originalSize: CGSize) -> CGSize {
        return getAspectFitRect(targetSize, originalSize: originalSize).size
    }
}
