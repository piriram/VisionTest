////
////  ContentView.swift
////  VisionTest
////
////  Created by ram on 9/20/24.
////
//
//import SwiftUI
//import CoreML
//import Vision
//import UIKit
//
//struct ContentView: View {
//    @State private var image: UIImage?
//    @State private var processedImage: UIImage?
//    @State private var showImagePicker = false
//    
//    var body: some View {
//        VStack {
//            if let processedImage = processedImage {
//                Image(uiImage: processedImage)
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 300, height: 300)
//            } else if let image = image {
//                Image(uiImage: image)
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 300, height: 300)
//                    .onAppear {
//                        print("Original image loaded")
//                    }
//            } else {
//                Text("Select an image")
//                    .padding()
//            }
//            
//            Button("Pick Image") {
//                showImagePicker = true
//            }
//            .padding()
//            
//            Button("Remove Background") {
//                if let image = image {
//                    print("Starting background removal process")
//                    removeBackground(from: image)
//                } else {
//                    print("No image selected")
//                }
//            }
//            .padding()
//        }
//        .sheet(isPresented: $showImagePicker) {
//            ImagePicker(image: $image)
//                .onDisappear {
//                    if image != nil {
//                        print("Image successfully selected: \(image!)")
//                    } else {
//                        print("No image was selected")
//                    }
//                }
//        }
//    }
//    
//    func removeBackground(from image: UIImage) {
//        guard let model = try? VNCoreMLModel(for: DeepLabV3(configuration: MLModelConfiguration()).model) else {
//            print("Failed to load model")
//            return
//        }
//
//        // sRGB로 변환된 이미지를 사용
//        guard let srgbImage = convertToSRGB(image: image) else {
//            print("Failed to convert image to sRGB")
//            return
//        }
//        
//        // 이미지 크기를 조정 (DeepLabV3 모델의 예상 크기는 513x513일 수 있음)
//        guard let resizedImage = resizeImage(image: srgbImage, targetSize: CGSize(width: 513, height: 513)) else {
//            print("Failed to resize image")
//            return
//        }
//
//        let request = VNCoreMLRequest(model: model) { request, error in
//            if let results = request.results as? [VNPixelBufferObservation], !results.isEmpty {
//                if let pixelBuffer = results.first?.pixelBuffer {
//                    self.processedImage = maskBackground(from: resizedImage, using: pixelBuffer)
//                    print("Background removal completed")
//                }
//            } else {
//                print("No results from CoreML request")
//            }
//        }
//        
//        guard let ciImage = CIImage(image: resizedImage) else {
//            print("Failed to convert UIImage to CIImage")
//            return
//        }
//        
//        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
//        do {
//            try handler.perform([request])
//            print("Vision request performed")
//        } catch {
//            print("Failed to perform Vision request: \(error)")
//        }
//    }
//
//
//    func maskBackground(from image: UIImage, using pixelBuffer: CVPixelBuffer) -> UIImage? {
//        let maskImage = UIImage(pixelBuffer: pixelBuffer)
//        
//        guard let cgImage = image.cgImage else {
//            print("Failed to get CGImage from original image")
//            return nil
//        }
//        let width = cgImage.width
//        let height = cgImage.height
//        
//        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
//        guard let context = UIGraphicsGetCurrentContext() else {
//            print("Failed to get graphics context")
//            return nil
//        }
//        
//        guard let maskCGImage = maskImage?.cgImage else {
//            print("Failed to get CGImage from mask image")
//            return nil
//        }
//        
//        context.clip(to: CGRect(x: 0, y: 0, width: width, height: height), mask: maskCGImage)
//        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
//        
//        let result = UIGraphicsGetImageFromCurrentImageContext()
//        UIGraphicsEndImageContext()
//        
//        if let result = result {
//            print("Background removal result image created successfully")
//        } else {
//            print("Failed to create result image")
//        }
//        
//        return result
//    }
//
//    func convertToSRGB(image: UIImage) -> UIImage? {
//        guard let cgImage = image.cgImage else {
//            print("Failed to get CGImage from original image")
//            return nil
//        }
//
//        // sRGB 색상 공간 생성
//        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
//        
//        // 새 컨텍스트 생성 (sRGB로 변환하기 위함)
//        let context = CGContext(data: nil,
//                                width: cgImage.width,
//                                height: cgImage.height,
//                                bitsPerComponent: cgImage.bitsPerComponent,
//                                bytesPerRow: cgImage.bytesPerRow,
//                                space: colorSpace,
//                                bitmapInfo: cgImage.bitmapInfo.rawValue)
//        
//        // 컨텍스트가 생성되었는지 확인
//        guard let newContext = context else {
//            print("Failed to create new context for sRGB conversion")
//            return nil
//        }
//        
//        // 기존 이미지 그리기
//        newContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
//        
//        // 새 이미지를 생성
//        guard let newCGImage = newContext.makeImage() else {
//            print("Failed to create new CGImage after sRGB conversion")
//            return nil
//        }
//        
//        print("Image successfully converted to sRGB")
//        return UIImage(cgImage: newCGImage)
//    }
//    func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage? {
//        let size = image.size
//        let widthRatio  = targetSize.width  / size.width
//        let heightRatio = targetSize.height / size.height
//
//        // Determine what scale factor to use to maintain aspect ratio
//        let scaleFactor = min(widthRatio, heightRatio)
//
//        let scaledImageSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
//
//        UIGraphicsBeginImageContextWithOptions(scaledImageSize, false, 0.0)
//        image.draw(in: CGRect(origin: .zero, size: scaledImageSize))
//        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
//        UIGraphicsEndImageContext()
//
//        return resizedImage
//    }
//
//}
//
//struct ImagePicker: UIViewControllerRepresentable {
//    @Binding var image: UIImage?
//    
//    func makeUIViewController(context: Context) -> UIImagePickerController {
//        let picker = UIImagePickerController()
//        picker.delegate = context.coordinator
//        return picker
//    }
//    
//    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
//
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self)
//    }
//    
//    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
//        let parent: ImagePicker
//        
//        init(_ parent: ImagePicker) {
//            self.parent = parent
//        }
//        
//        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
//            if let uiImage = info[.originalImage] as? UIImage {
//                parent.image = uiImage
//                print("ImagePicker: Image selected successfully")
//            } else {
//                print("ImagePicker: Failed to select an image")
//            }
//            picker.dismiss(animated: true)
//        }
//    }
//}
//
//extension UIImage {
//    convenience init?(pixelBuffer: CVPixelBuffer) {
//        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
//        let context = CIContext()
//        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
//        self.init(cgImage: cgImage)
//    }
//}
//
