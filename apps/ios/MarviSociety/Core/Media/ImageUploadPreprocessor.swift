import ImageIO
import UIKit

/// Instagram / LinkedIn-style upload prep: decode any size, resize, JPEG compress.
enum ImageUploadProfile: Sendable {
    case avatar
    case cover
    case showcase
    case proof

    var maxPixelDimension: CGFloat {
        switch self {
        case .avatar: 1024
        case .cover: 1920
        case .showcase: 1600
        case .proof: 2048
        }
    }

    var jpegQuality: CGFloat {
        switch self {
        case .avatar: 0.82
        case .cover: 0.80
        case .showcase: 0.80
        case .proof: 0.78
        }
    }

    var maxBytes: Int {
        switch self {
        case .avatar: 900_000
        case .cover: 1_800_000
        case .showcase: 1_500_000
        case .proof: 2_000_000
        }
    }
}

enum ImageUploadPreprocessor {
    /// Hard ceiling for Supabase `profile-media` bucket (5 MB); stay well below.
    private static let storageCeilingBytes = 4_500_000

    static func prepare(_ data: Data, profile: ImageUploadProfile) -> Data? {
        guard let image = decodeImage(from: data) else { return nil }

        var maxDimension = profile.maxPixelDimension
        let byteLimit = min(profile.maxBytes, storageCeilingBytes)

        while maxDimension >= 480 {
            let rendered = render(image, maxDimension: maxDimension)
            if let compressed = compress(rendered, maxBytes: byteLimit, startingQuality: profile.jpegQuality) {
                return compressed
            }
            maxDimension *= 0.75
        }
        return nil
    }

    private static func decodeImage(from data: Data) -> UIImage? {
        if let image = UIImage(data: data) { return image }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private static func pixelSize(of image: UIImage) -> CGSize {
        if let cgImage = image.cgImage {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }
        return CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )
    }

    private static func render(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        var target = pixelSize(of: image)
        let longest = max(target.width, target.height)
        if longest > maxDimension, longest > 0 {
            let scale = maxDimension / longest
            target = CGSize(width: target.width * scale, height: target.height * scale)
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    private static func compress(
        _ image: UIImage,
        maxBytes: Int,
        startingQuality: CGFloat
    ) -> Data? {
        var quality = startingQuality
        guard var data = image.jpegData(compressionQuality: quality) else { return nil }

        while data.count > maxBytes, quality > 0.35 {
            quality -= 0.07
            guard let next = image.jpegData(compressionQuality: quality) else { break }
            data = next
        }
        return data.count <= maxBytes ? data : nil
    }
}
