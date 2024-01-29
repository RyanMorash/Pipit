//
//  PipitApp.swift
//  Pipit
//
//  Created by Ryan Morash on 1/28/24.
//

import SwiftUI

@main
struct PipitApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
        }.immersionStyle(selection: .constant(.full), in: .full)
    }
}
