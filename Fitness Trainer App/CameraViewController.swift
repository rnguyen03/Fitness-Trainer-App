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
            // Remove any existing preview layers before adding a new one
            self.view.layer.sublayers?.forEach { layer in
                if layer is AVCaptureVideoPreviewLayer {
                    layer.removeFromSuperlayer()
                }
            }

            if let previewLayer = self.videoCapture?.previewLayer {
                previewLayer.frame = self.view.bounds
                self.view.layer.addSublayer(previewLayer)
            }

            // Add the joint drawing view layer on top of the camera preview
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
        // Ensure the Vision request exists and is set up
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

        if movingAverageFilters.count != predictedPoints.count {
            movingAverageFilters = predictedPoints.map { _ in MovingAverageFilter(limit: 3) }
        }

        for (index, point) in predictedPoints.enumerated() {
            movingAverageFilters[index].add(element: point)
            predictedPoints[index] = movingAverageFilters[index].averagedValue()
        }

        DispatchQueue.main.async {
            self.drawingJointView.bodyPoints = predictedPoints

            // Ensure each keypoint is labeled correctly
            let labeledKeypoints: [PosePoint] = predictedPoints.enumerated().compactMap { index, point in
                guard let point = point else { return nil }
                let label = PoseEstimationForMobileConstant.pointLabels[index]
                return PosePoint(label: label, point: String(format: "(%.3f, %.3f)", point.maxPoint.x, point.maxPoint.y), confidence: String(format: "%.2f", point.maxConfidence))
            }

            // Update the keypoints with labels in the UI
            self.onKeypointsUpdate?(labeledKeypoints)
            self.isInferencing = false
        }

    }

}
