//
//  PlayerView.swift
//  Pipit
//
//  Created by Ryan Morash on 1/28/24.
//

import SwiftUI
import AVFoundation
import AVKit

struct PlayerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> some UIViewController {
        let controller = AVPlayerViewController()
        controller.player = AVPlayer()
        controller.player?.replaceCurrentItem(with: AVPlayerItem(url: itemURL))
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        
    }
}
