//
//  UIDevice+Orientations.swift
//  MarkupableDocumentViewer
//
//  Created by Khoai Nguyen on 10/27/22.
//

import Foundation
import UIKit

public extension UIDeviceOrientation {
    var interfaceOrientationMask: UIInterfaceOrientationMask {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        case .faceUp: return .allButUpsideDown
        default: return .all
        }
    }
}
