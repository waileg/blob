import SwiftUI

/// The living face of Blob. Deterministic identity + reactive motion:
/// - idle breathing
/// - puffs up when someone is speaking
/// - eyes react to live audio level
struct BlobatarView: View {
    let name: String

    /// 0...1 live audio level; drives the reactive part.
    var audioLevel: Double = 0
    var isSpeaking: Bool = false
    var size: CGFloat = 160

    private let traits: BlobatarTraits
    private let animation: Animation

    init(name: String, audioLevel: Double = 0, isSpeaking: Bool = false, size: CGFloat = 160) {
        self.name = name
        self.audioLevel = audioLevel
        self.isSpeaking = isSpeaking
        self.size = size
        self.traits = Blobatar.traits(for: name)
        self.animation = .easeOut(duration: 0.18)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { ctx, canvasSize in
                let t = timeline.date.timeIntervalSinceReferenceDate
                render(ctx: ctx, size: canvasSize, t: t)
            }
        }
        .frame(width: size, height: size)
        .animation(animation, value: isSpeaking)
        .animation(animation, value: audioLevel)
    }

    private func render(ctx: GraphicsContext, size: CGSize, t: TimeInterval) {
        // breathing + speaking reactivity, all derived from time t
        let breath = (sin(t * 2.6) + 1) / 2
        let scale = 1.0 + breath * 0.02 + (isSpeaking ? 0.05 + audioLevel * 0.10 : 0)
        let squash = breath * 0.05 + (isSpeaking ? audioLevel * 0.18 : 0)

        let s = min(size.width, size.height)
        var bodyTransform = CGAffineTransform.identity
        bodyTransform = bodyTransform.translatedBy(x: size.width / 2, y: size.height / 2)
        bodyTransform = bodyTransform.scaledBy(x: s * scale, y: s * scale)
        bodyTransform = bodyTransform.translatedBy(x: -0.5, y: -0.5)

        // shadow blob under the body
        let shadowRect = CGRect(x: 0, y: 0, width: s * 0.6, height: s * 0.08)
            .offset(x: (size.width - s * 0.6) / 2, y: size.height * 0.88)
        ctx.fill(Path(ellipseIn: shadowRect), with: .color(.black.opacity(0.10)))

        // body + face, drawn in unit coordinates
        let body = SilhouetteShapes.path(for: traits.silhouette, squash: squash)
        ctx.drawLayer { layer in
            layer.transform = bodyTransform
            let grad = Gradient(colors: [traits.palette.color, traits.palette.accent])
            layer.fill(body, with: .linearGradient(grad, startPoint: .zero, endPoint: CGPoint(x: 0, y: 1)))
            drawFace(layer: layer, t: t)
        }
    }

    private func drawFace(layer: GraphicsContext, t: TimeInterval) {
        let eyeY = 0.40 - Double(traits.eyeStyle) * 0.01
        let eyeDX = 0.11 + Double(traits.eyeStyle) * 0.01
        let blink = sin(t * 0.7 + traits.gazeSeed * 6.28) > 0.985 ? true : false
        let gaze = sin(t * 0.6 + traits.gazeSeed * 6.28) * 0.015

        for side in [-1.0, 1.0] {
            let ex = 0.5 + side * eyeDX + gaze
            let eyeRect = CGRect(x: ex - 0.035, y: eyeY - 0.05 * (blink ? 0.2 : 1), width: 0.07, height: 0.10 * (blink ? 0.2 : 1))
            let eye = Path(ellipseIn: eyeRect)
            switch traits.eyeStyle {
            case 0, 1:
                layer.fill(eye, with: .color(.white))
                let pupil = Path(ellipseIn: eyeRect.insetBy(dx: 0.028, dy: 0.03))
                layer.fill(pupil, with: .color(.black))
            default:
                layer.fill(eye, with: .color(.black.opacity(0.85)))
            }
        }

        // mouth
        let mouthY = eyeY + 0.16
        let curve = traits.mouthCurve * 0.5 + (isSpeaking ? 0.35 + audioLevel * 0.3 : 0)
        var mouth = Path()
        mouth.move(to: CGPoint(x: 0.5 - 0.09, y: mouthY))
        mouth.addQuadCurve(
            to: CGPoint(x: 0.5 + 0.09, y: mouthY),
            control: CGPoint(x: 0.5, y: mouthY + curve * 0.12)
        )
        let mouthStroke = GraphicsContext.Shading.color(.black.opacity(0.75))
        layer.stroke(mouth, with: mouthStroke, style: StrokeStyle(lineWidth: 0.02, lineCap: .round))

        // cheeks
        if traits.hasCheeks {
            for side in [-1.0, 1.0] {
                let c = Path(ellipseIn: CGRect(x: 0.5 + side * 0.20 - 0.025, y: eyeY + 0.06, width: 0.05, height: 0.035))
                layer.fill(c, with: .color(.white.opacity(0.35)))
            }
        }
    }
}

/// Small static avatar for transcript rows (speaker identity).
struct SpeakerAvatarView: View {
    let name: String
    var size: CGFloat = 28

    var body: some View {
        BlobatarView(name: name, size: size)
    }
}
