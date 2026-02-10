//
//  ContentGridView.swift
//  Pipit
//
//  Grid view displaying content from selected creator
//

import SwiftUI

struct ContentGridView: View {
    @Bindable var viewModel: AppViewModel
    
    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 20)
    ]
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.contentFeed.isEmpty {
                ProgressView("Loading content...")
            } else if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
            } else if viewModel.contentFeed.isEmpty {
                emptyStateView
            } else {
                contentGrid
            }
        }
        .navigationTitle(navigationTitle)
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
    }
    
    private var navigationTitle: String {
        guard let creator = viewModel.selectedCreator else {
            return "Content"
        }
        
        if let selectedChannel = viewModel.selectedChannel {
            // Specific channel selected
            if creator.channels.count > 1 {
                return "\(creator.title) - \(selectedChannel.title)"
            } else {
                return creator.title
            }
        } else {
            // No channel selected - showing all content
            return creator.title
        }
    }
    
    private var contentGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(viewModel.contentFeed, id: \.id) { post in
                    NavigationLink {
                        PostDetailView(post: post)
                    } label: {
                        PostCardView(post: post)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.loadContentForSelectedChannel()
        }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Content", systemImage: "video.slash")
        } description: {
            Text("No content available for this creator")
        }
    }
    
    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task {
                    await viewModel.loadContentForSelectedChannel()
                }
            }
        }
    }
}

struct PostCardView: View {
    let post: Components.Schemas.BlogPostModelV3
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            thumbnailView
            
            // Content info
            VStack(alignment: .leading, spacing: 6) {
                Text(post.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)
                
                Text(post.releaseDate, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
#if os(iOS)
        .background(Color(uiColor: .secondarySystemBackground))
#else
        .background(Color(nsColor: .controlBackgroundColor))
#endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    }
    
    private var thumbnailView: some View {
        Group {
            if let thumbnail = post.thumbnail {
                CachedAsyncImage(url: thumbnail.value1.url(width: 800, height: 450)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    placeholderThumbnail
                }
            } else {
                placeholderThumbnail
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16/9, contentMode: .fit)
        .clipped()
    }
    
    private var placeholderThumbnail: some View {
        ZStack {
            Color.gray.opacity(0.3)
            Image(systemName: "video.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        ContentGridView(viewModel: AppViewModel(sailsSid: nil))
    }
}
