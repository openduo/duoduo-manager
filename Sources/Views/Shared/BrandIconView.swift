import SwiftUI
import AppKit

struct BrandIconView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        imageView.image = drawBrandIcon(size: NSSize(width: 120, height: 120))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private func drawBrandIcon(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext else { return image }
        let s = size.width / 120

        let darkColor = CGColor(srgbRed: 24/255, green: 24/255, blue: 27/255, alpha: 1)
        let muzzleColor = CGColor(srgbRed: 39/255, green: 39/255, blue: 42/255, alpha: 1)
        let whiteColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        let blackColor = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        let noseHighlight = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.6)
        let tongueColor = CGColor(srgbRed: 244/255, green: 114/255, blue: 182/255, alpha: 1)

        // Head
        ctx.setFillColor(darkColor)
        ctx.fillEllipse(in: CGRect(x: 30*s, y: 0, width: 60*s, height: 56*s))

        // Ears
        let leftEar = CGRect(x: 8*s, y: 20*s, width: 28*s, height: 50*s)
        let rightEar = CGRect(x: 84*s, y: 20*s, width: 28*s, height: 50*s)
        ctx.fillEllipse(in: leftEar)
        ctx.fillEllipse(in: rightEar)

        // Paws
        let leftPaw = CGRect(x: 22*s, y: 36*s, width: 30*s, height: 30*s)
        let rightPaw = CGRect(x: 68*s, y: 36*s, width: 30*s, height: 30*s)
        ctx.fillEllipse(in: leftPaw)
        ctx.fillEllipse(in: rightPaw)

        // Muzzle
        ctx.setFillColor(muzzleColor)
        ctx.fillEllipse(in: CGRect(x: 40*s, y: 30*s, width: 40*s, height: 30*s))

        // Eyes
        ctx.setFillColor(whiteColor)
        ctx.fillEllipse(in: CGRect(x: 36*s, y: 8*s, width: 10*s, height: 13*s))
        ctx.fillEllipse(in: CGRect(x: 64*s, y: 8*s, width: 10*s, height: 13*s))

        // Pupils
        ctx.setFillColor(blackColor)
        ctx.fillEllipse(in: CGRect(x: 38*s, y: 9*s, width: 7*s, height: 10*s))
        ctx.fillEllipse(in: CGRect(x: 66*s, y: 9*s, width: 7*s, height: 10*s))

        // Eye highlights
        ctx.setFillColor(whiteColor)
        ctx.fillEllipse(in: CGRect(x: 40*s, y: 9*s, width: 3*s, height: 3*s))
        ctx.fillEllipse(in: CGRect(x: 68*s, y: 9*s, width: 3*s, height: 3*s))

        // Nose
        ctx.setFillColor(blackColor)
        ctx.fillEllipse(in: CGRect(x: 55*s, y: 26*s, width: 10*s, height: 7*s))
        ctx.setFillColor(noseHighlight)
        ctx.fillEllipse(in: CGRect(x: 57.5*s, y: 25*s, width: 4*s, height: 2*s))

        // Tongue
        ctx.setFillColor(tongueColor)
        let tongue = CGMutablePath()
        tongue.move(to: CGPoint(x: 55*s, y: 42*s))
        tongue.addQuadCurve(to: CGPoint(x: 60*s, y: 52*s), control: CGPoint(x: 50*s, y: 48*s))
        tongue.addQuadCurve(to: CGPoint(x: 65*s, y: 42*s), control: CGPoint(x: 70*s, y: 48*s))
        tongue.closeSubpath()
        ctx.addPath(tongue)
        ctx.fillPath()

        image.unlockFocus()
        return image
    }
}
