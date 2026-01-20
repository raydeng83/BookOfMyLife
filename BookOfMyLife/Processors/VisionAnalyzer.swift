//
//  VisionAnalyzer.swift
//  BookOfMyLife
//
//  On-device photo analysis using Vision framework
//

import UIKit
import Vision

class VisionAnalyzer {

    // Analyze photo and extract metadata
    func analyzePhoto(_ image: UIImage) async -> (scenes: [String], hasFaces: Bool, quality: Double, ocrText: String?) {
        var detectedScenes: [String] = []
        var hasFaces = false
        var qualityScore = 0.5
        var ocrText: String?

        guard let cgImage = image.cgImage else {
            return ([], false, 0.5, nil)
        }

        // Scene classification
        detectedScenes = await classifyScenes(cgImage)

        // Face detection
        hasFaces = await detectFaces(cgImage)

        // Quality assessment
        qualityScore = await assessQuality(cgImage)

        // OCR text recognition
        ocrText = await recognizeText(cgImage)

        return (detectedScenes, hasFaces, qualityScore, ocrText)
    }

    // MARK: - Scene Classification

    private func classifyScenes(_ image: CGImage) async -> [String] {
        return await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                guard let observations = request.results as? [VNClassificationObservation],
                      error == nil else {
                    continuation.resume(returning: [])
                    return
                }

                // Get top 5 classifications with confidence > 0.3
                let scenes = observations
                    .filter { $0.confidence > 0.3 }
                    .prefix(5)
                    .map { $0.identifier }

                continuation.resume(returning: Array(scenes))
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - Face Detection

    private func detectFaces(_ image: CGImage) async -> Bool {
        return await withCheckedContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                guard let observations = request.results as? [VNFaceObservation],
                      error == nil else {
                    continuation.resume(returning: false)
                    return
                }

                continuation.resume(returning: !observations.isEmpty)
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - Quality Assessment

    private func assessQuality(_ image: CGImage) async -> Double {
        // Simple quality heuristic based on image properties
        let width = Double(image.width)
        let height = Double(image.height)
        let megapixels = (width * height) / 1_000_000.0

        // Quality score based on resolution
        var score = 0.5

        if megapixels > 8.0 {
            score = 0.9
        } else if megapixels > 4.0 {
            score = 0.8
        } else if megapixels > 2.0 {
            score = 0.7
        } else if megapixels > 1.0 {
            score = 0.6
        }

        // Bonus for good aspect ratio (not too stretched)
        let aspectRatio = max(width, height) / min(width, height)
        if aspectRatio < 2.0 {
            score += 0.1
        }

        return min(score, 1.0)
    }

    // MARK: - OCR Text Recognition

    private func recognizeText(_ image: CGImage) async -> String? {
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation],
                      error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                let fullText = recognizedStrings.joined(separator: " ")
                continuation.resume(returning: fullText.isEmpty ? nil : fullText)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try? handler.perform([request])
        }
    }
}
