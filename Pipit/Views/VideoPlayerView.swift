//
//  VideoPlayerView.swift
//  Pipit
//
//  Video player for Floatplane content
//

import SwiftUI
import AVKit
import AVFoundation

struct VideoPlayerView: View {
    let post: Components.Schemas.BlogPostModelV3
    @State private var player: AVPlayer?
    #if os(iOS)
    @State private var playerViewController: AVPlayerViewController?
    #endif
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedVideoIndex = 0
    @State private var selectedQualityIndex: Int?
    @State private var availableQualities: [Components.Schemas.CdnDeliveryV3Variant] = []
    @State private var currentOriginURL: String = ""
    @State private var videoDetails: [Components.Schemas.ContentVideoV3Response] = []
    @State private var hasAppliedDefaultQuality = false
    @AppStorage("defaultVideoQuality") private var defaultVideoQuality: String = "auto"
    @Environment(\.floatplaneAPI) private var apiService
    
    private var videoAttachments: [String] {
        guard let videos = post.videoAttachments else { return [] }
        
        // Use attachmentOrder to sort videos in the correct order
        let attachmentOrder = post.attachmentOrder
        if !attachmentOrder.isEmpty {
            // Filter attachmentOrder to only include videos, maintaining order
            let orderedVideos = attachmentOrder.filter { videos.contains($0) }
            // Add any videos not in attachmentOrder at the end
            let remainingVideos = videos.filter { !orderedVideos.contains($0) }
            return orderedVideos + remainingVideos
        }
        
        return videos
    }
    
    private var hasMultipleVideos: Bool {
        videoAttachments.count > 1
    }
    
    private var thumbnailPlaceholder: some View {
        Group {
            if selectedVideoIndex < videoDetails.count {
                let thumbnail = videoDetails[selectedVideoIndex].thumbnail
                CachedAsyncImage(url: thumbnail.url(width: 1280, height: 720)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .aspectRatio(16/9, contentMode: .fit)
                .frame(maxWidth: .infinity)
            } else {
                // Fallback to simple placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    #if os(iOS)
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback)
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    #endif
    
    var body: some View {
        VStack(spacing: 0) {
            // Video player
            ZStack {
                if let errorMessage = errorMessage {
                    errorView(message: errorMessage)
                } else if let player = player {
                    #if os(iOS)
                    CustomVideoPlayer(player: player, playerViewController: $playerViewController)
                        .aspectRatio(16/9, contentMode: .fit)
                        .onAppear {
                            configureAudioSession()
                        }
                    #else
                    MacOSVideoPlayerWithControls(player: player)
                        .aspectRatio(16/9, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                    #endif
                } else {
                    // Initial loading state - show thumbnail if available
                    thumbnailPlaceholder
                }
                
                // Loading overlay for video switches
                if isLoading {
                    Color.black.opacity(0.5)
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                        )
                }
            }
            
            // Quality selector bar
            if !availableQualities.isEmpty && !isLoading {
                HStack {
                    Text("Quality:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    qualitySelector
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                #if os(iOS)
                .background(Color(uiColor: .secondarySystemBackground))
                #else
                .background(Color(nsColor: .controlBackgroundColor))
                #endif
            }
            
            // Video selector for multiple videos
            if hasMultipleVideos {
                videoSelector
            }
        }
        .task {
            await loadVideoDetails()
        }
        .task(id: selectedVideoIndex) {
            await loadVideo()
        }
        .task(id: selectedQualityIndex) {
            if selectedQualityIndex != nil {
                await switchQuality()
            }
        }
    }
    
    private var qualitySelector: some View {
        Menu {
            // Auto quality option
            Button {
                selectedQualityIndex = nil
            } label: {
                HStack {
                    Text("Auto (Recommended)")
                    if selectedQualityIndex == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Divider()
            
            // Manual quality options
            ForEach(Array(availableQualities.enumerated().reversed()), id: \.offset) { index, variant in
                Button {
                    selectedQualityIndex = index
                } label: {
                    HStack {
                        Text(variant.label ?? "Quality \(index + 1)")
                        if selectedQualityIndex == index {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                if let selectedIndex = selectedQualityIndex,
                   selectedIndex < availableQualities.count {
                    let label = availableQualities[selectedIndex].label ?? "Quality \(selectedIndex + 1)"
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                } else {
                    Text("Auto")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
    
    private var videoSelector: some View {
        VStack(spacing: 8) {
            Divider()
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(videoAttachments.enumerated()), id: \.offset) { index, videoId in
                        Button {
                            selectedVideoIndex = index
                        } label: {
                            VideoSelectorButton(
                                index: index,
                                videoDetail: videoDetails.indices.contains(index) ? videoDetails[index] : nil,
                                isSelected: selectedVideoIndex == index
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
        }
        #if os(iOS)
        .background(Color(uiColor: .secondarySystemBackground))
        #else
        .background(Color(nsColor: .controlBackgroundColor))
        #endif
    }
    
    private func switchQuality() async {
        guard !currentOriginURL.isEmpty else {
            return
        }
        
        // Save current playback position
        let currentTime = await player?.currentTime()
        let wasPlaying = await player?.rate != 0
        
        // Determine which URL to use
        let videoURLString: String
        
        if let qualityIndex = selectedQualityIndex, qualityIndex < availableQualities.count {
            // Manual quality selection
            let selectedVariant = availableQualities[qualityIndex]
            videoURLString = currentOriginURL + selectedVariant.url
        } else {
            // Auto mode - use master playlist or highest quality
            if let masterVariant = availableQualities.first(where: { variant in
                variant.url.contains("master") || 
                (variant.url.hasSuffix(".m3u8") && !variant.url.contains("/\(variant.name ?? "")"))
            }) {
                videoURLString = currentOriginURL + masterVariant.url
            } else {
                let highestQuality = availableQualities.last ?? availableQualities[0]
                videoURLString = currentOriginURL + highestQuality.url
            }
        }
        
        guard let videoURL = URL(string: videoURLString) else {
            return
        }
        
        // Create new player with the new quality
        let newPlayer = AVPlayer(url: videoURL)
        
        // Restore playback position
        if let currentTime = currentTime {
            await newPlayer.seek(to: currentTime)
        }
        
        // Resume playback if it was playing
        if wasPlaying {
            newPlayer.play()
        }
        
        await MainActor.run {
            self.player = newPlayer
        }
    }
    
    private func getDefaultQualityIndex(from variants: [Components.Schemas.CdnDeliveryV3Variant]) -> Int? {
        // "auto" means nil (adaptive streaming)
        if defaultVideoQuality == "auto" {
            return nil
        }
        
        // Helper function to check if a variant matches a quality level
        func variantMatches(_ variant: Components.Schemas.CdnDeliveryV3Variant, _ quality: String) -> Bool {
            let label = variant.label.lowercased()
            if quality == "2160p" {
                // 4K can be labeled as either "4k" or "2160p"
                return label.contains("4k") || label.contains("2160p")
            }
            return label.contains(quality.lowercased())
        }
        
        // Try to find exact matching quality by label
        if let index = variants.firstIndex(where: { variant in
            variantMatches(variant, defaultVideoQuality)
        }) {
            return index
        }
        
        // Preferred quality not available - find next highest quality
        // Define quality hierarchy (higher index = higher quality)
        let qualityHierarchy = ["360p", "480p", "720p", "1080p", "2160p"]
        
        guard let preferredIndex = qualityHierarchy.firstIndex(of: defaultVideoQuality) else {
            // Unknown quality preference, fallback to auto
            return nil
        }
        
        // Try to find the next highest quality going down from preferred
        for targetQuality in qualityHierarchy[..<preferredIndex].reversed() {
            if let index = variants.firstIndex(where: { variant in
                variantMatches(variant, targetQuality)
            }) {
                return index
            }
        }
        
        // If no lower quality found, try higher qualities
        for targetQuality in qualityHierarchy[(preferredIndex + 1)...] {
            if let index = variants.firstIndex(where: { variant in
                variantMatches(variant, targetQuality)
            }) {
                return index
            }
        }
        
        // Fallback to highest available quality
        return variants.count - 1
    }
    
    private func loadVideoDetails() async {
        // Fetch details for all videos in parallel
        await withTaskGroup(of: (Int, Components.Schemas.ContentVideoV3Response?).self) { group in
            for (index, videoId) in videoAttachments.enumerated() {
                group.addTask {
                    do {
                        let details = try await apiService?.getVideoContent(videoId: videoId)
                        return (index, details)
                    } catch {
                        print("Failed to load video details for \(videoId): \(error)")
                        return (index, nil)
                    }
                }
            }
            
            var detailsArray: [Components.Schemas.ContentVideoV3Response?] = Array(repeating: nil, count: videoAttachments.count)
            for await (index, detail) in group {
                detailsArray[index] = detail
            }
            
            await MainActor.run {
                self.videoDetails = detailsArray.compactMap { $0 }
            }
        }
    }
    
    private func loadVideo() async {
        guard !videoAttachments.isEmpty,
              selectedVideoIndex < videoAttachments.count else {
            errorMessage = "No video available for this post"
            isLoading = false
            return
        }
        
        // Show loading overlay (but keep player visible if it exists)
        await MainActor.run {
            // Only set isLoading to true if we don't have a player yet
            // This prevents the view from collapsing when switching videos
            if self.player != nil {
                self.isLoading = true
            } else {
                self.isLoading = true
            }
            errorMessage = nil
        }
        
        let selectedVideo = videoAttachments[selectedVideoIndex]
        
        do {
            // Get video delivery info from Floatplane CDN
            let deliveryInfo = try await apiService?.getDeliveryInfo(
                entityId: selectedVideo,
                scenario: .onDemand
            )
            
            guard let groups = deliveryInfo?.groups,
                  let firstGroup = groups.first,
                  let origins = firstGroup.origins,
                  let firstOrigin = origins.first else {
                errorMessage = "Could not retrieve video delivery information"
                isLoading = false
                return
            }
            
            // Store available qualities and origin
            let variants = firstGroup.variants
            await MainActor.run {
                self.availableQualities = variants
                self.currentOriginURL = firstOrigin.url
                
                // Apply default quality preference on first load
                if !self.hasAppliedDefaultQuality {
                    self.selectedQualityIndex = self.getDefaultQualityIndex(from: variants)
                    self.hasAppliedDefaultQuality = true
                }
            }
            
            // Determine which URL to use based on quality selection
            let videoURLString: String
            let qualityIndex = await MainActor.run { selectedQualityIndex }
            
            if let qualityIndex = qualityIndex, qualityIndex < variants.count {
                // Manual quality selection - use specific variant
                let selectedVariant = variants[qualityIndex]
                videoURLString = firstOrigin.url + selectedVariant.url
            } else {
                // Auto mode - look for master playlist or use highest quality
                // HLS master playlists typically have "master" or end with just .m3u8
                if let masterVariant = variants.first(where: { variant in
                    variant.url.contains("master") || 
                    (variant.url.hasSuffix(".m3u8") && !variant.url.contains("/\(variant.name ?? "")"))
                }) {
                    // Found master playlist for adaptive streaming
                    videoURLString = firstOrigin.url + masterVariant.url
                } else {
                    // Fallback to highest quality variant
                    let highestQuality = variants.last ?? variants[0]
                    videoURLString = firstOrigin.url + highestQuality.url
                }
            }
            
            guard let videoURL = URL(string: videoURLString) else {
                errorMessage = "Invalid video URL"
                isLoading = false
                return
            }
            
            // Create AVPlayer with the video URL
            let newPlayer = AVPlayer(url: videoURL)
            await MainActor.run {
                self.player = newPlayer
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load video: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16/9, contentMode: .fit)
        .padding()
    }
}

// MARK: - Video Selector Button

struct VideoSelectorButton: View {
    let index: Int
    let videoDetail: Components.Schemas.ContentVideoV3Response?
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Thumbnail
            if let thumbnail = videoDetail?.thumbnail {
                CachedAsyncImage(url: thumbnail.url(width: 160, height: 90)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 80, height: 45)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
            }
            
            // Title and info
            VStack(alignment: .leading, spacing: 4) {
                Text(videoDetail?.title ?? "Video \(index + 1)")
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if let duration = videoDetail?.duration {
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 200, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - macOS Video Player with AVPlayerView

#if os(macOS)
import AppKit

struct MacOSVideoPlayerWithControls: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> ContainerView {
        let container = ContainerView()
        let playerView = AVPlayerView()
        playerView.player = player
        playerView.controlsStyle = .floating
        playerView.showsFullScreenToggleButton = true
        playerView.allowsPictureInPicturePlayback = true
        playerView.showsSharingServiceButton = false
        
        playerView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(playerView)
        
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: container.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            playerView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        
        container.playerView = playerView
        return container
    }
    
    func updateNSView(_ nsView: ContainerView, context: Context) {
        nsView.playerView?.player = player
    }
    
    class ContainerView: NSView {
        var playerView: AVPlayerView?
        
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
#endif

// MARK: - Custom Video Player for iOS (with PiP support)

#if os(iOS)
struct CustomVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    @Binding var playerViewController: AVPlayerViewController?
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        
        // Enable Picture-in-Picture
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        
        // Enable fullscreen controls
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        
        // Show playback controls
        controller.showsPlaybackControls = true
        
        // Store reference for later updates
        DispatchQueue.main.async {
            self.playerViewController = controller
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}
#endif

// Environment key for FloatplaneAPIService
private struct FloatplaneAPIKey: EnvironmentKey {
    static let defaultValue: FloatplaneAPIService? = nil
}

extension EnvironmentValues {
    var floatplaneAPI: FloatplaneAPIService? {
        get { self[FloatplaneAPIKey.self] }
        set { self[FloatplaneAPIKey.self] = newValue }
    }
}
