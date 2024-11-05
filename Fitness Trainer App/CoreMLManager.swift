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
                let config = MLModelConfiguration()
                let coreMLModel = try cpmmodel(configuration: config).model
                self.model = try VNCoreMLModel(for: coreMLModel)
            } catch {
                fatalError("Failed to load CoreML model: \(error)")
            }
        }

        public func getModel() -> VNCoreMLModel {
            return model
        }

        func performPrediction(pixelBuffer: CVPixelBuffer, completion: @escaping (MLMultiArray) -> Void) {
            let request = VNCoreMLRequest(model: model) { (request, error) in
                if let error = error {
                    print("Error in CoreML prediction: \(error)")
                    return
                }

                guard let results = request.results as? [VNCoreMLFeatureValueObservation],
                      let multiArray = results.first?.featureValue.multiArrayValue else {
                    print("No multiArray result found")
                    return
                }

                completion(multiArray)
            }

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform CoreML request: \(error)")
            }
        }
    }
