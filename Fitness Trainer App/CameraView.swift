import SwiftUI
import AVFoundation

struct CameraView: View {
    @State private var isCameraAuthorized: Bool = false
    @State private var showAlert: Bool = false
    var videoCapture = VideoCapture()
    @State private var cameraViewController = CameraViewController()
    
    @State private var keypoints: [PosePoint] = []

    var body: some View {
        ZStack {
            if isCameraAuthorized {
                VStack(spacing: 20) {
                    CameraPreview(videoCapture: videoCapture, keypoints: $keypoints)
                        .frame(height: 500)
                        .padding(.top, 20)
                    
                    ScrollView {
                        VStack {
                            KeypointsListView(keypoints: keypoints)
                        }
                        .padding()
                    }
                    .frame(height: 200)
                    
                    // Flip Camera Button
                    Button(action: {
                        videoCapture.stop()  // Stop the video session
                        cameraViewController.resetInferencingState() // Reset any inferences before switching
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            videoCapture.switchCamera()  // Switch camera after a brief delay
                            videoCapture.start() // Restart the video session
                        }
                    }) {
                        Text("Flip Camera")
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.bottom, 20)

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
