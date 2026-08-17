import SwiftUI
import CoreLocation
import MapboxMaps // Вы импортировали Mapbox, но этот экран использует Apple Maps (MapKit)
import UIKit
import MapKit

enum RouteEditorMode {
    case create
    case edit(routeID: String)
}

struct MapView: View {
    var mode: RouteEditorMode = .create
    
    @State private var title: String = ""
    @State private var tags: [String] = []
    @State private var newTagText: String = ""
    @State private var thumbnailImage: UIImage?
    @State private var thumbnailURL: URL?
    @State private var stops: [Stop] = []
    @State private var showSearch = false
    @State private var isSaving = false
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var imagePickerDelegate: ImagePickerDelegateWrapper?  // Added strong delegate reference

    // ИСПРАВЛЕНИЕ: Используем MapCameraPosition вместо MKCoordinateRegion для iOS 17+
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )

    var body: some View {
        VStack {
            TextField("Title", text: $title)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)

            // Tags editor
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Add tag", text: $newTagText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Add") {
                        let t = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty, !tags.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) else { return }
                        tags.append(t)
                        newTagText = ""
                    }
                    .buttonStyle(.borderedProminent)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 6) {
                                Text(tag)
                                    .font(.caption)
                                Button(action: { tags.removeAll { $0 == tag } }) {
                                    Image(systemName: "xmark.circle.fill").font(.caption)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)

            // Thumbnail picker
            HStack(spacing: 12) {
                if let img = thumbnailImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                        .frame(width: 80, height: 80)
                        .overlay(Image(systemName: "photo").foregroundColor(.secondary))
                }
                VStack(alignment: .leading) {
                    Button("Choose Thumbnail") { presentImagePicker() }
                    if isUploading { ProgressView("Uploading…") }
                    if let url = thumbnailURL {
                        Text(url.lastPathComponent).font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)

            // ИСПРАВЛЕНИЕ: Map iOS 17
            Map(position: $position) {
                // Сюда можно добавлять маркеры (Annotation)
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .safeAreaInset(edge: .bottom) {
                // Кнопка сохранения поверх карты (опционально)
                Button {
                    Task { await saveRoute() }
                } label: {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Save Route")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding()
                .disabled(isSaving || title.isEmpty)
            }
        }
        .alert(item: Binding(get: { errorMessage.map { ErrorWrapper(error: $0) } }, set: { _ in errorMessage = nil })) { wrapper in
             Alert(title: Text("Error"), message: Text(wrapper.error), dismissButton: .default(Text("OK")))
         }
    }

    private func presentImagePicker() {
        // Simple UIKit picker bridge
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        let delegate = ImagePickerDelegateWrapper { image in
            if let image = image, let data = image.jpegData(compressionQuality: 0.85) {
                self.thumbnailImage = image
                Task { await uploadThumbnail(data: data) }
            }
        }
        self.imagePickerDelegate = delegate
        picker.delegate = delegate
        UIApplication.shared.topMostViewController()?.present(picker, animated: true)
    }

    private func uploadThumbnail(data: Data) async {
        await MainActor.run { isUploading = true }
        do {
            let url = try await StorageService.shared.uploadRouteThumbnail(data)
            await MainActor.run {
                self.thumbnailURL = url
                self.isUploading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isUploading = false
            }
        }
    }

    private func saveRoute() async {
        isSaving = true
        defer { isSaving = false }

        let currentTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentStops = stops

        do {
            switch mode {
            case .create:
                _ = try await RouteEditorService().createRoute(
                    title: currentTitle,
                    tags: tags,
                    thumbnailURL: thumbnailURL,
                    stops: currentStops
                )
            case .edit(let routeID):
                try await RouteEditorService().updateRoute(
                    routeID: routeID,
                    title: currentTitle,
                    stops: currentStops,
                    tags: tags,
                    thumbnailURL: thumbnailURL
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// Вспомогательная структура для Alert
struct ErrorWrapper: Identifiable {
    let id = UUID()
    let error: String
}

// MARK: - Helpers

private final class ImagePickerDelegateWrapper: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let onImage: (UIImage?) -> Void
    init(onImage: @escaping (UIImage?) -> Void) { self.onImage = onImage }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let img = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        onImage(img)
        picker.dismiss(animated: true)
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        onImage(nil)
        picker.dismiss(animated: true)
    }
}

private extension UIApplication {
    func topMostViewController(base: UIViewController? = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController { return topMostViewController(base: nav.visibleViewController) }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController { return topMostViewController(base: selected) }
        if let presented = base?.presentedViewController { return topMostViewController(base: presented) }
        return base
    }
}
