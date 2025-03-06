//
//  UIScreen+Exts.swift
//  MarkupableDocumentViewer
//
//  Created by Khoai Nguyen on 11/21/24.
//

import UIKit

@available(iOSApplicationExtension, unavailable)
extension UIWindow {
    static var current: UIWindow? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                if window.isKeyWindow { return window }
            }
        }
        return nil
    }
}

@available(iOSApplicationExtension, unavailable)
extension UIScreen {
    static var current: UIScreen? {
        UIWindow.current?.screen
    }
}
