//
//	CoreGraphics+Z.swift
//	ZKit
//
//	The MIT License (MIT)
//
//	Copyright (c) 2016 Electricwoods LLC, Kaz Yoshikawa.
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the Software is
//	furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in
//	all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//	THE SOFTWARE.
//

import CoreGraphics
import CoreImage
import Foundation

infix operator •
infix operator ×

protocol CGFloatCovertible {
    var cgFloatValue: CGFloat { get }
}

extension CGFloat: CGFloatCovertible {
    var cgFloatValue: CGFloat { return self }
}

extension Float: CGFloatCovertible {
    var cgFloatValue: CGFloat { return CGFloat(self) }
}

extension Double: CGFloatCovertible {
    var cgFloatValue: CGFloat { return CGFloat(self) }
}

extension Int: CGFloatCovertible {
    var cgFloatValue: CGFloat { return CGFloat(self) }
}

extension CGPoint {
    init<X: CGFloatCovertible, Y: CGFloatCovertible>(_ x: X, _ y: Y) {
        self = CGPoint(x: x.cgFloatValue, y: y.cgFloatValue)
    }
}

extension CGSize {
    init<W: CGFloatCovertible, H: CGFloatCovertible>(_ w: W, _ h: H) {
        self = CGSize(width: w.cgFloatValue, height: h.cgFloatValue)
    }
}

extension CGRect {
    init<X: CGFloatCovertible, Y: CGFloatCovertible, W: CGFloatCovertible, H: CGFloatCovertible>(_ x: X, _ y: Y, _ w: W, _ h: H) {
        self = CGRect(x: x.cgFloatValue, y: y.cgFloatValue, width: w.cgFloatValue, height: h.cgFloatValue)
    }
}

func DegreesToRadians(_ value: CGFloat) -> CGFloat {
    return value * CGFloat.pi / 180.0
}

func RadiansToDegrees(_ value: CGFloat) -> CGFloat {
    return value * 180.0 / CGFloat.pi
}

extension CGAffineTransform: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        [a, b, c, d, tx, ty].forEach { hasher.combine($0) }
    }
}

extension CGPoint {
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    static func / (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
    }

    static func • (lhs: CGPoint, rhs: CGPoint) -> CGFloat { // dot product
        return lhs.x * rhs.x + lhs.y * rhs.y
    }

    static func × (lhs: CGPoint, rhs: CGPoint) -> CGFloat { // cross product
        return lhs.x * rhs.y - lhs.y * rhs.x
    }

    var length²: CGFloat {
        return (x * x) + (y * y)
    }

    var length: CGFloat {
        return sqrt(length²)
    }

    var normalized: CGPoint {
        let length = self.length
        return CGPoint(x: x / length, y: y / length)
    }

    var size: CGSize { return CGSize(width: x, height: y) }
}

extension CGRect {
    var cgPath: CGPath {
        return CGPath(rect: self, transform: nil)
    }

    func cgPath(cornerRadius: CGFloat) -> CGPath {
        //	+7-------------6+
        //	0				5
        //	|				|
        //	1				4
        //	+2-------------3+

        let cornerRadius = min(size.width * 0.5, size.height * 0.5, cornerRadius)
        let path = CGMutablePath()
        path.move(to: minXmidY + CGPoint(x: 0, y: cornerRadius)) // (0)
        path.addLine(to: minXmaxY - CGPoint(x: 0, y: cornerRadius)) // (1)
        path.addQuadCurve(to: minXmaxY + CGPoint(x: cornerRadius, y: 0), control: minXmaxY) // (2)
        path.addLine(to: maxXmaxY - CGPoint(x: cornerRadius, y: 0)) // (3)
        path.addQuadCurve(to: maxXmaxY - CGPoint(x: 0, y: cornerRadius), control: maxXmaxY) // (4)
        path.addLine(to: maxXminY + CGPoint(x: 0, y: cornerRadius)) // (5)
        path.addQuadCurve(to: maxXminY - CGPoint(x: cornerRadius, y: 0), control: maxXminY) // (6)
        path.addLine(to: minXminY + CGPoint(x: cornerRadius, y: 0)) // (7)
        path.addQuadCurve(to: minXminY + CGPoint(x: 0, y: cornerRadius), control: minXminY) // (0)
        path.closeSubpath()
        return path
    }

    var minXminY: CGPoint { return CGPoint(x: minX, y: minY) }
    var midXminY: CGPoint { return CGPoint(x: midX, y: minY) }
    var maxXminY: CGPoint { return CGPoint(x: maxX, y: minY) }

    var minXmidY: CGPoint { return CGPoint(x: minX, y: midY) }
    var midXmidY: CGPoint { return CGPoint(x: midX, y: midY) }
    var maxXmidY: CGPoint { return CGPoint(x: maxX, y: midY) }

    var minXmaxY: CGPoint { return CGPoint(x: minX, y: maxY) }
    var midXmaxY: CGPoint { return CGPoint(x: midX, y: maxY) }
    var maxXmaxY: CGPoint { return CGPoint(x: maxX, y: maxY) }

    func aspectFill(_ size: CGSize) -> CGRect {
        let result: CGRect
        let margin: CGFloat
        let horizontalRatioToFit = self.size.width / size.width
        let verticalRatioToFit = self.size.height / size.height
        let imageHeightWhenItFitsHorizontally = horizontalRatioToFit * size.height
        let imageWidthWhenItFitsVertically = verticalRatioToFit * size.width
        let minX = self.minX
        let minY = self.minY

        if imageHeightWhenItFitsHorizontally > self.size.height {
            margin = (imageHeightWhenItFitsHorizontally - self.size.height) * 0.5
            result = CGRect(x: minX, y: minY - margin, width: size.width * horizontalRatioToFit, height: size.height * horizontalRatioToFit)
        } else {
            margin = (imageWidthWhenItFitsVertically - self.size.width) * 0.5
            result = CGRect(x: minX - margin, y: minY, width: size.width * verticalRatioToFit, height: size.height * verticalRatioToFit)
        }
        return result
    }

    func aspectFit(_ size: CGSize) -> CGRect {
        let minX = self.minX
        let minY = self.minY
        let widthRatio = self.size.width / size.width
        let heightRatio = self.size.height / size.height
        let ratio = min(widthRatio, heightRatio)
        let width = size.width * ratio
        let height = size.height * ratio
        let xmargin = (self.size.width - width) / 2.0
        let ymargin = (self.size.height - height) / 2.0
        return CGRect(x: minX + xmargin, y: minY + ymargin, width: width, height: height)
    }

    func transform(to rect: CGRect) -> CGAffineTransform {
        var t = CGAffineTransform.identity
        t = t.translatedBy(x: -minX, y: -minY)
        t = t.scaledBy(x: 1 / width, y: 1 / height)
        t = t.scaledBy(x: rect.width, y: rect.height)
        t = t.translatedBy(x: rect.minX * width / rect.width, y: rect.minY * height / rect.height)
        return t
    }

    var center: CGPoint {
        get { return midXmidY }
        set { origin = newValue - (CGPoint(x: width, y: height) * 0.5) }
    }

    func centered(at point: CGPoint) -> CGRect {
        return CGRect(origin: CGPoint(x: -width * 0.5, y: -height * 0.5), size: size)
    }

    static var A4: CGRect { return CGRect(x: 0, y: 0, width: 1654, height: 2339) }
    static var USLetter: CGRect { return CGRect(x: 0, y: 0, width: 1700, height: 2200) }

    static func + (lhs: CGRect, rhs: CGPoint) -> CGRect {
        return CGRect(origin: lhs.origin + rhs, size: lhs.size)
    }

    static func - (lhs: CGRect, rhs: CGPoint) -> CGRect {
        return CGRect(origin: lhs.origin - rhs, size: lhs.size)
    }

    static func += (lhs: inout CGRect, rhs: CGPoint) {
        lhs = lhs + rhs
    }

    static func -= (lhs: inout CGRect, rhs: CGPoint) {
        lhs = lhs - rhs
    }
}

extension CGSize {
    // resize given size to fit in this
    func aspectFit(_ size: CGSize) -> CGSize {
        let widthRatio = self.width / size.width
        let heightRatio = self.height / size.height
        let ratio = (widthRatio < heightRatio) ? widthRatio : heightRatio
        let width = size.width * ratio
        let height = size.height * ratio
        return CGSize(width: width, height: height)
    }

    var aspectRatio: CGFloat { return width / height }

    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }

    static func - (lhs: CGSize, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
    }

    static func * (lhs: CGSize, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs.width * rhs.width, height: lhs.height * rhs.height)
    }

    static func / (lhs: CGSize, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs.width / rhs.width, height: lhs.height / rhs.height)
    }

    static func * (lhs: CGSize, rhs: CGFloat) -> CGSize {
        return CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
    }

    static func / (lhs: CGSize, rhs: CGFloat) -> CGSize {
        return CGSize(width: lhs.width / rhs, height: lhs.height / rhs)
    }

    var point: CGPoint { return CGPoint(x: width, y: height) }
}

extension CGAffineTransform {
    static func * (lhs: CGAffineTransform, rhs: CGAffineTransform) -> CGAffineTransform {
        return lhs.concatenating(rhs)
    }
}

extension CGContext {
    func strokeLines(points: [CGPoint]) {
        if points.count > 1 {
            for (index, point) in points.enumerated() {
                if index == 0 { move(to: point) }
                else { addLine(to: point) }
            }
            strokePath()
        }
    }

    func strokeLine(_ point1: CGPoint, _ point2: CGPoint) {
        strokeLines(points: [point1, point2])
    }
}
