import SwiftUI
import SwiftData
import PhotosUI
import PDFKit
import UniformTypeIdentifiers

@Observable
final class CheckupViewModel {

    // MARK: - Dependencies

    private let tagService: AITagServiceProtocol
    private let checklistService: ChecklistGenerationService

    init(
        tagService: AITagServiceProtocol = LLMTagService(),
        checklistService: ChecklistGenerationService = ChecklistGenerationService()
    ) {
        self.tagService = tagService
        self.checklistService = checklistService
    }

    // MARK: - State

    var notes: String = ""
    var uploadedImages: [UIImage] = []
    var pdfPageCount: Int = 0

    var selectedPhotoItems: [PhotosPickerItem] = [] {
        didSet { loadSelectedImages(from: selectedPhotoItems) }
    }

    // MARK: - UI State

    var showCamera = false
    var showFilePicker = false
    var showAIDisclaimer = false
    var isAnalyzing = false
    var isSaving = false
    var aiAnalysis: String?
    var aiTags: [String]?

    var hasContent: Bool { !uploadedImages.isEmpty }

    // MARK: - Actions

    func removeImage(at index: Int) {
        guard index < uploadedImages.count else { return }
        withAnimation { uploadedImages.remove(at: index) }
    }

    func handleFileImport(result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        if url.pathExtension.lowercased() == "pdf" {
            guard let pdfDoc = PDFDocument(url: url) else { return }
            pdfPageCount = pdfDoc.pageCount
            var images: [UIImage] = []
            for i in 0..<min(pdfDoc.pageCount, 5) {
                guard let page = pdfDoc.page(at: i) else { continue }
                let thumbnail = page.thumbnail(of: CGSize(width: 900, height: 1200), for: .mediaBox)
                images.append(thumbnail)
            }
            uploadedImages.append(contentsOf: images)
        } else {
            if let data = try? Data(contentsOf: url), let image = ImageDownsampler.downsampled(from: data) {
                uploadedImages.append(image)
            }
        }
    }

    func analyzeWithAI() {
        guard hasContent, !isAnalyzing else { return }
        isAnalyzing = true
        showAIDisclaimer = false

        Task {
            let scanner = DocumentScannerService()
            let ocrText = try? await scanner.extractText(from: uploadedImages)

            let tempEntry = JournalEntry(
                title: "Medical Checkup",
                content: notes,
                entryType: .checkup
            )

            do {
                let result = try await tagService.generateTags(for: tempEntry, ocrText: ocrText)
                await MainActor.run {
                    withAnimation(.spring) {
                        self.aiTags = result.tags
                        self.aiAnalysis = result.analysis
                        print("ai analysis \(result.analysis)")
                        self.isAnalyzing = false
                    }
                }
            } catch {
                await MainActor.run { self.isAnalyzing = false }
            }
        }
    }

    func saveEntry(context: ModelContext, onComplete: @escaping () -> Void) {
        isSaving = true
        let imageData = uploadedImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
        let entryId = UUID()
        let capturedNotes = notes
        let capturedImages = uploadedImages
        let capturedTags = aiTags
        let capturedAnalysis = aiAnalysis

        let entry = JournalEntry(
            id: entryId,
            title: "Medical Checkup",
            content: capturedNotes,
            entryType: .checkup,
            aiTagsRaw: capturedTags?.joined(separator: ","),
            aiAnalysis: capturedAnalysis,
            attachedImagesData: imageData.isEmpty ? nil : imageData
        )
        context.insert(entry)
        isSaving = false
        onComplete()

        UserDefaults.standard.set(true, forKey: "isGeneratingChecklist")

        Task.detached(priority: .background) { [weak self] in
            guard let self else {
                await MainActor.run {
                    UserDefaults.standard.set(false, forKey: "isGeneratingChecklist")
                }
                return
            }
            let scanner = DocumentScannerService()
            let ocrText = try? await scanner.extractText(from: capturedImages)

            // Generate tags if not already done
            if capturedTags == nil {
                if let result = try? await self.tagService.generateTags(for: entry, ocrText: ocrText) {
                    await MainActor.run {
                        entry.aiTags = result.tags
                        if let analysis = result.analysis { entry.aiAnalysis = analysis }
                        entry.updatedAt = Date()
                    }
                }
            }

            // Feed the curated health_summary.md knowledge base from whatever AI
            // results now exist on the entry (already-analyzed or just-generated
            // above) — no second/duplicate cloud analysis call (see HealthSummaryManager).
            let (finalTags, finalAnalysis, entryDate): ([String], String?, Date) = await MainActor.run {
                (entry.aiTags, entry.aiAnalysis, entry.createdAt)
            }
            await HealthSummaryManager.shared.updateFromExistingCheckupResult(
                tags: finalTags, analysisMarkdown: finalAnalysis, date: entryDate
            )

            // Always generate checklist from new checkup
            if let items = try? await self.checklistService.generateChecklist(
                ocrText: ocrText ?? "",
                notes: capturedNotes
            ), !items.isEmpty {
                await MainActor.run {
                    let existing = (try? context.fetch(FetchDescriptor<ChecklistItem>())) ?? []
                    existing.forEach { context.delete($0) }

                    for (idx, item) in items.enumerated() {
                        context.insert(ChecklistItem(
                            text: item.text,
                            emoji: item.emoji,
                            sortOrder: idx,
                            sourceCheckupId: entryId
                        ))
                    }
                    UserDefaults.standard.set(Date(), forKey: "checklistLastReset")
                }
            }

            await MainActor.run {
                UserDefaults.standard.set(false, forKey: "isGeneratingChecklist")
            }
        }
    }

    // MARK: - Private

    private func loadSelectedImages(from items: [PhotosPickerItem]) {
        Task {
            var images: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = ImageDownsampler.downsampled(from: data) {
                    images.append(image)
                }
            }
            await MainActor.run { self.uploadedImages = images }
        }
    }
}
