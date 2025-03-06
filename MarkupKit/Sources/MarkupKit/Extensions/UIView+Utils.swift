//
//  File.swift
//
//
//  Created by Khoai Nguyen on 3/14/23.
//

import UIKit

extension UIView {
    func findViews<T: UIView>(_ type: T.Type) -> [T] {
        var items: [T] = []
        for subview in subviews {
            if subview is T {
                items.append(subview as! T)
            }
            items.append(contentsOf: subview.findViews(type))
        }
        return items
    }

    func find(_ name: String) -> [UIView] {
        var items: [UIView] = []
        for subview in subviews {
            debugPrint(subview.classForCoder.description())
            if subview.classForCoder.description().lowercased().contains(name.lowercased()) {
                items.append(subview)
            }
            items.append(contentsOf: subview.find(name))
        }
        return items
    }
}

extension UIBarButtonItem {
    var view: UIView? { value(forKey: "view") as? UIView }
}
