import SwiftUI
import Vision
import CoreML

struct RemoveBackgroundView: View {
    @State private var inputImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var isProcessing = false
    @State private var updateTrigger = false
    
    var body: some View {
        VStack {
            if let inputImage = inputImage {
                HStack {
                    VStack {
                        Text("원본")
                            .font(.headline)
                        
                        Image(uiImage: inputImage)// 이미지피커에서 선택한 사진
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                    }
                    
                    if let processedImage = processedImage {
                        VStack {
                            Text("누끼")
                                .font(.headline)
                            Image(uiImage: processedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                        }
                    } else {
                        VStack {
                            Text("Processing...")
                                .font(.headline)
                            ProgressView()
                        }
                        .frame(maxHeight: 300)
                    }
                }
                .padding()
            } else {
                Text("이미지가 아직 선택되지 않았습니다.")
                    .foregroundColor(.gray)
                    .padding()
            }
            
            Spacer()
            
            Button(action: {
                showingImagePicker = true
            }) {
                Text("이미지 선택")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
            .sheet(isPresented: $showingImagePicker, onDismiss: processImage) {
                RawImagePicker(image: $inputImage)
            }
            
            if isProcessing {
                ProgressView("Removing background...")
                    .padding()
            }
        }
        .padding()
        .onChange(of: updateTrigger) { _ in }
    }
    
    func processImage() {
        guard let inputImage = inputImage else {
            print("No image selected")
            return
        }
        
        isProcessing = true
        processedImage = nil  // Reset processed image
        print("Starting background removal process...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.removeBackground(from: inputImage)
            
            DispatchQueue.main.async {
                if let result = result {
                    print("Background removal successful")
                    self.processedImage = result
                    self.updateTrigger.toggle()
                } else {
                    print("Background removal failed")
                }
                self.isProcessing = false
            }
        }
    }
    
    func removeBackground(from image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else {
            print("Failed to create CIImage from UIImage")
            return nil
        }
        
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        
        #if targetEnvironment(simulator)
        if #available(iOS 17.0, *) {
            let allDevices = MLComputeDevice.allComputeDevices
            for device in allDevices where device.description.contains("MLCPUComputeDevice") {
                print("Using MLCPUComputeDevice")
                request.setComputeDevice(.some(device), for: .main)
                break
            }
        } else {
            request.usesCPUOnly = true
            print("Using CPU for segmentation")
        }
        #endif
        
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        do {
            print("Performing segmentation request...")
            try handler.perform([request])
            print("Segmentation request completed")
            
            if let mask = request.results?.first?.pixelBuffer {
                print("Mask generated successfully")
                let maskedImage = applyMask(to: ciImage, mask: mask)
                
                let context = CIContext()
                guard let cgImage = context.createCGImage(maskedImage, from: maskedImage.extent) else {
                    print("Failed to create CGImage from masked image")
                    return nil
                }
                return UIImage(cgImage: cgImage)
            } else {
                print("No mask generated")
            }
        } catch {
            print("Failed to perform segmentation: \(error.localizedDescription)")
        }
        
        return nil
    }
   
    func applyMask(to image: CIImage, mask: CVPixelBuffer) -> CIImage {
        let maskCIImage = CIImage(cvPixelBuffer: mask)
        
        let scale = max(image.extent.width / maskCIImage.extent.width,
                        image.extent.height / maskCIImage.extent.height)
        let resizedMask = maskCIImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        let maskedImage = image.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputMaskImageKey: resizedMask
        ])
        
        print("Masked image generated successfully")
        print("Original Image Extent: \(image.extent)")
        print("Resized Mask Extent: \(resizedMask.extent)")
        print("Masked Image Extent: \(maskedImage.extent)")
        
        return maskedImage
    }
}
