import SwiftUI
import CoreML
import AVFoundation
import CoreVideo

struct PosePoint: Identifiable {
    let id = UUID()
    let label: String
    let point: String
    let confidence: String
}

class CameraViewController: UIViewController, VideoCaptureDelegate {
    var videoCapture: VideoCapture?
    var onKeypointsUpdate: (([PosePoint]) -> Void)? // Closure to update keypoints in SwiftUI
    let coreMLManager = CoreMLManager() // Instance of CoreMLManager to handle predictions
    let heatmapPostProcessor = HeatmapPostProcessor() // HeatmapPostProcessor instance
    
    var drawingJointView = DrawingJointView() // Create DrawingJointView instance
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        videoCapture?.setUp(completion: { success in
            if success {
                DispatchQueue.main.async {
                    if let previewLayer = self.videoCapture?.previewLayer {
                        previewLayer.frame = self.view.bounds
                        self.view.layer.addSublayer(previewLayer)
                    }
                    self.videoCapture?.start()
                    
                    // Add DrawingJointView on top of the camera preview
                    self.drawingJointView.frame = self.view.bounds
                    self.drawingJointView.backgroundColor = .clear
                    self.view.addSubview(self.drawingJointView)
                }
            }
        })
        
        videoCapture?.delegate = self
    }

    // Handle captured video frame and perform prediction
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        coreMLManager.performPrediction(pixelBuffer: pixelBuffer) { multiArray in
            // Convert the MLMultiArray using the HeatmapPostProcessor
            let predictedPoints = self.heatmapPostProcessor.convertToPredictedPoints(from: multiArray)
            
            // Properly label keypoints based on body part
            let keypoints = predictedPoints.enumerated().map { (index, predictedPoint) -> PosePoint in
                // Fetch the body part label from the constant
                let label = PoseEstimationForMobileConstant.pointLabels[index]
                
                // Format the position as a string from PredictedPoint's x and y values
                let pointString = String(format: "(%.3f, %.3f)", predictedPoint?.maxPoint.x ?? 0, predictedPoint?.maxPoint.y ?? 0)
                
                // Format the confidence as a string
                let confidenceString = String(format: "%.2f", predictedPoint?.maxConfidence ?? 0)
                
                // Create PosePoint using formatted strings and body part label
                return PosePoint(label: label, point: pointString, confidence: confidenceString)
            }
            
            // Pass predictedPoints to the DrawingJointView to draw the joints
            DispatchQueue.main.async {
                self.drawingJointView.bodyPoints = predictedPoints // Update the joint view with keypoints
                
                // Also pass the keypoints to SwiftUI
                self.onKeypointsUpdate?(keypoints)
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        videoCapture?.stop()
    }
}

public protocol VideoCaptureDelegate: AnyObject {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame: CVPixelBuffer, timestamp: CMTime)
}

public class VideoCapture: NSObject {
    public var previewLayer: CALayer?
    public weak var delegate: VideoCaptureDelegate?
    public var fps = 30
    
    let captureSession = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "session queue")
    
    var lastTimestamp = CMTime()
    
    public func setUp(sessionPreset: AVCaptureSession.Preset = .vga640x480,
                      cameraPosition: AVCaptureDevice.Position = .back,
                      completion: @escaping (Bool) -> Void) {
        sessionQueue.async {
            self.setUpCamera(sessionPreset: sessionPreset, cameraPosition: cameraPosition, completion: completion)
        }
    }
    
    func setUpCamera(sessionPreset: AVCaptureSession.Preset, cameraPosition: AVCaptureDevice.Position, completion: @escaping (_ success: Bool) -> Void) {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = sessionPreset
        
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) else {
            fatalError("Error: no video devices available")
        }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            fatalError("Error: could not create AVCaptureDeviceInput")
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        previewLayer.connection?.videoOrientation = .portrait
        self.previewLayer = previewLayer
        
        let settings: [String : Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA),
        ]
        
        videoOutput.videoSettings = settings
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        videoOutput.connection(with: AVMediaType.video)?.videoOrientation = .portrait
        captureSession.commitConfiguration()
        
        completion(true)
    }
    
    public func start() {
        sessionQueue.async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }
    
    public func stop() {
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }
}

extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let deltaTime = timestamp - lastTimestamp
        if deltaTime >= CMTimeMake(value: 1, timescale: Int32(fps)) {
            lastTimestamp = timestamp
        }
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            delegate?.videoCapture(self, didCaptureVideoFrame: imageBuffer, timestamp: timestamp)
        }
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("Dropped frame at \(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))")
    }
}

struct CameraView: View {
    @State private var isCameraAuthorized: Bool = false
    @State private var showAlert: Bool = false
    var videoCapture = VideoCapture()
    
    @State private var keypoints: [PosePoint] = []
    let movingAverageFilters = Array(repeating: MovingAverageFilter(limit: 3), count: 14) // Use existing MovingAverageFilter
    let kalmanFilters = Array(repeating: KalmanFilter(), count: 14) // Kalman filters for smoothing

    var body: some View {
        ZStack {
            if isCameraAuthorized {
                VStack {
                    CameraPreview(videoCapture: videoCapture, keypoints: $keypoints, movingAverageFilters: movingAverageFilters, kalmanFilters: kalmanFilters)
                        .edgesIgnoringSafeArea(.all)
                        .frame(height: 400)
                    
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

// Updated CameraPreview struct to pass filters and keypoint updates
struct CameraPreview: UIViewControllerRepresentable {
    var videoCapture: VideoCapture
    @Binding var keypoints: [PosePoint]
    let movingAverageFilters: [MovingAverageFilter]
    let kalmanFilters: [KalmanFilter]

    func makeUIViewController(context: Context) -> CameraViewController {
        let viewController = CameraViewController()
        viewController.videoCapture = videoCapture
        viewController.onKeypointsUpdate = { updatedKeypoints in
            self.keypoints = applyAdvancedPostProcessing(updatedKeypoints)
        }
        return viewController
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}

    func applyAdvancedPostProcessing(_ keypoints: [PosePoint]) -> [PosePoint] {
        return keypoints.enumerated().map { index, keypoint in
            // Parse CGPoint from string for processing
            let components = keypoint.point
                .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
                .components(separatedBy: ", ")
            if let x = Double(components[0]), let y = Double(components[1]) {
                let currentPoint = CGPoint(x: x, y: y)

                // Apply Moving Average Filter using the existing class
                movingAverageFilters[index].add(element: PredictedPoint(maxPoint: currentPoint, maxConfidence: Double(keypoint.confidence) ?? 0))
                let smoothedPoint = movingAverageFilters[index].averagedValue()?.maxPoint ?? currentPoint

                // Apply Kalman Filter for further stability
                let filteredX = kalmanFilters[index].update(measurement: smoothedPoint.x)
                let filteredY = kalmanFilters[index].update(measurement: smoothedPoint.y)

                // Return updated PosePoint with postprocessed data
                return PosePoint(
                    label: keypoint.label,
                    point: String(format: "(%.3f, %.3f)", filteredX, filteredY),
                    confidence: keypoint.confidence
                )
            }
            return keypoint
        }
    }
}
