//
//  CoreMLManager.swift
//  Fitness Trainer App
//
//  Created by Ryan Nguyen on 2024-10-27.
//


import CoreML
import Vision
import AVFoundation

class CoreMLManager {
    // CoreML Model
    private let model: VNCoreMLModel

    init() {
        do {
            // Replace "YourModel" with your actual model's name
            self.model = try VNCoreMLModel(for: YourModel().model)
        } catch {
            fatalError("Failed to load CoreML model: \(error)")
        }
    }

    // Function to process a video frame and perform a prediction
    func performPrediction(pixelBuffer: CVPixelBuffer, completion: @escaping (String, Float) -> Void) {
        // Create a request using the CoreML model
        let request = VNCoreMLRequest(model: model) { (request, error) in
            guard let results = request.results as? [VNClassificationObservation], let firstResult = results.first else {
                return
            }
            
            // Returning the prediction identifier and confidence
            completion(firstResult.identifier, firstResult.confidence)
        }
        
        // Perform the request on the pixelBuffer (frame from the camera)
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform CoreML request: \(error)")
        }
    }
}
