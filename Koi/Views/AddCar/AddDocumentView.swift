import SwiftUI
import PhotosUI
import PDFKit
import UniformTypeIdentifiers
import UIKit

/// Add a document to a car's vault. One tappable area offers both sources — your photo library
/// (camera roll) or Files (a PDF or image). A document holds one file.
struct AddDocumentView: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss
    let car: Car

    @State private var kind: DocumentKind = .registration
    @State private var title = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var pdfData: Data?
    @State private var fileName: String?
    @State private var pdfPreview: UIImage?      // page-1 thumbnail of a chosen PDF
    @State private var showSourceDialog = false
    @State private var showPhotos = false
    @State private var showFiles = false

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }
    private var hasAttachment: Bool { imageData != nil || pdfData != nil }

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "New document")
            ScrollView {
                VStack(spacing: 16) {
                    attachmentButton
                    kindPicker
                    KoiField(label: "Title", placeholder: titlePlaceholder, text: $title)
                }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 18)
                .padding(.bottom, 12)
            }
            KoiPrimaryButton(title: "Save document", enabled: canSave) { save() }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 10)
                .padding(.bottom, 12)
        }
        .background(KoiColors.surface.ignoresSafeArea())
        .confirmationDialog("Add a file", isPresented: $showSourceDialog, titleVisibility: .visible) {
            Button("Photo library") { showPhotos = true }
            Button("Choose a file (PDF or image)") { showFiles = true }
            if hasAttachment { Button("Remove attachment", role: .destructive) { clearAttachment() } }
            Button("Cancel", role: .cancel) { }
        }
        .photosPicker(isPresented: $showPhotos, selection: $photoItem, matching: .images)
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf, .image]) { result in
            handlePickedFile(result)
        }
        .onChange(of: photoItem) {
            Task {
                guard let raw = try? await photoItem?.loadTransferable(type: Data.self) else { return }
                // documents keep a touch more detail than a card thumbnail, for legible text
                let prepared = await Task.detached { UIImage(data: raw)?.preparedForStorage(maxDimension: 1600) ?? raw }.value
                await MainActor.run {
                    imageData = prepared
                    pdfData = nil; fileName = nil; pdfPreview = nil   // one file per document
                }
            }
        }
    }

    // MARK: attachment
    private var attachmentButton: some View {
        Button { showSourceDialog = true } label: {
            ZStack {
                if let d = imageData, let ui = UIImage(data: d) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else if let thumb = pdfPreview {
                    Image(uiImage: thumb).resizable().scaledToFit().padding(14)
                } else {
                    KoiColors.insetFill
                    VStack(spacing: 8) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(KoiColors.textSubdued)
                        Text("Add a photo, scan, or PDF")
                            .koiStyle(.body).foregroundStyle(KoiColors.textSecondary)
                        Text("From your photos or Files")
                            .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: KoiRadius.cardSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KoiRadius.cardSmall, style: .continuous)
                    .strokeBorder(KoiColors.border,
                                  style: StrokeStyle(lineWidth: 1, dash: hasAttachment ? [] : [5, 4]))
            )
            .overlay(alignment: .bottomLeading) { if pdfData != nil { pdfBadge } }
            .overlay(alignment: .topTrailing) { if hasAttachment { changeBadge } }
            .contentShape(RoundedRectangle(cornerRadius: KoiRadius.cardSmall, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var pdfBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "doc.richtext").font(.system(size: 11, weight: .semibold))
            Text(fileName ?? "PDF").koiStyle(.meta).lineLimit(1)
        }
        .foregroundStyle(KoiColors.textSecondary)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(KoiColors.container, in: Capsule())
        .overlay(Capsule().strokeBorder(KoiColors.ring, lineWidth: 1))
        .padding(10)
    }

    private var changeBadge: some View {
        Text("Change")
            .koiStyle(.meta).foregroundStyle(KoiColors.textSecondary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(KoiColors.container, in: Capsule())
            .overlay(Capsule().strokeBorder(KoiColors.ring, lineWidth: 1))
            .padding(10)
    }

    private func clearAttachment() {
        imageData = nil; pdfData = nil; fileName = nil; pdfPreview = nil; photoItem = nil
    }

    /// Read a Files-picked PDF or image. The security-scoped read is what makes this reliable —
    /// without `startAccessingSecurityScopedResource` the read fails silently (the earlier bug).
    private func handlePickedFile(_ result: Result<URL, any Error>) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        if looksLikePDF(data) {
            pdfData = data
            fileName = url.lastPathComponent
            pdfPreview = Self.pdfThumbnail(data)
            imageData = nil
        } else if let ui = UIImage(data: data) {
            imageData = ui.preparedForStorage(maxDimension: 1600)
            pdfData = nil; fileName = nil; pdfPreview = nil
        }
    }

    private func looksLikePDF(_ data: Data) -> Bool { data.prefix(5).elementsEqual(Array("%PDF-".utf8)) }

    private var titlePlaceholder: String {
        switch kind {
        case .registration: return "Registration"
        case .inspection:   return "Inspection certificate"
        case .insurance:    return "Insurance policy"
        case .other:        return "Document"
        }
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Type").koiStyle(.eyebrow).foregroundStyle(KoiColors.textSubdued)
            Menu {
                Picker("Type", selection: $kind) {
                    ForEach(DocumentKind.allCases, id: \.self) { Text($0.label).tag($0) }
                }
            } label: {
                HStack {
                    Text(kind.label).koiStyle(.body).foregroundStyle(KoiColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 12)).foregroundStyle(KoiColors.textSubdued)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(KoiColors.fieldFill, in: RoundedRectangle(cornerRadius: KoiRadius.field, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: KoiRadius.field, style: .continuous).strokeBorder(KoiColors.border, lineWidth: 1))
            }
        }
    }

    private func save() {
        garage.addDocument(Document(carID: car.id, kind: kind,
                                    title: title.trimmingCharacters(in: .whitespaces),
                                    subtitle: pdfData != nil ? fileName : nil,
                                    imageData: imageData, pdfData: pdfData, fileName: fileName))
        Haptics.success()
        dismiss()
    }

    /// Page-1 thumbnail of a PDF, for the picker slot.
    static func pdfThumbnail(_ data: Data) -> UIImage? {
        guard let doc = PDFDocument(data: data), let page = doc.page(at: 0) else { return nil }
        return page.thumbnail(of: CGSize(width: 700, height: 900), for: .mediaBox)
    }
}

/// Full look at a stored document — a PDF (scrollable, zoomable) or an image.
struct DocumentPreviewView: View {
    let document: Document

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: document.title)
            if let pdf = document.pdfData {
                PDFKitView(data: pdf).ignoresSafeArea(edges: .bottom)
            } else if let data = document.imageData, let ui = UIImage(data: data) {
                ScrollView {
                    Image(uiImage: ui).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: KoiRadius.cardSmall, style: .continuous))
                        .padding(KoiSpace.gutter)
                }
            } else {
                Spacer()
                EmptyHint(icon: "doc", text: "No file attached to this document.")
                    .padding(.horizontal, KoiSpace.gutter)
                Spacer()
            }
        }
        .background(KoiColors.surface.ignoresSafeArea())
    }
}

/// PDFKit page viewer (scroll + pinch-zoom) for a PDF held in memory.
struct PDFKitView: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.backgroundColor = .clear
        view.document = PDFDocument(data: data)
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {
        if view.document == nil { view.document = PDFDocument(data: data) }
    }
}

#Preview { AddDocumentView(car: Garage.preview.residents.first!).environmentObject(Garage.preview) }
