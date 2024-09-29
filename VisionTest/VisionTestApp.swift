//
//  VisionTestApp.swift
//  VisionTest
//
//  Created by ram on 9/20/24.
//

import SwiftUI

@main
struct VisionTestApp: App {
    var body: some Scene {
        WindowGroup {
//            HumanDetectView()
//            MultiPersonSegmentationView()
//            RemoveBackgroundView()
            HumanDetectView()//사람을 개별을 탐지해서 사각형으로 잘라주는 방법
            
        }
    }
}
