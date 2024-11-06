import SwiftUI
import SwiftUI
import AVFoundation

struct CameraView: View {
    @State private var isCameraAuthorized: Bool = false
    @State private var showAlert: Bool = false
    var videoCapture = VideoCapture()
    
    @State private var keypoints: [PosePoint] = []

    var body: some View {
        ZStack {
            if isCameraAuthorized {
                VStack(spacing: 20) {  // Add spacing between camera and keypoints
                    CameraPreview(videoCapture: videoCapture, keypoints: $keypoints)
                        .frame(height: 500) // Make CameraPreview larger
                        .padding(.top, 20) // Add padding from the top of the screen
                    
                    ScrollView {
                        VStack {
                            KeypointsListView(keypoints: keypoints)
                        }
                        .padding()
                    }
                    .frame(height: 200) // Reduce height of ScrollView for the keypoints list
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
