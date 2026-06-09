//
//  MedCheckupAnalysisTests.swift
//  MedJourneyTests
//
//  Integration tests: Vision OCR → Gemini vs GPT-4o medical analysis comparison.
//
//  ⚠️  These tests make real network calls. They may take 10–60 seconds to complete.
//      Run them with: Product → Test (Cmd+U) and check the console for printed results.
//
//  Optional OCR pipeline tests (testOCRPipeline*):
//      Add the lab result images to the MedJourneyTests target in Xcode with these names:
//      - lab_result_1.png  (COVID/Influenza Rapid Panel page)
//      - lab_result_2.png  (Hematology CBC page)
//      The tests will skip gracefully if the images are not found.
//

import Testing
import UIKit
import Vision
@testable import MedJourney

// MARK: - Hardcoded OCR text (Mayapada Hospital — 22 May 2025)
// This matches the text Apple Vision OCR would extract from the attached lab result images.

private let mayapadaLabOCRText = """
LAPORAN HASIL LABORATORIUM
Mayapada Hospital - Experience Better Care

No. Lab             : 2505220089D
No. Rekam Medis     : 0300051712
Nama Pasien         : SAMUEL PRASETIYO
Tgl. Lahir / Umur  : 09-04-1997 / 28 Th 1 Bl 13 Hr
Jenis Kelamin       : Laki-laki
Alamat              : BOGANGIN I NO 22 - 081233933175
Lokasi              : Emergency Department / -

Dokter Patologi Klinik : dr. Yolanda Njotowibowo, Sp.PK
Dokter Pengirim        : dr. Ihya Fakhrurizal Amin
Tgl. Transaksi         : 22-Mei-2025 19:11
Hasil Selesai          : 22-Mei-2025 19:35
Cetak Hasil            : 22-Mei-2025 19:35

PEMERIKSAAN                      HASIL    NILAI RUJUKAN     SATUAN    METODE

COVID-19/INFLUENZA A&B RAPID PANEL
SARS-CoV-2                       Negatif  Negatif
Influenza A                      Negatif  Negatif
Influenza B                      Negatif  Negatif

HEMATOLOGI
HEMATOLOGI LENGKAP
Hemoglobin (Hb)                  16.4     14.0 - 18.0       g/dL
Hematokrit (Ht)                  50       40 - 52           %
Eritrosit (RBC)               H  5.6      4.5 - 5.5         juta/µL

Nilai Rerata Eri (NER)
VER (MCV)                        89.2     82 - 92           fL
HER (MCH)                        30       27 - 31           pg
KHER (MCHC)                      33       32 - 36           g/dL
Sebaran Ukuran Eri (RDW)-SD      43.1     38 - 50           fL
Sebaran Ukuran Eri (RDW)-CV      13.1     12 - 15           %
Leukosit                         6.0      4.3 - 10.8        ribu/µL

Hitung Jenis
Basofil relatif                  0        0 - 1             Sel/µL
Eosinofil Relatif                0        1 - 5             %
Neutrofil Segmen Relatif         63       40 - 70           %
Limfosit Relatif              L  21.5     23 - 50           %
Monosit Relatif               H  15.4     4 - 10            %
Basofil absolut                  0.01     0.00 - 0.10       10³/µL
Eosinofil Absolut                0.01     0.00 - 0.40       10³/µL
Neutrofil Absolut                3.77     1.50 - 7.00       10³/µL
Limfosit Absolut                 1.29     1.00 - 3.70       10³/µL
Monosit Absolut               H  0.93     0.00 - 0.70       10³/µL
Trombosit                        172      150 - 400         ribu/µL
Trombosit Imatur (IPF)           4.1      1.1 - 6.1         %
Retikulosit                      1.1      0.5 - 1.5         %

SEROLOGI
SEROLOGI UMUM
Dengue NS 1 Ag                   Negatif  Negatif

IMUNOLOGI & MOLEKULAR

Catatan:
1/ Desimal dinyatakan dengan titik, ribuan dinyatakan dengan spasi.
2/ Penafsiran hasil yang mantap hanya dapat diberikan oleh dokter yang memegang seluruh data hasil pemeriksaan.
3/ Hasil uji cepat (rapid) sebagai penyaring (sementara) & masih perlu dikonfirmasi dengan uji yang lebih mantap.

Di Cetak Oleh : Novia Saraswati, Amd.AK
MAYAPADA HOSPITAL SURABAYA Jl. Mayjen Sungkono No. 16 - 20 Kota Surabaya, Jawa Timur
"""

// MARK: - Helper: bundle access for struct-based tests

private final class TestBundleToken: NSObject {}

// MARK: - Test Suite

@Suite("Medical Checkup Analysis — Gemini vs GPT-4o Comparison")
struct MedCheckupAnalysisTests {

    // MARK: - Keys
    //
    // Resolution order:
    //   1. App bundle Config.plist — the .app sits next to this .xctest in DerivedData
    //   2. GEMINI_API_KEY / OPENAI_API_KEY Xcode scheme environment variable

    private var geminiKey: String {
        // 1. App bundle's Config.plist (git-ignored; holds the real key locally)
        let testBundle = Bundle(for: TestBundleToken.self)
        let appBundleURL = testBundle.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("MedJourney.app")
        if let appBundle = Bundle(url: appBundleURL),
           let configURL = appBundle.url(forResource: "Config", withExtension: "plist"),
           let cfg = NSDictionary(contentsOf: configURL) as? [String: Any],
           let key = cfg["GEMINI_API_KEY"] as? String,
           !key.isEmpty, !key.hasPrefix("YOUR_") {
            return key
        }
        // 2. Xcode scheme env var
        return ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
    }

    private var openAIKey: String {
        // 1. App bundle's Config.plist
        let testBundle = Bundle(for: TestBundleToken.self)
        let appBundleURL = testBundle.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("MedJourney.app")
        if let appBundle = Bundle(url: appBundleURL),
           let configURL = appBundle.url(forResource: "Config", withExtension: "plist"),
           let cfg = NSDictionary(contentsOf: configURL) as? [String: Any],
           let key = cfg["OPENAI_API_KEY"] as? String,
           !key.isEmpty, !key.hasPrefix("YOUR_") {
            return key
        }
        // 2. Xcode scheme env var
        return ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    }

    // MARK: - Gemini — hardcoded OCR text

    @Test("Gemini: analyze Mayapada Hospital lab results (hardcoded OCR)", .timeLimit(.minutes(2)))
    func testGeminiAnalysisHardcodedOCR() async throws {
        let service = GeminiTagService(apiKey: geminiKey)
        let entry = makeCheckupEntry()

        let result = try await service.generateTags(for: entry, ocrText: mayapadaLabOCRText)
        printResult(label: "GEMINI (gemini-flash-latest)", result: result)

        #expect(!result.tags.isEmpty, "Gemini should return at least one observational tag")
        #expect(result.analysis != nil, "Gemini should return a structured analysis for checkup entries")
    }

    // MARK: - GPT-4o — hardcoded OCR text

    @Test("GPT-4o: analyze Mayapada Hospital lab results (hardcoded OCR)", .timeLimit(.minutes(2)))
    func testGPT4oAnalysisHardcodedOCR() async throws {
        let service = OpenAITagService(apiKey: openAIKey)
        let entry = makeCheckupEntry()

        let result = try await service.generateTags(for: entry, ocrText: mayapadaLabOCRText)
        printResult(label: "GPT-4o (gpt-4o)", result: result)

        #expect(!result.tags.isEmpty, "GPT-4o should return at least one observational tag")
        #expect(result.analysis != nil, "GPT-4o should return a structured analysis for checkup entries")
    }

    // MARK: - Side-by-side comparison (runs both in parallel)

    @Test("Compare: Gemini vs GPT-4o side-by-side", .timeLimit(.minutes(3)))
    func testSideBySideComparison() async throws {
        let geminiService = GeminiTagService(apiKey: geminiKey)
        let openAIService = OpenAITagService(apiKey: openAIKey)
        let entry = makeCheckupEntry()

        async let geminiTask = geminiService.generateTags(for: entry, ocrText: mayapadaLabOCRText)
        async let gptTask    = openAIService.generateTags(for: entry, ocrText: mayapadaLabOCRText)

        let (gemini, gpt) = try await (geminiTask, gptTask)
        printSideBySide(gemini: gemini, gpt: gpt)

        #expect(!gemini.tags.isEmpty, "Gemini should return tags")
        #expect(!gpt.tags.isEmpty,    "GPT-4o should return tags")
        #expect(gemini.analysis != nil, "Gemini should return analysis")
        #expect(gpt.analysis    != nil, "GPT-4o should return analysis")
    }

    // MARK: - OCR pipeline: Vision → Gemini (requires test images in bundle)

    @Test("OCR pipeline: Apple Vision → Gemini analysis", .timeLimit(.minutes(3)))
    func testOCRPipelineGemini() async throws {
        guard let images = loadTestImages() else {
            print("""
            ⚠️  [OCR Pipeline - Gemini] Skipping: no test images found.
                Add 'lab_result_1.png' and 'lab_result_2.png' to the MedJourneyTests
                target (Build Phases → Copy Bundle Resources) and re-run.
            """)
            return
        }

        let ocrText = try await runVisionOCR(on: images)

        printOCRText(ocrText)
        #expect(!ocrText.isEmpty, "Apple Vision should extract text from the lab result images")

        let service = GeminiTagService(apiKey: geminiKey)
        let entry   = makeCheckupEntry()
        let result  = try await service.generateTags(for: entry, ocrText: ocrText)

        printResult(label: "GEMINI (after Vision OCR)", result: result)
        #expect(!result.tags.isEmpty)
        #expect(result.analysis != nil)
    }

    // MARK: - OCR pipeline: Vision → GPT-4o (requires test images in bundle)

    @Test("OCR pipeline: Apple Vision → GPT-4o analysis", .timeLimit(.minutes(3)))
    func testOCRPipelineGPT4o() async throws {
        guard let images = loadTestImages() else {
            print("""
            ⚠️  [OCR Pipeline - GPT-4o] Skipping: no test images found.
                Add 'lab_result_1.png' and 'lab_result_2.png' to the MedJourneyTests
                target (Build Phases → Copy Bundle Resources) and re-run.
            """)
            return
        }

        let ocrText = try await runVisionOCR(on: images)

        printOCRText(ocrText)
        #expect(!ocrText.isEmpty, "Apple Vision should extract text from the lab result images")

        let service = OpenAITagService(apiKey: openAIKey)
        let entry   = makeCheckupEntry()
        let result  = try await service.generateTags(for: entry, ocrText: ocrText)

        printResult(label: "GPT-4o (after Vision OCR)", result: result)
        #expect(!result.tags.isEmpty)
        #expect(result.analysis != nil)
    }

    // MARK: - Full pipeline comparison: Vision OCR → both models (requires test images)

    @Test("Full pipeline: Vision OCR → Gemini vs GPT-4o comparison", .timeLimit(.minutes(4)))
    func testFullOCRPipelineComparison() async throws {
        guard let images = loadTestImages() else {
            print("""
            ⚠️  [Full OCR Pipeline] Skipping: no test images found.
                Add 'lab_result_1.png' and 'lab_result_2.png' to the MedJourneyTests
                target (Build Phases → Copy Bundle Resources) and re-run.
            """)
            return
        }

        let ocrText = try await runVisionOCR(on: images)
        printOCRText(ocrText)
        #expect(!ocrText.isEmpty)

        let geminiService = GeminiTagService(apiKey: geminiKey)
        let openAIService = OpenAITagService(apiKey: openAIKey)
        let entry         = makeCheckupEntry()

        async let geminiTask = geminiService.generateTags(for: entry, ocrText: ocrText)
        async let gptTask    = openAIService.generateTags(for: entry, ocrText: ocrText)

        let (gemini, gpt) = try await (geminiTask, gptTask)
        printSideBySide(gemini: gemini, gpt: gpt)

        #expect(!gemini.tags.isEmpty)
        #expect(!gpt.tags.isEmpty)
    }

    // MARK: - Helpers

    private func makeCheckupEntry() -> JournalEntry {
        JournalEntry(
            title: "Lab Results — Mayapada Hospital Surabaya",
            content: "Emergency Department visit. CBC, COVID-19/Influenza rapid panel, Dengue NS1 Ag, Serologi.",
            entryType: .checkup
        )
    }

    private func loadTestImages() -> [UIImage]? {
        let bundle = Bundle(for: TestBundleToken.self)
        let names  = ["lab_result_1", "lab_result_2"]
        let images = names.compactMap { name -> UIImage? in
            // Try both PNG and JPEG extensions
            UIImage(named: name, in: bundle, compatibleWith: nil)
                ?? UIImage(contentsOfFile: bundle.path(forResource: name, ofType: "png") ?? "")
                ?? UIImage(contentsOfFile: bundle.path(forResource: name, ofType: "jpg") ?? "")
        }
        return images.isEmpty ? nil : images
    }

    private func runVisionOCR(on images: [UIImage]) async throws -> String {
        let scanner = DocumentScannerService()
        return try await scanner.extractText(from: images)
    }

    // MARK: - Print helpers

    private func printOCRText(_ text: String) {
        print("""

        📄 ─────────────────────────────────────────────────────────────────
        📄  APPLE VISION OCR RESULT (\(text.count) characters)
        📄 ─────────────────────────────────────────────────────────────────
        \(text)
        📄 ─────────────────────────────────────────────────────────────────

        """)
    }

    private func printResult(label: String, result: AITagResult) {
        print("""

        🔬 ═══════════════════════════════════════════════════════════════════
        🔬  \(label)
        🔬 ═══════════════════════════════════════════════════════════════════
        """)

        print("🏷️  TAGS (\(result.tags.count)):")
        result.tags.forEach { print("   • \($0)") }

        if let analysis = result.analysis {
            print("\n📝  ANALYSIS:\n\(analysis)")
        } else {
            print("\n📝  No analysis returned.")
        }

        print("""
        🔬 ═══════════════════════════════════════════════════════════════════

        """)
    }

    private func printSideBySide(gemini: AITagResult, gpt: AITagResult) {
        print("""

        ┌─────────────────────────────────────────────────────────────────────┐
        │           MEDICAL ANALYSIS COMPARISON — GEMINI vs GPT-4o           │
        └─────────────────────────────────────────────────────────────────────┘

        🔵 GEMINI TAGS (\(gemini.tags.count)):
        \(gemini.tags.map { "   • \($0)" }.joined(separator: "\n"))

        🟢 GPT-4o TAGS (\(gpt.tags.count)):
        \(gpt.tags.map { "   • \($0)" }.joined(separator: "\n"))

        ──────────────────────────── GEMINI ANALYSIS ────────────────────────
        \(gemini.analysis ?? "(no analysis)")

        ──────────────────────────── GPT-4o ANALYSIS ────────────────────────
        \(gpt.analysis ?? "(no analysis)")

        └─────────────────────────────────────────────────────────────────────┘

        """)
    }
}
