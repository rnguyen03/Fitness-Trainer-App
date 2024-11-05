//
//  CameraPreview.swift
//  Fitness Trainer App
//
//  Created by Ryan Nguyen on 2024-10-29.
//

import SwiftUI
import AVFoundation

struct CameraPreview: UIViewControllerRepresentable {
    var videoCapture: VideoCapture
    @Binding var keypoints: [PosePoint]
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let viewController = CameraViewController()
        viewController.videoCapture = videoCapture
        viewController.onKeypointsUpdate = { updatedKeypoints in
            self.keypoints = updatedKeypoints
        }
        return viewController
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}
