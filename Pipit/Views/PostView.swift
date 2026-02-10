//
//  PostView.swift
//  Pipit
//
//  Post detail view
//

import SwiftUI

struct PostDetailView: View {
    let post: Components.Schemas.BlogPostModelV3
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Video player or thumbnail
                if let videoAttachments = post.videoAttachments, !videoAttachments.isEmpty {
                    VideoPlayerView(post: post)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if let thumbnail = post.thumbnail {
                    AsyncImage(url: thumbnail.value1.url(width: 1920, height: 1080)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(16/9, contentMode: .fit)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    // Title
                    Text(post.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // Metadata
                    HStack {
                        Label(post.creator.title, systemImage: "person.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text(post.releaseDate, style: .date)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    // Description
                    if !post.text.isEmpty {
                        HTMLTextView(post.text, font: .body)
                    }
                    
                    // Stats
                    HStack(spacing: 20) {
                        Label("\(post.likes)", systemImage: "hand.thumbsup")
                        Label("\(post.dislikes)", systemImage: "hand.thumbsdown")
                        Label("\(post.comments)", systemImage: "bubble.left")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Post")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

