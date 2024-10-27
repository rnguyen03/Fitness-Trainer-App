//
//  ContentView.swift
//  Fitness Trainer App
//
//  Created by Ryan Nguyen on 2024-10-26.
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @State private var isCameraAuthorized: Bool = false
    @State private var showAlert: Bool = false
    
    var body: some View {
        ZStack {
            if isCameraAuthorized {
                CameraPreview() // Display camera feed if authorized
                    .edgesIgnoringSafeArea(.all)
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
    
    // Check and request camera permission
    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // The user has previously granted access to the camera.
            isCameraAuthorized = true
        case .notDetermined:
            // The user has not yet been asked for camera access.
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.isCameraAuthorized = granted
                    if !granted {
                        self.showAlert = true
                    }
                }
            }
        case .denied, .restricted:
            // The user has previously denied or the access is restricted.
            showAlert = true
            isCameraAuthorized = false
        @unknown default:
            // Handle any unknown future cases.
            showAlert = true
            isCameraAuthorized = false
        }
    }
}

// Camera Preview using UIViewControllerRepresentable to integrate UIKit with SwiftUI
struct CameraPreview: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CameraViewController {
        return CameraViewController() // Create the camera view controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        // No updates needed for the camera feed
    }
}

// UIViewController for handling the live camera feed
class CameraViewController: UIViewController {
    var captureSession: AVCaptureSession?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create the capture session and set the camera feed as the input
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .high

        guard let backCamera = AVCaptureDevice.default(for: .video) else {
            print("Unable to access back camera!")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            if captureSession?.canAddInput(input) == true {
                captureSession?.addInput(input)
            }

            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.layer.bounds
            view.layer.addSublayer(previewLayer)

            captureSession?.startRunning()

        } catch let error {
            print("Error Unable to initialize back camera:  \(error.localizedDescription)")
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Stop the session when the view is dismissed
        captureSession?.stopRunning()
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}
