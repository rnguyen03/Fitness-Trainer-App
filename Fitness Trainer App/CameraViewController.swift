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
    let poseEstimationManager = PoseEstimationManager()

    var drawingJointView = DrawingJointView()
    var isInferencing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        videoCapture?.setUp { success in
            if success {
                self.setupCameraPreview()
                self.videoCapture?.start()
            }
        }
        videoCapture?.delegate = self
    }

    func setupCameraPreview() {
        DispatchQueue.main.async {
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
            poseEstimationManager.predictUsingVision(pixelBuffer: pixelBuffer) { keypoints in
                DispatchQueue.main.async {
                    self.drawingJointView.bodyPoints = keypoints.compactMap { posePoint in
                        // Parse the point string, expecting a format like "(x, y)"
                        let coordinates = posePoint.point
                            .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
                            .split(separator: ",")
                            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                        
                        // Ensure we have both x and y values before creating a PredictedPoint
                        guard coordinates.count == 2 else { return nil }
                        
                        let point = CGPoint(x: coordinates[0], y: coordinates[1])
                        // Assuming confidence can be converted to Double
                        let confidence = Double(posePoint.confidence) ?? 0.0
                        return PredictedPoint(maxPoint: point, maxConfidence: confidence)
                    }
                    
                    self.onKeypointsUpdate?(keypoints)
                    self.isInferencing = false
                }

            }
        }
    }

}
