import SwiftUI
import UIKit

/// The system camera, as a SwiftUI sheet.
///
/// SwiftUI has a picker for the photo library (`PhotosPicker`, which needs no
/// permission because it runs out of process) but nothing for the camera, so
/// this wraps `UIImagePickerController`. AVFoundation would mean building a
/// capture session, a preview layer and a shutter button to arrive at the same
/// place, with more to get wrong.
///
/// Requires `NSCameraUsageDescription`. Without it the app is killed on
/// presentation rather than shown an error.
struct CameraPicker: UIViewControllerRepresentable {
    /// JPEG data for the captured photo, already downscaled.
    var onCapture: (Data) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraCaptureMode = .photo
        controller.allowsEditing = true
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: { dismiss() })
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onCapture: (Data) -> Void
        private let dismiss: () -> Void

        init(onCapture: @escaping (Data) -> Void, dismiss: @escaping () -> Void) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            // A 12-megapixel capture is roughly 4 MB of JPEG for a thumbnail that
            // is never shown larger than a phone screen. Downscaling here rather
            // than at the upload keeps the memory spike off the main thread's
            // conscience too.
            if let data = image?.jpegForUpload() {
                onCapture(data)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

// MARK: - Downscaling

extension UIImage {
    /// JPEG at a sensible size for a cover image: the long edge capped, quality
    /// at the point where the next percent costs more bytes than it returns.
    func jpegForUpload(maxEdge: CGFloat = 1600, quality: CGFloat = 0.8) -> Data? {
        let longest = max(size.width, size.height)
        guard longest > maxEdge else { return jpegData(compressionQuality: quality) }

        let scale = maxEdge / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}

// MARK: - Availability

enum Camera {
    /// False on the Simulator, and on the rare device with no camera. The menu
    /// hides the option rather than offering one that opens a black screen.
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}
