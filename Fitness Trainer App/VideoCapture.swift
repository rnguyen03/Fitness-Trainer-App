//
//  VideoCapture.swift
//  Fitness Trainer App
//
//  Created by Ryan Nguyen on 2024-10-29.
//

import AVFoundation

public class VideoCapture: NSObject {
    public var previewLayer: CALayer?
    public weak var delegate: VideoCaptureDelegate?
    public var fps = 30
    
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "session queue")
    
    private var lastTimestamp = CMTime()
    public var currentCameraPosition: AVCaptureDevice.Position = .back
    
    public var currentPosition: AVCaptureDevice.Position {
        return currentCameraPosition
    }

    public func setUp(sessionPreset: AVCaptureSession.Preset = .vga640x480,
                      cameraPosition: AVCaptureDevice.Position = .back,
                      completion: @escaping (Bool) -> Void) {
        currentCameraPosition = cameraPosition
        sessionQueue.async {
            self.setUpCamera(sessionPreset: sessionPreset, cameraPosition: cameraPosition, completion: completion)
        }
    }

    private func setUpCamera(sessionPreset: AVCaptureSession.Preset,
                             cameraPosition: AVCaptureDevice.Position,
                             completion: @escaping (Bool) -> Void) {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = sessionPreset
        
        // Remove existing inputs
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) else {
            print("Error: No video devices available")
            completion(false)
            return
        }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            print("Error: Could not create AVCaptureDeviceInput")
            completion(false)
            return
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

    public func switchCamera() {
        currentCameraPosition = (currentCameraPosition == .back) ? .front : .back
        stop()

        setUp(sessionPreset: .vga640x480, cameraPosition: currentCameraPosition) { [weak self] success in
            guard let self = self else { return }
            
            if success {
                DispatchQueue.main.async {
                    // Remove the existing preview layer if it's present
                    self.previewLayer?.removeFromSuperlayer()

                    // Re-setup the preview layer for the new camera session
                    if let newPreviewLayer = self.previewLayer as? AVCaptureVideoPreviewLayer {
                        newPreviewLayer.session = self.captureSession
                        newPreviewLayer.videoGravity = .resizeAspect
                        newPreviewLayer.connection?.videoOrientation = .portrait
                        self.delegate?.cameraDidSwitch(self) // Notify the delegate
                    }
                    
                    self.start() // Restart the video session after switching
                }
            } else {
                print("Failed to switch camera")
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

public protocol VideoCaptureDelegate: AnyObject {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame: CVPixelBuffer, timestamp: CMTime)
    func cameraDidSwitch(_ capture: VideoCapture) // New delegate method
}
