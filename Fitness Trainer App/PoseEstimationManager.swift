//
//  PoseEstimationManager.swift
//  Fitness Trainer App
//
//  Created by Ryan Nguyen on 2024-10-29.
//

import Vision

class PoseEstimationManager {
    let coreMLManager = CoreMLManager()
    let postProcessor = HeatmapPostProcessor()

    func predictUsingVision(pixelBuffer: CVPixelBuffer, completion: @escaping ([PosePoint]) -> Void) {
        let request = VNCoreMLRequest(model: coreMLManager.getModel()) { request, error in
            self.handleVisionRequest(request: request, error: error, completion: completion)
        }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }

    private func handleVisionRequest(request: VNRequest, error: Error?, completion: @escaping ([PosePoint]) -> Void) {
        if let results = request.results as? [VNCoreMLFeatureValueObservation],
           let multiArray = results.first?.featureValue.multiArrayValue {
            let predictedPoints = postProcessor.convertToPredictedPoints(from: multiArray)
            let keypoints = predictedPoints.enumerated().map { (index, predictedPoint) -> PosePoint in
                let label = PoseEstimationForMobileConstant.pointLabels[index]
                let pointString = String(format: "(%.3f, %.3f)", predictedPoint?.maxPoint.x ?? 0, predictedPoint?.maxPoint.y ?? 0)
                let confidenceString = String(format: "%.2f", predictedPoint?.maxConfidence ?? 0)
                return PosePoint(label: label, point: pointString, confidence: confidenceString)
            }
            completion(keypoints)
        }
    }
}
