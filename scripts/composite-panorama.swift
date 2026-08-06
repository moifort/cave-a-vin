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

for third in 0..<3 {
  let xStart = width * third / 3
  let xEnd = width * (third + 1) / 3

  // Bounding box of confidently-magenta pixels in this third.
  var minX = Int.max
  var maxX = Int.min
  var minY = Int.max
  var maxY = Int.min
  for y in 0..<height {
    for x in xStart..<xEnd {
      if magentaWeight(panorama, (y * width + x) * 4) > 0.8 {
        minX = min(minX, x)
        maxX = max(maxX, x)
        minY = min(minY, y)
        maxY = max(maxY, y)
      }
    }
  }
  // Sentinel check must come first: with no magenta at all, computing a width from the
  // Int.max/Int.min sentinels would trap on overflow.
  guard minX <= maxX else {
    fail("No magenta screen found in third \(third + 1) of \(panoramaPath)")
  }
  let screenWidth = maxX - minX + 1
  let screenHeight = maxY - minY + 1
  guard screenWidth > (xEnd - xStart) / 5, screenHeight > height / 5 else {
    fail("No magenta screen found in third \(third + 1) of \(panoramaPath)")
  }

  // A screen that is not screenshot-shaped would silently stretch the UI when filled.
  let screenshotRatio = 1206.0 / 2622.0
  let screenRatio = Double(screenWidth) / Double(screenHeight)
  guard abs(screenRatio - screenshotRatio) / screenshotRatio < 0.05 else {
    fail(
      "Screen in third \(third + 1) has ratio \(screenRatio) but screenshots are \(screenshotRatio); regenerate the panorama")
  }

  let screenshot = loadImage(arguments[2 + third])
  let (scaledContext, scaled) = rgbaBitmap(of: screenshot, width: screenWidth, height: screenHeight)

  // Replace magenta pixels with the scaled screenshot, blending on the soft mask
  // so anti-aliased screen edges keep their bezel transition. The contexts own
  // the pixel buffers, so keep them alive for the whole loop.
  withExtendedLifetime((panoramaContext, scaledContext)) {
    for y in 0..<screenHeight {
      // Both buffers come from identically-configured contexts, so rows line up 1:1.
      for x in 0..<screenWidth {
        let target = ((minY + y) * width + (minX + x)) * 4
        // Scaled up and clamped: a plain weight leaves the partly-magenta pixels
        // of an anti-aliased screen edge half-replaced, which reads as a pink
        // fringe around the screen. Steeper, the edge stays soft and the colour
        // goes.
        let weight = min(1, magentaWeight(panorama, target) * 2.5)
        if weight <= 0 { continue }
        let source = (y * screenWidth + x) * 4
        for channel in 0..<3 {
          let original = Double(panorama[target + channel])
          let replacement = Double(scaled[source + channel])
          panorama[target + channel] = UInt8(max(0, min(255, (original + (replacement - original) * weight).rounded())))
        }
      }
    }
  }

  // The caption goes in the band the panorama leaves free above the phone.
  // `minY` is a row of the pixel buffer, whose first row is the top of the
  // image, while the context draws from a bottom-left origin — hence the flip.
  if !captions[third].isEmpty, minY > height / 12 {
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
}

guard let output = panoramaContext.makeImage(),
  let destination = CGImageDestinationCreateWithURL(
    URL(fileURLWithPath: panoramaPath) as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fail("Cannot encode output image") }
CGImageDestinationAddImage(destination, output, nil)
guard CGImageDestinationFinalize(destination) else { fail("Cannot write \(panoramaPath)") }
