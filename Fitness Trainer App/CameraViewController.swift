//
//  CameraViewController.swift
//  Fitness Trainer App
//
//  Created by Ryan Nguyen on 2024-10-29.
//

import UIKit
import AVFoundation
import CoreVideo
import Vision

class CameraViewController: UIViewController, VideoCaptureDelegate {
    var videoCapture: VideoCapture?
    var onKeypointsUpdate: (([PosePoint]) -> Void)?
    private var movingAverageFilters = [MovingAverageFilter]()
    private var request: VNCoreMLRequest?
    private let poseEstimationManager = PoseEstimationManager()
    var drawingJointView = DrawingJointView()
    var isInferencing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupVisionRequest()
        
        videoCapture?.setUp { success in
            if success {
                self.setupCameraPreview()
                self.videoCapture?.start()
            }
        }
        videoCapture?.delegate = self
    }
    
    func cameraDidSwitch(_ capture: VideoCapture) {
        resetInferencingState()
        setupCameraPreview() // Re-setup the camera preview after switching
    }

    func resetInferencingState() {
        isInferencing = false
        movingAverageFilters.removeAll()
        onKeypointsUpdate?([])
    }

    func setupVisionRequest() {
        request = VNCoreMLRequest(model: poseEstimationManager.getModel()) { [weak self] request, error in
            self?.visionRequestDidComplete(request: request, error: error)
        }
        request?.imageCropAndScaleOption = .scaleFill
    }

    func setupCameraPreview() {
        DispatchQueue.main.async {
            self.view.layer.sublayers?.forEach { layer in
                if layer is AVCaptureVideoPreviewLayer {
                    layer.removeFromSuperlayer()
                }
            }

            if let previewLayer = self.videoCapture?.previewLayer {
                previewLayer.frame = self.view.bounds
                self.view.layer.addSublayer(previewLayer)
            }

            self.drawingJointView.frame = self.view.bounds
            self.drawingJointView.backgroundColor = .clear
            self.view.addSubview(self.drawingJointView)
        }
    }

    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        if !isInferencing {
            isInferencing = true
            predictUsingVision(pixelBuffer: pixelBuffer)
        }
    }

    func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        guard let request = self.request else { return }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Vision request failed with error: \(error)")
            isInferencing = false
        }
    }

    private func visionRequestDidComplete(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNCoreMLFeatureValueObservation],
              let heatmaps = observations.first?.featureValue.multiArrayValue else {
            isInferencing = false
            return
        }

        var predictedPoints = poseEstimationManager.postProcessor.convertToPredictedPoints(from: heatmaps)
  
        
        /// Keypoint Print Debugging
        ///  1. These layers are used to capture larger receptive fields, which helps the model learn spatial relationships over larger areas of the image. However, the trade-off is reduced resolution in the output feature maps, which results in lower-resolution keypoint predictions. If the model is reducing the resolution by a factor of 4, the keypoints’ positions would be on a 96x96 grid instead of the full resolution, explaining why coordinates are multiples of 4.
        
//        for point in predictedPoints {
//            if let maxPoint = point?.maxPoint, let confidence = point?.maxConfidence {
//                print("Predicted keypoint at: (\(Int(maxPoint.x * 96)), \(Int(maxPoint.y * 96))) with confidence \(confidence)")
//            }
//        }


        // Flip the points horizontally if using the front camera
        if videoCapture?.currentPosition == .front {
            predictedPoints = predictedPoints.map { predictedPoint in
                guard let point = predictedPoint else { return nil }
                let flippedPoint = CGPoint(x: 1 - point.maxPoint.x, y: point.maxPoint.y)
                return PredictedPoint(maxPoint: flippedPoint, maxConfidence: point.maxConfidence)
            }
        }

        if movingAverageFilters.count != predictedPoints.count {
            movingAverageFilters = predictedPoints.map { _ in MovingAverageFilter(limit: 3) }
        }

        for (index, point) in predictedPoints.enumerated() {
            movingAverageFilters[index].add(element: point)
            predictedPoints[index] = movingAverageFilters[index].averagedValue()
        }

        DispatchQueue.main.async {
            self.drawingJointView.bodyPoints = predictedPoints

            let labeledKeypoints: [PosePoint] = predictedPoints.enumerated().compactMap { index, point in
                guard let point = point else { return nil }
                let label = PoseEstimationForMobileConstant.pointLabels[index]
                return PosePoint(label: label, point: String(format: "(%.3f, %.3f)", point.maxPoint.x, point.maxPoint.y), confidence: String(format: "%.2f", point.maxConfidence))
            }

            self.onKeypointsUpdate?(labeledKeypoints)
            self.isInferencing = false
        }
    }

}
