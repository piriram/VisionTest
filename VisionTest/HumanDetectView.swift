import SwiftUI
import Vision
import PhotosUI

struct HumanDetectView: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var uiImage: UIImage? = nil
    @State private var humanBoxes: [CGRect] = []
    @State private var croppedImages: [UIImage] = [] // 크롭된 이미지 배열 추가
    
    var body: some View {
        VStack {
            PhotosPicker(
                selection: $selectedItem,
                matching: .images
            ) {
                Text("Select a group photo")
            }
            .onChange(of: selectedItem) { newItem in
                Task {
                    if let newItem = newItem {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            uiImage = image
                            detectHumans(in: image)
                        }
                    }
                }
            }

            if let uiImage = uiImage {
                TabView {
                    ForEach(croppedImages.indices, id: \.self) { index in
                        Image(uiImage: croppedImages[index])
                            .resizable()
                            .scaledToFit()
                            .frame(height: 400)
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .frame(height: 400) // 탭 뷰의 높이를 설정
            }
        }
        .padding()
    }

    private var detectionOverlay: some View {
        GeometryReader { geometry in
            ForEach(humanBoxes, id: \.self) { box in
                Rectangle()
                    .stroke(Color.red, lineWidth: 2)
                    .frame(
                        width: box.width * geometry.size.width,
                        height: box.height * geometry.size.height
                    )
                    .position(
                        x: box.midX * geometry.size.width,
                        y: (1 - box.midY) * geometry.size.height  // Y 좌표 조정
                    )
            }
        }
    }

    private func detectHumans(in image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        let request = VNDetectHumanRectanglesRequest()
        request.revision = VNDetectHumanRectanglesRequestRevision2
        request.upperBodyOnly = false
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let results = request.results as? [VNHumanObservation] else {
                print("No results or results are not of type VNHumanObservation")
                return
            }
            
            // Extract human bounding boxes and crop images
            humanBoxes = results.map { observation in
                let boundingBox = observation.boundingBox
                let rect = CGRect(
                    x: boundingBox.origin.x,
                    y: boundingBox.origin.y,
                    width: boundingBox.size.width,
                    height: boundingBox.size.height
                )
                
                // 크롭된 이미지를 배열에 추가
                if let croppedImage = cropImage(from: image, rect: rect) {
                    croppedImages.append(croppedImage)
                }
                
                return rect
            }
        } catch {
            print("Failed to perform request: \(error)")
        }
    }
    
    private func cropImage(from image: UIImage, rect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        // 크롭 영역을 이미지의 좌표계에 맞게 조정
        let width = rect.size.width * CGFloat(cgImage.width)
        let height = rect.size.height * CGFloat(cgImage.height)
        let x = rect.origin.x * CGFloat(cgImage.width)
        let y = (1 - rect.origin.y - rect.size.height) * CGFloat(cgImage.height) // Y 좌표 변환
        
        let cropRect = CGRect(x: x, y: y, width: width, height: height).integral
        
        guard let croppedCgImage = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: croppedCgImage)
    }
}
