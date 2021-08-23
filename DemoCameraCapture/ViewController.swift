//
//  ViewController.swift
//  DemoCameraCapture
//
//  Created by Higashihara Yoki on 2021/08/23.
//

import AVFoundation
import MetalKit
import UIKit

class ViewController: UIViewController {
    
    // Camera Capture
    var captureSession : AVCaptureSession!
    
    // Metal
    private var mtkView: MTKView = MTKView()
    private var metalDevice : MTLDevice!
    private var metalCommandQueue : MTLCommandQueue!
    
    // Core Image
    var ciContext : CIContext!
    var currentCIImage : CIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupMetal()
        ciContext = CIContext(mtlDevice: metalDevice)
        setupAndStartCaptureSession()
    }
    
    func setupView(){
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mtkView)
        
        NSLayoutConstraint.activate([
            mtkView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mtkView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mtkView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mtkView.topAnchor.constraint(equalTo: view.topAnchor)
        ])
    }
    
    private func setupMetal() {
        metalDevice = MTLCreateSystemDefaultDevice()
        mtkView.device = metalDevice
        
        metalCommandQueue = metalDevice.makeCommandQueue()
        
        mtkView.delegate = self
        
        //let it's drawable texture be writen to
        mtkView.framebufferOnly = false
        
        mtkView.isPaused = true
        mtkView.enableSetNeedsDisplay = true
    }
    
    func setupAndStartCaptureSession(){
        self.captureSession = AVCaptureSession()
        
        // setup capture session
        self.captureSession.beginConfiguration()
        if self.captureSession.canSetSessionPreset(.photo) {
            self.captureSession.sessionPreset = .photo
        }
        self.captureSession.automaticallyConfiguresCaptureDeviceForWideColor = true
        self.setupInputs()
        self.setupOutput()
        self.captureSession.commitConfiguration()
        
        self.captureSession.startRunning()
    }
    
    func setupInputs(){
        guard let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            fatalError("❌ no capture device")
        }
        
        guard let backCameraInput = try? AVCaptureDeviceInput(device: backCameraDevice) else {
            fatalError("❌ could not create a capture input")
        }
        
        if !captureSession.canAddInput(backCameraInput) {
            fatalError("❌ could not add capture input to capture session")
        }
        
        captureSession.addInput(backCameraInput)
    }
    
    func setupOutput(){
        let videoOutput = AVCaptureVideoDataOutput()
        let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            fatalError("❌ could not add video output")
        }
        
        videoOutput.connections.first?.videoOrientation = .portrait
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let cvBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let ciImage = CIImage(cvImageBuffer: cvBuffer)
        
        self.currentCIImage = ciImage
        
        DispatchQueue.main.async {
            self.mtkView.setNeedsDisplay()
        }
    }
    
}

extension ViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        guard let commandBuffer = metalCommandQueue.makeCommandBuffer() else {
            return
        }
        
        guard let ciImage = currentCIImage else {
            return
        }
        
        guard let currentDrawable = view.currentDrawable else {
            return
        }
        
        let heightOfciImage = ciImage.extent.height
        let heightOfDrawable = view.drawableSize.height
        let yOffsetFromBottom = (heightOfDrawable - heightOfciImage)/2
        
        ciContext.render(ciImage,
                              to: currentDrawable.texture,
                              commandBuffer: commandBuffer,
                              bounds: CGRect(origin: CGPoint(x: 0, y: -yOffsetFromBottom), size: view.drawableSize),
                              colorSpace: CGColorSpaceCreateDeviceRGB())
        
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}

