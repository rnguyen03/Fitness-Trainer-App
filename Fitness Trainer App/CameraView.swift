import SwiftUI
import AVFoundation

struct CameraView: View {
    @State private var isCameraAuthorized: Bool = false
    @State private var showAlert: Bool = false
    var videoCapture = VideoCapture()
    
    @State private var keypoints: [PosePoint] = []
    let movingAverageFilters = Array(repeating: MovingAverageFilter(limit: 3), count: 14)
    let kalmanFilters = Array(repeating: KalmanFilter(), count: 14)

    @State private var smoothingIntensity: Double = 0.5
    @State private var filterEffect: Bool = true
    
    var body: some View {
        ZStack {
            if isCameraAuthorized {
                VStack {
                    CameraPreview(videoCapture: videoCapture, keypoints: $keypoints)
                        .edgesIgnoringSafeArea(.all)
                        .frame(height: 400)
                    
                    VStack {
                        Text("Smoothing Intensity: \(String(format: "%.2f", smoothingIntensity))")
                            .font(.headline)
                            .padding(.top)
                        
                        Slider(value: $smoothingIntensity, in: 0...1)
                            .padding()

                        Toggle(isOn: $filterEffect) {
                            Text("Enable Filters")
                        }
                        .padding()
                    }
                    
                    ScrollView {
                        KeypointsListView(keypoints: keypoints)
                            .frame(height: 200)
                    }
                    .padding()
                }
            } else {
                Text("Camera access is required to use this feature.")
                    .padding()
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            checkCameraPermission()
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Camera Permission Required"),
                message: Text("Please allow camera access in the settings to use the camera feature."),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCameraAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.isCameraAuthorized = granted
                    if !granted {
                        self.showAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showAlert = true
        @unknown default:
            showAlert = true
        }
    }
}
