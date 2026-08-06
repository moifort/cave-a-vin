// Composites real app screenshots onto the magenta placeholder screens of a
// generated App Store panorama (see generate-appstore-previews.ts), and draws
// the marketing caption above each phone.
//
// The panorama contains three front-facing phone mockups whose screens are
// solid magenta (#FF00FF). For each horizontal third, this tool finds the
// magenta region, scales the matching screenshot to its bounding box, and
// replaces only the magenta pixels (soft mask), preserving bezels and
// anti-aliased edges. The panorama file is rewritten in place.
//
// The captions are drawn here rather than asked of the image model: the model
// mangles text it renders, and it would have to be trusted with seven languages
// including Japanese. Core Text sets them from the same font the app uses, so a
// German compound word wraps instead of overflowing and kana come out as kana.
//
// Usage: swift composite-panorama.swift <panorama.png> <left.png> <center.png> <right.png>
//                                       [<language> <caption1> <caption2> <caption3> [<subtitle>]]
//
// The optional subtitle is set smaller under every caption, the same sentence on
// the three panels: it says what the app does, while each caption says what its
// panel shows.

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("\(message)\n".utf8))
  exit(1)
}

func loadImage(_ path: String) -> CGImage {
  let url = URL(fileURLWithPath: path)
  guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
  else { fail("Cannot read image: \(path)") }
  return image
}

func rgbaBitmap(of image: CGImage, width: Int, height: Int) -> (CGContext, UnsafeMutablePointer<UInt8>) {
  let bytesPerRow = width * 4
  guard
    let context = CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  else { fail("Cannot create bitmap context") }
  context.interpolationQuality = .high
  context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
  guard let data = context.data else { fail("Bitmap context has no data") }
  return (context, data.assumingMemoryBound(to: UInt8.self))
}

// How strongly a pixel reads as the magenta placeholder, in 0...1.
func magentaWeight(_ pixels: UnsafeMutablePointer<UInt8>, _ offset: Int) -> Double {
  let r = Double(pixels[offset])
  let g = Double(pixels[offset + 1])
  let b = Double(pixels[offset + 2])
  return max(0, min(1, (min(r, b) - g - 60) / 80))
}

/// A piece of text measured at the largest size that fits the given width and
/// height, ready to be drawn wherever the caller decides.
struct FittedText {
  let framesetter: CTFramesetter
  let size: CGSize
  let fontSize: Double
}

/// Measures `text` at the largest size that fits, shrinking rather than
/// clipping: German runs long, Japanese runs short, and a caption that overflows
/// its band is worse than one set a size smaller. The size is expressed against
/// the panel width so the three panels carry the same weight of text, whatever
/// the language does with the wording.
func fitText(
  _ text: String, width: Double, maxHeight: Double, language: String,
  weight: Double = 1, opacity: Double = 1
) -> FittedText? {
  guard !text.isEmpty, maxHeight > 0 else { return nil }
  // Core Text reads the setting through a raw pointer, so the value has to
  // outlive the call that copies it — hence the explicit scope.
  var alignment = CTTextAlignment.center
  let paragraph = withUnsafeBytes(of: &alignment) { buffer -> CTParagraphStyle in
    var setting = CTParagraphStyleSetting(
      spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: buffer.baseAddress!)
    return CTParagraphStyleCreate(&setting, 1)
  }

  for size in stride(from: width * 0.075 * weight, to: width * 0.025 * weight, by: -2) {
    let font = CTFontCreateUIFontForLanguage(.system, size, language as CFString)
      ?? CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
    // The Core Text attribute names, not AppKit's: this tool links neither
    // AppKit nor UIKit, and NSAttributedString.Key.font comes from those.
    let attributed = NSAttributedString(
      string: text,
      attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(
          red: 1, green: 0.98, blue: 0.94, alpha: opacity),
        NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraph,
      ])
    let framesetter = CTFramesetterCreateWithAttributedString(attributed)
    let measured = CTFramesetterSuggestFrameSizeWithConstraints(
      framesetter, CFRange(location: 0, length: 0), nil,
      CGSize(width: width, height: .greatestFiniteMagnitude), nil)
    guard measured.height <= maxHeight, measured.width <= width else { continue }
    return FittedText(framesetter: framesetter, size: measured, fontSize: size)
  }
  return nil
}

/// Draws measured text with its top-left at `origin`, in a box `width` wide.
func draw(_ text: FittedText, x: Double, top: Double, width: Double, context: CGContext) {
  let box = CGRect(x: x, y: top - text.size.height, width: width, height: text.size.height)
  let frame = CTFramesetterCreateFrame(
    text.framesetter, CFRange(location: 0, length: 0), CGPath(rect: box, transform: nil), nil)
  context.saveGState()
  // A soft dark halo: the background is a photograph, and white text over a
  // bright reflection would disappear into it.
  context.setShadow(
    offset: .zero, blur: text.fontSize * 0.35,
    color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.65))
  CTFrameDraw(frame, context)
  context.restoreGState()
}

let arguments = CommandLine.arguments
guard arguments.count == 5 || arguments.count == 9 || arguments.count == 10 else {
  fail(
    "Usage: swift composite-panorama.swift <panorama.png> <left.png> <center.png> <right.png> [<language> <caption1> <caption2> <caption3> [<subtitle>]]"
  )
}
let hasCaptions = arguments.count >= 9
let captionLanguage = hasCaptions ? arguments[5] : ""
let captions = hasCaptions ? Array(arguments[6...8]) : ["", "", ""]
let subtitle = arguments.count == 10 ? arguments[9] : ""
let panoramaPath = arguments[1]
let panoramaImage = loadImage(panoramaPath)
let width = panoramaImage.width
let height = panoramaImage.height
let (panoramaContext, panorama) = rgbaBitmap(of: panoramaImage, width: width, height: height)

// The device is drawn here rather than generated: asked for a phone at a given
// size, the image model produced a different one every time and a different one
// per panel, and the panels are read side by side. Placed by hand, the six of
// them line up to the pixel and the screenshots never stretch.
let panelWidth = Double(width) / 3
let deviceHeight = Double(height) * 0.82
let screenshotRatio = 1206.0 / 2622.0
let screenHeight = deviceHeight
let screenWidth = screenHeight * screenshotRatio
let bezel = screenWidth * 0.022
let cornerRadius = screenWidth * 0.09
// Top edge at 16% of the height, so the caption band above it is the same on
// every panel.
let deviceTop = Double(height) * 0.16

for third in 0..<3 {
  let centerX = panelWidth * (Double(third) + 0.5)
  // Core Graphics counts y from the bottom; the framing above is expressed from
  // the top, as the panel is read.
  let screenRect = CGRect(
    x: centerX - screenWidth / 2,
    y: Double(height) - deviceTop - screenHeight,
    width: screenWidth,
    height: screenHeight)
  let bodyRect = screenRect.insetBy(dx: -bezel, dy: -bezel)

  panoramaContext.saveGState()
  // The body: a dark frame with a soft drop shadow, so the device sits in the
  // room instead of floating on top of it.
  panoramaContext.setShadow(
    offset: CGSize(width: 0, height: -bezel * 1.5), blur: bezel * 4,
    color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.55))
  panoramaContext.setFillColor(CGColor(red: 0.09, green: 0.09, blue: 0.1, alpha: 1))
  panoramaContext.addPath(
    CGPath(
      roundedRect: bodyRect, cornerWidth: cornerRadius + bezel, cornerHeight: cornerRadius + bezel,
      transform: nil))
  panoramaContext.fillPath()
  panoramaContext.restoreGState()

  // The screenshot, clipped to the screen's rounded corners.
  panoramaContext.saveGState()
  panoramaContext.addPath(
    CGPath(
      roundedRect: screenRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius,
      transform: nil))
  panoramaContext.clip()
  panoramaContext.draw(loadImage(arguments[2 + third]), in: screenRect)
  panoramaContext.restoreGState()

  guard !captions[third].isEmpty else { continue }

  let minY = Int(deviceTop)
  let xStart = Int(panelWidth * Double(third))
  let xEnd = Int(panelWidth * Double(third + 1))

    // A dark scrim over the text area, drawn here rather than asked of the image
    // model: told to keep an area calm, it produced a blurred band with a hard
    // edge across the picture. A gradient we draw ourselves is even, predictable
    // and stops exactly where we say.
    let scrimHeight = Double(minY) * 1.15
    if let gradient = CGGradient(
      colorsSpace: CGColorSpaceCreateDeviceRGB(),
      colors: [
        CGColor(red: 0.05, green: 0.01, blue: 0.03, alpha: 0.72),
        CGColor(red: 0.05, green: 0.01, blue: 0.03, alpha: 0),
      ] as CFArray,
      locations: [0, 1])
    {
      panoramaContext.saveGState()
      panoramaContext.clip(
        to: CGRect(
          x: Double(xStart), y: Double(height) - scrimHeight,
          width: Double(xEnd - xStart), height: scrimHeight))
      panoramaContext.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: Double(height)),
        end: CGPoint(x: 0, y: Double(height) - scrimHeight),
        options: [])
      panoramaContext.restoreGState()
    }

    let margin = Double(height) * 0.02
    let inset = Double(xEnd - xStart) * 0.08
    let band = CGRect(
      x: Double(xStart) + inset,
      y: Double(height - minY) + margin,
      width: Double(xEnd - xStart) - inset * 2,
      height: Double(minY) - margin * 2)

    // The title, and under it the sentence saying what the app does — measured
    // first, then drawn as one block centered in the band, so the two read as a
    // pair rather than as two things that happen to share an area.
    let titleHeight = subtitle.isEmpty ? band.height : band.height * 0.6
    guard
      let title = fitText(
        captions[third], width: band.width, maxHeight: titleHeight,
        language: captionLanguage, weight: subtitle.isEmpty ? 1 : 1.15)
    else { continue }
    let sentence = fitText(
      subtitle, width: band.width * 0.95, maxHeight: band.height * 0.25,
      language: captionLanguage, weight: 0.55, opacity: 0.85)

    let gap = title.fontSize * 0.55
    let blockHeight = title.size.height + (sentence.map { gap + $0.size.height } ?? 0)
    var cursor = band.midY + blockHeight / 2
    draw(title, x: band.minX, top: cursor, width: band.width, context: panoramaContext)
    cursor -= title.size.height + gap
    if let sentence {
      draw(
        sentence, x: band.minX + band.width * 0.025, top: cursor, width: band.width * 0.95,
        context: panoramaContext)
    }
}

guard let output = panoramaContext.makeImage(),
  let destination = CGImageDestinationCreateWithURL(
    URL(fileURLWithPath: panoramaPath) as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fail("Cannot encode output image") }
CGImageDestinationAddImage(destination, output, nil)
guard CGImageDestinationFinalize(destination) else { fail("Cannot write \(panoramaPath)") }
