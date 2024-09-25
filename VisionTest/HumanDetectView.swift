import SwiftUI
import Vision
import PhotosUI

struct HumanDetectView: View {
    @State private var selectedImageItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var observations: [VNHumanObservation] = []
    
    var body: some View {
        VStack {
            if let image = selectedImage {
                GeometryReader { geometry in
                    let imageSize = CGSize(width: image.size.width, height: image.size.height)
                    let displaySize = self.getFittedImageSize(imageSize: imageSize, containerSize: geometry.size)
                    
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: displaySize.width, height: displaySize.height)
                        .overlay(
                            ForEach(observations, id: \.self) { observation in
                                HumanRectangleOverlay(observation: observation, imageSize: imageSize, displaySize: displaySize)
                                    .stroke(Color.red, lineWidth: 2)
                            }
                        )
                        .clipped()
                }
            } else {
                Text("사진을 선택해주세요")
                    .padding()
            }
            
            PhotosPicker(selection: $selectedImageItem, matching: .images) {
                Text("사진 선택하기")
            }
            .onChange(of: selectedImageItem) { newItem in
                if let newItem = newItem {
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            selectedImage = uiImage
                            detectHumans(in: uiImage)
                        }
                    }
                }
            }
        }
    }
    
    func detectHumans(in image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        let request = VNDetectHumanRectanglesRequest { request, error in
            guard let results = request.results as? [VNHumanObservation], error == nil else {
                print("Error detecting humans: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                self.observations = results
            }
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform detection: \(error.localizedDescription)")
            }
        }
    }
    
    func getFittedImageSize(imageSize: CGSize, containerSize: CGSize) -> CGSize {
        let imageAspectRatio = imageSize.width / imageSize.height
        let containerAspectRatio = containerSize.width / containerSize.height
        
        if imageAspectRatio > containerAspectRatio {
            let width = containerSize.width
            let height = width / imageAspectRatio
            return CGSize(width: width, height: height)
        } else {
            let height = containerSize.height
            let width = height * imageAspectRatio
            return CGSize(width: width, height: height)
        }
    }
}

struct HumanRectangleOverlay: Shape {
    let observation: VNHumanObservation
    let imageSize: CGSize
    let displaySize: CGSize
    
    func path(in rect: CGRect) -> Path {
        let boundingBox = observation.boundingBox
        
        // 이미지 내에서의 좌표로 변환
        let x = boundingBox.origin.x * displaySize.width
        let y = (1 - boundingBox.origin.y - boundingBox.height) * displaySize.height
        let width = boundingBox.width * displaySize.width
        let height = boundingBox.height * displaySize.height
        
        var path = Path()
        path.addRect(CGRect(x: x, y: y, width: width, height: height))
        return path
    }
}
