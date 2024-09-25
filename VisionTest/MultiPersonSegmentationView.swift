import SwiftUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

struct MultiPersonSegmentationView: View {
    @State private var selectedImage: UIImage? = nil
    @State private var personImages: [UIImage] = []
    @State private var showImagePicker = false
    
    var body: some View {
        VStack {
            if personImages.isEmpty {
                Text("Select an image with multiple people")
                    .padding()
            } else {
                TabView {
                    ForEach(personImages, id: \.self) { personImage in
                        Image(uiImage: personImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.7))
                            .padding()
                    }
                }
                .tabViewStyle(PageTabViewStyle())
            }
            
            Button("Choose Image") {
                showImagePicker.toggle()
            }
            .padding()
        }
        .sheet(isPresented: $showImagePicker) {
            MultiImagePicker(sourceType: .photoLibrary) { image in
                self.selectedImage = image
                if let selectedImage = selectedImage {
                    processImage(selectedImage)
                }
            }
        }
    }
    
    // 이미지 처리 및 개별 사람 분리
    func processImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }

        // 사람 사각형 감지
        let detectPeopleRequest = VNDetectHumanRectanglesRequest { (request, error) in
            guard let results = request.results as? [VNHumanObservation] else { return }
            var individualPersonImages: [UIImage] = []
            
            // 세그멘테이션 요청
            let segmentationRequest = VNGeneratePersonSegmentationRequest()
            segmentationRequest.qualityLevel = .accurate // 정확한 인식을 위해 accurate 설정
            segmentationRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8


            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try requestHandler.perform([segmentationRequest])
                
                if let segmentationResult = segmentationRequest.results?.first as? VNPixelBufferObservation {
                    let pixelBuffer = segmentationResult.pixelBuffer
                    
                    // 각 사람의 사각형에 맞춰 이미지 및 마스크 분리
                    for person in results {
                        let boundingBox = person.boundingBox
                        if let croppedPersonImage = cropPersonFromImage(cgImage, boundingBox: boundingBox, mask: pixelBuffer) {
                            individualPersonImages.append(croppedPersonImage)
                        }
                    }
                    
                    DispatchQueue.main.async {
                        personImages = individualPersonImages
                    }
                }
            } catch {
                print("Error performing segmentation: \(error)")
            }
        }

        // 요청 실행
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try requestHandler.perform([detectPeopleRequest])
        } catch {
            print("Error detecting human rectangles: \(error)")
        }
    }
    
    // 사람 마스크 크롭 및 배경 제거 처리
    func cropPersonFromImage(_ originalImage: CGImage, boundingBox: CGRect, mask: CVPixelBuffer) -> UIImage? {
        let originalCIImage = CIImage(cgImage: originalImage)

        // 픽셀 버퍼에서 너비와 높이 가져오기
        let width = CGFloat(CVPixelBufferGetWidth(mask))
        let height = CGFloat(CVPixelBufferGetHeight(mask))
        
        // boundingBox를 이미지 좌표로 변환 (Y좌표 반전)
        let cropRect = CGRect(
            x: boundingBox.origin.x * width,
            y: (1 - boundingBox.origin.y - boundingBox.height) * height, // Y좌표는 상하 반전
            width: boundingBox.width * width,
            height: boundingBox.height * height
        )

        // 원본 이미지 크롭
        let croppedCIImage = originalCIImage.cropped(to: cropRect)

        // 마스크 이미지 크롭
        let maskCIImage = CIImage(cvPixelBuffer: mask).cropped(to: cropRect)

        // 마스크를 원본 이미지에 적용
        let maskedImage = croppedCIImage.applyingFilter("CIBlendWithMask", parameters: [
            "inputMaskImage": maskCIImage
        ])

        let context = CIContext()
        if let outputCGImage = context.createCGImage(maskedImage, from: maskedImage.extent) {
            return UIImage(cgImage: outputCGImage)
        }
        return nil
    }

}

// UIImagePickerController를 위한 UIViewControllerRepresentable
struct MultiImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    var completionHandler: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: MultiImagePicker
        
        init(_ parent: MultiImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.completionHandler(image)
            }
            picker.dismiss(animated: true)
        }
    }
}
