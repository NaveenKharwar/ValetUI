import AppKit
import SwiftUI

/// Loads the official WordPress logo SVG from the app bundle.
enum WordPressLogo {

    /// NSImage for use in AppKit / Label icons.
    /// Falls back to a simple drawn placeholder if bundle resource is missing.
    static func nsImage(size: CGFloat = 16) -> NSImage {
        if let url = Bundle.main.url(forResource: "wordpress-logo", withExtension: "svg"),
           let img = NSImage(contentsOf: url) {
            img.isTemplate = false
            let result = NSImage(size: NSSize(width: size, height: size))
            result.lockFocus()
            img.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                     from: .zero,
                     operation: .copy,
                     fraction: 1.0)
            result.unlockFocus()
            return result
        }
        // Fallback: blue circle with W
        return fallbackImage(size: size)
    }

    static func image(size: CGFloat = 16) -> Image {
        Image(nsImage: nsImage(size: size))
    }

    // MARK: - Fallback

    private static func fallbackImage(size: CGFloat) -> NSImage {
        let wpBlue = NSColor(red: 0.0, green: 0.451, blue: 0.667, alpha: 1.0)
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let circlePath = NSBezierPath(ovalIn: rect)
            wpBlue.setFill()
            circlePath.fill()
            let fontSize = size * 0.58
            let font = NSFont(name: "Georgia-Bold", size: fontSize) ?? NSFont.boldSystemFont(ofSize: fontSize)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.white,
                .paragraphStyle: paragraphStyle
            ]
            let str = NSAttributedString(string: "W", attributes: attrs)
            let strSize = str.size()
            str.draw(at: NSPoint(x: (size - strSize.width) / 2, y: (size - strSize.height) / 2))
            return true
        }
        image.isTemplate = false
        return image
    }
}

/// SwiftUI view — loads SVG via NSImage for crisp rendering at any size.
struct WordPressLogoView: View {
    var size: CGFloat = 28

    var body: some View {
        Image(nsImage: WordPressLogo.nsImage(size: size * 2)) // 2x for retina
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .frame(width: size, height: size)
    }
}
