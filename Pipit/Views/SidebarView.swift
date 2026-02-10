//
//  SidebarView.swift
//  Pipit
//
//  Sidebar navigation showing subscribed creators
//

import SwiftUI

struct SidebarView: View {
    @Bindable var viewModel: AppViewModel
    
    var body: some View {
        List(selection: $viewModel.selectedChannel) {
            Section("Subscriptions") {
                ForEach(viewModel.creators) { creator in
                    if creator.channels.count == 1 {
                        // Single channel - show creator directly
                        NavigationLink(value: creator.channels[0]) {
                            CreatorRowView(creator: creator)
                        }
                    } else {
                        // Multiple channels - show as disclosure group with clickable header
                        DisclosureGroup {
                            ForEach(creator.channels) { channel in
                                NavigationLink(value: channel) {
                                    ChannelRowView(channel: channel)
                                }
                            }
                        } label: {
                            Button {
                                viewModel.selectCreator(creator)
                            } label: {
                                CreatorRowView(creator: creator)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("Floatplane")
        .onChange(of: viewModel.selectedChannel) { oldValue, newValue in
            if let newChannel = newValue {
                // Update selected creator when channel changes
                if viewModel.selectedCreator?.id != newChannel.creatorId {
                    viewModel.selectedCreator = viewModel.creators.first { $0.id == newChannel.creatorId }
                }
                viewModel.selectChannel(newChannel)
            }
        }
#if os(macOS)
        .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
#endif
    }
}

struct CreatorRowView: View {
    let creator: CreatorInfo
    
    var body: some View {
        HStack(spacing: 12) {
            // Creator icon
            CachedAsyncImage(url: creator.icon.thumbnailURL, priority: .icon) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(creator.title)
                    .font(.body)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ChannelRowView: View {
    let channel: ChannelInfo
    
    var body: some View {
        HStack(spacing: 12) {
            // Channel icon
            CachedAsyncImage(url: channel.icon.thumbnailURL, priority: .icon) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 28, height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            Text(channel.title)
                .font(.subheadline)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .padding(.leading, 8)
    }
}

#Preview {
    NavigationSplitView {
        SidebarView(viewModel: AppViewModel(sailsSid: nil))
    } detail: {
        Text("Select a creator")
    }
}
