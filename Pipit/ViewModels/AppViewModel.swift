//
//  AppViewModel.swift
//  Pipit
//
//  Main app view model managing creators and content
//

import Foundation
import SwiftUI

@Observable
class AppViewModel {
    var apiService: FloatplaneAPIService?
    var subscriptions: [Components.Schemas.UserSubscriptionModel] = []
    var creators: [CreatorInfo] = []
    var selectedCreator: CreatorInfo? {
        didSet {
            // Save selected creator ID
            if let creatorId = selectedCreator?.id {
                UserDefaults.standard.set(creatorId, forKey: "lastSelectedCreatorId")
            }
        }
    }
    var selectedChannel: ChannelInfo? {
        didSet {
            // Save selected channel ID (or remove if nil)
            if let channelId = selectedChannel?.id {
                UserDefaults.standard.set(channelId, forKey: "lastSelectedChannelId")
            } else {
                UserDefaults.standard.removeObject(forKey: "lastSelectedChannelId")
            }
        }
    }
    var contentFeed: [Components.Schemas.BlogPostModelV3] = []
    var isLoading = false
    var errorMessage: String?
    
    init(sailsSid: String?) {
        if let sailsSid, !sailsSid.isEmpty {
            self.apiService = FloatplaneAPIService(sailsSid: sailsSid)
        }
    }
    
    func loadCreators() async {
        guard let apiService else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Get user subscriptions
            subscriptions = try await apiService.listUserSubscriptions()
            
            // Get creator details for each subscription
            var loadedCreators: [CreatorInfo] = []
            for subscription in subscriptions {
                do {
                    let creator = try await apiService.getCreator(creatorId: subscription.creator)
                    let channels = creator.channels
                        .sorted { ($0.order ?? Int.max) < ($1.order ?? Int.max) }
                        .map { channel in
                            ChannelInfo(
                                id: channel.id,
                                title: channel.title,
                                urlname: channel.urlname,
                                creatorId: creator.id,
                                icon: channel.icon
                            )
                        }
                    
                    loadedCreators.append(CreatorInfo(
                        id: creator.id,
                        title: creator.title,
                        urlname: creator.urlname,
                        description: creator.description,
                        icon: creator.icon,
                        channels: channels,
                        defaultChannelId: creator.defaultChannel
                    ))
                } catch {
                    print("Failed to load creator \(subscription.creator): \(error)")
                }
            }
            
            creators = loadedCreators.sorted { $0.title < $1.title }
            
            // Restore last selected creator/channel, or select first creator
            await restoreOrSelectInitial()
        } catch {
            errorMessage = "Failed to load creators: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func loadContentForSelectedChannel() async {
        guard let apiService, let selectedCreator else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.getMultiCreatorBlogPosts(
                creatorIds: [selectedCreator.id],
                limit: 50
            )
            
            // Filter by selected channel if one is selected, otherwise show all
            if let selectedChannel {
                contentFeed = response.blogPosts.filter { post in
                    switch post.channel {
                    case .ChannelModel(let channelModel):
                        return channelModel.id == selectedChannel.id
                    case .case2(let channelId):
                        return channelId == selectedChannel.id
                    }
                }
            } else {
                // No specific channel selected, show all content from this creator
                contentFeed = response.blogPosts
            }
        } catch {
            errorMessage = "Failed to load content: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func selectCreator(_ creator: CreatorInfo) {
        selectedCreator = creator
        // Clear channel selection to show all creator content
        selectedChannel = nil
        Task {
            await loadContentForSelectedChannel()
        }
    }
    
    func selectChannel(_ channel: ChannelInfo) {
        selectedChannel = channel
        Task {
            await loadContentForSelectedChannel()
        }
    }
    
    // MARK: - Private Helpers
    
    private func restoreOrSelectInitial() async {
        guard selectedCreator == nil else { return }
        
        // Try to restore last selected creator and channel
        let lastCreatorId = UserDefaults.standard.string(forKey: "lastSelectedCreatorId")
        let lastChannelId = UserDefaults.standard.string(forKey: "lastSelectedChannelId")
        
        if let lastCreatorId,
           let creator = creators.first(where: { $0.id == lastCreatorId }) {
            // Restore previously selected creator
            selectedCreator = creator
            
            if let lastChannelId,
               let channel = creator.channels.first(where: { $0.id == lastChannelId }) {
                // Restore previously selected channel
                selectedChannel = channel
            } else {
                // No channel was selected (was viewing all content)
                selectedChannel = nil
            }
            
            await loadContentForSelectedChannel()
        } else if let first = creators.first {
            // First launch - select first creator, show all content
            selectedCreator = first
            selectedChannel = nil  // Show all content from all channels
            await loadContentForSelectedChannel()
        }
    }
}

// MARK: - Creator Info Model

struct CreatorInfo: Identifiable, Hashable {
    let id: String
    let title: String
    let urlname: String
    let description: String
    let icon: Components.Schemas.ImageModel
    let channels: [ChannelInfo]
    let defaultChannelId: String
}

// MARK: - Channel Info Model

struct ChannelInfo: Identifiable, Hashable {
    let id: String
    let title: String
    let urlname: String
    let creatorId: String
    let icon: Components.Schemas.ImageModel
}
