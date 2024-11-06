//
//  PoseEstimationManager.swift
//  Fitness Trainer App
//
//  Created by Ryan Nguyen on 2024-10-29.
//

import Vision

class PoseEstimationManager {
    private let coreMLManager = CoreMLManager()
    let postProcessor = HeatmapPostProcessor()

    func getModel() -> VNCoreMLModel {
        return coreMLManager.getModel()
    }
}
