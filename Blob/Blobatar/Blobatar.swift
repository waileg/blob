import SwiftUI

// MARK: - Deterministic traits

/// Same string -> same traits, always. Inspired by blobatar.dev's concept.
struct BlobatarTraits: Equatable {
    enum Silhouette: Int, CaseIterable, Identifiable {
        case blob = 0, droplet, bean, egg, pill, squish, cloud, star, hex, heart
        var id: Int { rawValue }

        var name: String {
            switch self {
            case .blob: return "blob"
            case .droplet: return "droplet"
            case .bean: return "bean"
            case .egg: return "egg"
            case .pill: return "pill"
            case .squish: return "squish"
            case .cloud: return "cloud"
            case .star: return "star"
            case .hex: return "hex"
            case .heart: return "heart"
            }
        }
    }

    struct Palette {
        let hue: Double
        let accentHue: Double
        var color: Color { Color(hue: hue, saturation: 0.72, brightness: 0.92) }
        var accent: Color { Color(hue: accentHue, saturation: 0.78, brightness: 0.98) }
    }

    let silhouette: Silhouette
    let palette: Palette
    /// eye style 0-3
    let eyeStyle: Int
    /// mouth curve -1.0...1.0
    let mouthCurve: Double
    /// cheek 0/1
    let hasCheeks: Bool
    /// gaze direction seed
    let gazeSeed: Double
}

// MARK: - Hash

/// Deterministic 32-bit FNV-1a. Same input, same stream, on every platform.
enum BlobatarHash {
    static func digest(_ name: String) -> [UInt32] {
        var h: UInt32 = 0x811c9dc5
        let scalars = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased().unicodeScalars
        for s in scalars {
            h = (h ^ UInt32(s.value)) &* 16777619
        }
        // derive a small deterministic stream from the final state
        var stream: [UInt32] = []
        var x = h == 0 ? 0x9e3779b9 : h
        for _ in 0..<8 {
            x ^= x << 13; x ^= x >> 17; x ^= x << 5
            stream.append(x)
        }
        return stream
    }

    static func unit(_ v: UInt32) -> Double {
        Double(v % 10000) / 10000.0
    }
}

// MARK: - Generator

enum Blobatar {
    /// Fix stream order and derivation so traits never change across versions.
    static func traits(for name: String) -> BlobatarTraits {
        let s = BlobatarHash.digest(name)
        let silhouette = BlobatarTraits.Silhouette(rawValue: Int(s[0] % 10)) ?? .blob
        let hue = Double(BlobatarHash.unit(s[1]))
        let accent = (hue + 0.5 + Double(BlobatarHash.unit(s[2]) * 0.15)).truncatingRemainder(dividingBy: 1.0)
        let eyeStyle = Int(s[3] % 4)
        let mouthCurve = Double(BlobatarHash.unit(s[4])) * 2.0 - 1.0
        let hasCheeks = s[5] % 2 == 0
        let gazeSeed = Double(BlobatarHash.unit(s[6]))
        return BlobatarTraits(
            silhouette: silhouette,
            palette: .init(hue: hue, accentHue: accent),
            eyeStyle: eyeStyle,
            mouthCurve: mouthCurve,
            hasCheeks: hasCheeks,
            gazeSeed: gazeSeed
        )
    }
}