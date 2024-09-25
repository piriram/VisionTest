import SwiftUI
import Vision
import PhotosUI

struct HumanDetectView: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var uiImage: UIImage? = nil
    @State private var humanBoxes: [CGRect] = []
    
    var body: some View {
        VStack {
            PhotosPicker(
                selection: $selectedItem,
                matching: .images
            ) {
                Text("Select a group photo")
            }
            .onChange(of: selectedItem) { newItem in
                // Handle the change in selectedItem
                Task {
                    if let newItem = newItem {
                        // Load the image after selection
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            uiImage = image
                            detectHumans(in: image)
                        }
                    }
                }
            }

            if let uiImage = uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .overlay(detectionOverlay)
                    .frame(height: 400)
            }
        }
        .padding()
    }

    private var detectionOverlay: some View { //2
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
                        y: (1 - box.midY) * geometry.size.height  // Adjust Y coordinate
                    )
            }
        }
    }

    private func detectHumans(in image: UIImage) { //1
        guard let cgImage = image.cgImage else { return }
        
        
        let request = VNDetectHumanRectanglesRequest()
        request.revision = VNDetectHumanRectanglesRequestRevision2
        request.upperBodyOnly = false
        
        // 단일 이미지와 관련된 하나 이상의 이미지 분석 요청을 처리하는 객체 생성
        // options : `보조 이미지 데이터`로 이미지 분석을 수행할 때 추가적인 정보나 데이터를 제공할 수 있다.
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            // 결과가 nil일 경우를 처리하는 guard 구문 수정
            guard let results = request.results else {
                print("No results or results are not of type VNHumanObservation")
                return
            }
            
            // Extract human bounding boxes
            humanBoxes = results.map { observation in
                let boundingBox = observation.boundingBox
                return CGRect(
                    x: boundingBox.origin.x,
                    y: boundingBox.origin.y,
                    width: boundingBox.size.width,
                    height: boundingBox.size.height
                )
            }
        } catch {
            print("Failed to perform request: \(error)")
        }

    }
}
