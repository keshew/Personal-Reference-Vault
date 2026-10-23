import SwiftUI
import PhotosUI
import UIKit
import AVFoundation

struct PhotoFocus: Identifiable { var id: UUID }

struct PhotosEditView: View {
    @Binding var photos: [PhotoAttachment]
    @State private var selection: [PhotosPickerItem] = []
    @State private var loading = false
    @State private var camera = false
    @State private var caption: PhotoAttachment?
    @State private var viewing: PhotoFocus?
    @State private var deleting: UUID?
    @State private var confirmDelete = false
    @State private var error: String?
    var body: some View {
        List {
            if photos.isEmpty { VaultEmptyState(icon: "photo", title: "Supporting Photos", message: "Add a label, product photo or measurement sketch. Photos stay in your local library.").listRowBackground(Color.clear) }
            Section {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    HStack(spacing: 13) {
                        Button { viewing = PhotoFocus(id: photo.id) } label: {
                            if let image = UIImage(data: photo.imageData) { Image(uiImage: image).resizable().scaledToFill().frame(width: 65, height: 65).clipShape(RoundedRectangle(cornerRadius: 10)) }
                        }.buttonStyle(.plain).accessibilityLabel("View photo \(index + 1)")
                        VStack(alignment: .leading, spacing: 5) {
                            Text(index == 0 ? "Cover Photo" : "Photo \(index + 1)").font(.subheadline.weight(.medium))
                            Text(photo.caption.isEmpty ? "No caption" : photo.caption).font(.caption).foregroundStyle(VaultStyle.secondary).lineLimit(3)
                        }; Spacer()
                        Menu {
                            Button("Edit Caption", systemImage: "text.bubble") { caption = photo }
                            if index != 0 { Button("Set Cover Photo", systemImage: "photo") { var reordered = photos; reordered.remove(at: index); reordered.insert(photo, at: 0); photos = reordered } }
                            Button("Delete Photo", systemImage: "trash", role: .destructive) { deleting = photo.id; confirmDelete = true }
                        } label: { Image(systemName: "ellipsis.circle").padding(7) }.accessibilityLabel("Photo options")
                    }.padding(.vertical, 6)
                }.onMove { source, target in photos.move(fromOffsets: source, toOffset: target) }
            } footer: { if !photos.isEmpty { Text("The first photo is the cover. Tap Edit to reorder photos.") } }
            Section {
                PhotosPicker(selection: $selection, maxSelectionCount: 10, matching: .images, photoLibrary: .shared()) { Label("Add from Photo Library", systemImage: "photo.badge.plus") }.disabled(loading)
                if UIImagePickerController.isSourceTypeAvailable(.camera) { Button { openCamera() } label: { Label("Take Photo", systemImage: "camera") }.disabled(loading) }
                if loading { HStack { ProgressView(); Text("Preparing photos…").font(.subheadline).foregroundStyle(VaultStyle.secondary) } }
            }
        }.vaultBackground().navigationTitle("Photos").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { EditButton().disabled(photos.count < 2) } }
            .task(id: selection) {
                guard !selection.isEmpty else { return }
                loading = true
                defer { loading = false; selection = [] }
                for selected in selection {
                    do {
                        guard let bytes = try await selected.loadTransferable(type: Data.self), let image = UIImage(data: bytes), let jpeg = Self.prepare(image) else { throw VaultError.invalid("This image could not be opened.") }
                        guard !Task.isCancelled else { return }
                        photos.append(PhotoAttachment(imageData: jpeg))
                    } catch {
                        guard !Task.isCancelled else { return }
                        self.error = "A photo could not be added. \(error.localizedDescription)"
                    }
                }
            }
            .sheet(isPresented: $camera) { CameraPicker { image in
                if let bytes = Self.prepare(image) { photos.append(PhotoAttachment(imageData: bytes)) }
                else { error = "The photo could not be prepared." }
            } }
            .sheet(item: $caption) { photo in PhotoCaptionView(photo: photo) { text in if let i = photos.firstIndex(where: { $0.id == photo.id }) { photos[i].caption = text } } }
            .fullScreenCover(item: $viewing) { focus in PhotoViewer(photos: photos, selectedID: focus.id) }
            .confirmationDialog("Delete this photo?", isPresented: $confirmDelete, titleVisibility: .visible) { Button("Delete Photo", role: .destructive) { photos.removeAll { $0.id == deleting } } }
            .alert("Photo notice", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private func openCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: camera = true
        case .notDetermined:
            Task {
                if await AVCaptureDevice.requestAccess(for: .video) { camera = true }
                else { error = "Camera access is off. You can enable it for Reference Vault in iOS Settings, or choose a photo from your library." }
            }
        default: error = "Camera access is off. You can enable it for Reference Vault in iOS Settings, or choose a photo from your library."
        }
    }

    static func prepare(_ image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let factor = min(1, 1800 / longest)
        let size = CGSize(width: max(1, image.size.width * factor), height: max(1, image.size.height * factor))
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let normalized = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size)); image.draw(in: CGRect(origin: .zero, size: size))
        }
        return normalized.jpegData(compressionQuality: 0.82)
    }
}

struct PhotoCaptionView: View {
    @Environment(\.dismiss) private var dismiss
    let photo: PhotoAttachment
    let save: (String) -> Void
    @State private var text: String
    init(photo: PhotoAttachment, save: @escaping (String) -> Void) { self.photo = photo; self.save = save; _text = State(initialValue: photo.caption) }
    var body: some View {
        NavigationStack {
            Form {
                if let image = UIImage(data: photo.imageData) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 250).frame(maxWidth: .infinity) }
                TextField("Photo caption", text: $text, axis: .vertical).lineLimit(3...8)
            }.vaultBackground().navigationTitle("Photo Caption").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { save(text); dismiss() } }
                }
        }
    }
}

struct PhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    let photos: [PhotoAttachment]
    @State var selectedID: UUID
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $selectedID) {
                ForEach(photos) { photo in
                    VStack(spacing: 16) {
                        ZoomablePhoto(data: photo.imageData)
                        if !photo.caption.isEmpty { ScrollView { Text(photo.caption).font(.subheadline).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24) }.frame(maxHeight: 100) }
                    }.padding(.top, 55).padding(.bottom, 45).tag(photo.id)
                }
            }.tabViewStyle(.page(indexDisplayMode: .automatic))
            Button { dismiss() } label: { Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(.white).padding(13).background(.white.opacity(0.15), in: Circle()) }.padding(18).accessibilityLabel("Close photo")
        }.preferredColorScheme(.dark)
    }
}

struct ZoomablePhoto: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PhotoScrollView { let view = PhotoScrollView(); view.imageView.image = UIImage(data: data); return view }
    func updateUIView(_ view: PhotoScrollView, context: Context) {}
}

final class PhotoScrollView: UIScrollView, UIScrollViewDelegate {
    let imageView = UIImageView()
    private var lastSize = CGSize.zero
    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self; minimumZoomScale = 1; maximumZoomScale = 5
        showsVerticalScrollIndicator = false; showsHorizontalScrollIndicator = false
        imageView.contentMode = .scaleAspectFit; addSubview(imageView)
        let tap = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:))); tap.numberOfTapsRequired = 2; addGestureRecognizer(tap)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != lastSize { lastSize = bounds.size; zoomScale = 1; imageView.frame = CGRect(origin: .zero, size: bounds.size); contentSize = bounds.size }
    }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    @objc private func doubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScale > 1 { setZoomScale(1, animated: true) }
        else { let point = gesture.location(in: imageView); let size = CGSize(width: bounds.width / 2.5, height: bounds.height / 2.5); zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height), animated: true) }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let receive: (UIImage) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> UIImagePickerController { let controller = UIImagePickerController(); controller.sourceType = .camera; controller.delegate = context.coordinator; return controller }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) { if let image = info[.originalImage] as? UIImage { parent.receive(image) }; parent.dismiss() }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
