import SwiftUI
import AVFoundation
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

struct LiveRemoveBackgroundView: View {
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        ZStack {
            if let frame = cameraManager.capturedImage {
                Image(uiImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Text("카메라를 로드하는 중...")
            }
        }
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
}

class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var session: AVCaptureSession
    private var videoOutput: AVCaptureVideoDataOutput
    private var context = CIContext()
    
    @Published var capturedImage: UIImage?

    private let backgroundModel: VNCoreMLModel = {
        do {
            let config = MLModelConfiguration()
            let model = try VNCoreMLModel(for: DeepLabV3(configuration: config).model)
            return model
        } catch {
            fatalError("CoreML 모델을 로드할 수 없습니다: \(error.localizedDescription)")
        }
    }()
    
    override init() {
        session = AVCaptureSession()
        videoOutput = AVCaptureVideoDataOutput()
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("전면 카메라를 사용할 수 없습니다.")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.addInput(input)
        } catch {
            fatalError("카메라 입력을 추가할 수 없습니다: \(error.localizedDescription)")
        }
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        session.addOutput(videoOutput)
    }
    
    func startSession() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if granted {
                DispatchQueue.main.async {
                    self.session.startRunning()
                }
            } else {
                print("카메라 접근이 허용되지 않았습니다.")
            }
        }
    }
    
    func stopSession() {
        session.stopRunning()
    }
    
    private func processFrame(pixelBuffer: CVPixelBuffer) {
        let request = VNCoreMLRequest(model: backgroundModel) { request, error in
            guard let results = request.results as? [VNPixelBufferObservation],
                  let maskPixelBuffer = results.first?.pixelBuffer else {
                return
            }
            
            // 마스크를 적용하여 배경을 검정색으로 변경
            let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
            let inputImage = CIImage(cvPixelBuffer: pixelBuffer)

            let maskedImage = inputImage.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputMaskImageKey: maskImage,
                kCIInputBackgroundImageKey: CIImage(color: .black)
            ])
            
            if let cgImage = self.context.createCGImage(maskedImage, from: inputImage.extent) {
                DispatchQueue.main.async {
                    self.capturedImage = UIImage(cgImage: cgImage)
                }
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
    
    // AVCaptureVideoDataOutputSampleBufferDelegate 메서드 구현
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        processFrame(pixelBuffer: pixelBuffer)
    }
}
