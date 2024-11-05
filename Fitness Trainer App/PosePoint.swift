//
//  PosePoint.swift
//  Fitness Trainer App
//
//  Created by Ryan Nguyen on 2024-10-29.
//

import Foundation

struct PosePoint: Identifiable {
    let id = UUID()
    let label: String
    let point: String
    let confidence: String
}
