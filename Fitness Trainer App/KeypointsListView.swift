//
//  KeyPointsListView.swift
//  Fitness Trainer App
//
//  Created by Ryan Nguyen on 2024-10-29.
//

import SwiftUI

struct KeypointsListView: View {
    var keypoints: [PosePoint]
    
    var body: some View {
        VStack(alignment: .leading) {
            ForEach(keypoints) { keypoint in
                HStack {
                    Text(keypoint.label)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(keypoint.point)
                        .font(.subheadline)
                    
                    Text("Confidence: \(keypoint.confidence)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Divider()
            }
        }
        .padding()
    }
}
