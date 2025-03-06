//
//  MarkupNavigationViewController.swift
//  MarkupableDocumentViewer
//
//  Created by Khoai Nguyen on 10/27/22.
//

import UIKit

class MarkupNavigationViewController: UINavigationController {
    override var shouldAutorotate: Bool {
        return false
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIDevice.current.orientation.interfaceOrientationMask
    }
}
