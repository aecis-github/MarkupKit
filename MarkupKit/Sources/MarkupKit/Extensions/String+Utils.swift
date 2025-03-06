//
//  File.swift
//
//
//  Created by Khoai Nguyen on 3/23/23.
//

import Foundation

extension String {
    static func pointer(_ object: AnyObject?) -> String {
        guard let object = object else { return "nil" }
        let opaque: UnsafeMutableRawPointer = Unmanaged.passUnretained(object).toOpaque()
        return String(describing: opaque)
    }
}
