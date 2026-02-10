//
//  SettingsView.swift
//  Pipit
//
//  Settings view for configuring API access
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("sailsSid") private var sailsSid: String = ""
    @AppStorage("defaultVideoQuality") private var defaultVideoQuality: String = "auto"
    @State private var showingCookieInfo = false
    @State private var cacheSize: String = "Calculating..."
    @State private var showingClearCacheAlert = false
    @State private var showingClearThumbnailsAlert = false
    
    var body: some View {
        Form {
            Section {
                SecureField("sails.sid Cookie", text: $sailsSid)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                
                Button {
                    showingCookieInfo = true
                } label: {
                    Label("How to get your cookie", systemImage: "questionmark.circle")
                }
            } header: {
                Text("Authentication")
            } footer: {
                Text("Enter your sails.sid cookie from Floatplane to access content.")
            }
            
            Section {
                Picker("Default Quality", selection: $defaultVideoQuality) {
                    Text("Auto (Recommended)").tag("auto")
                    Text("4K").tag("2160p")
                    Text("1080p").tag("1080p")
                    Text("720p").tag("720p")
                    Text("480p").tag("480p")
                    Text("360p").tag("360p")
                }
            } header: {
                Text("Video Playback")
            } footer: {
                Text("Choose the default video quality for playback. Auto adjusts quality based on your network connection. If your preferred quality is unavailable, the next highest quality will be used.")
            }
            
            Section {
                HStack {
                    Text("Cache Size")
                    Spacer()
                    Text(cacheSize)
                        .foregroundStyle(.secondary)
                }
                
                Button(role: .destructive) {
                    showingClearThumbnailsAlert = true
                } label: {
                    Label("Clear Thumbnails Only", systemImage: "photo.on.rectangle.angled")
                }
                
                Button(role: .destructive) {
                    showingClearCacheAlert = true
                } label: {
                    Label("Clear All Images", systemImage: "trash")
                }
            } header: {
                Text("Storage")
            } footer: {
                Text("Images are cached for 7 days. Clear thumbnails to free up space while keeping creator/channel icons, or clear all images including icons.")
            }
        }
        .navigationTitle("Settings")
        .task {
            await updateCacheSize()
        }
        .sheet(isPresented: $showingCookieInfo) {
            CookieInfoView()
        }
        .alert("Clear All Images?", isPresented: $showingClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearAllCache()
            }
        } message: {
            Text("This will remove all cached images including icons. They will be downloaded again when needed.")
        }
        .alert("Clear Thumbnails?", isPresented: $showingClearThumbnailsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Thumbnails", role: .destructive) {
                clearThumbnails()
            }
        } message: {
            Text("This will remove cached post thumbnails while preserving creator and channel icons.")
        }
    }
    
    private func updateCacheSize() async {
        let bytes = ImageCache.shared.diskCacheSize()
        cacheSize = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    private func clearAllCache() {
        ImageCache.shared.clearAll()
        Task {
            await updateCacheSize()
        }
    }
    
    private func clearThumbnails() {
        ImageCache.shared.clearThumbnails()
        Task {
            await updateCacheSize()
        }
    }
}

struct CookieInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How to get your sails.sid cookie")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        InstructionStep(
                            number: 1,
                            text: "Open Floatplane.com in your web browser and log in"
                        )
                        
                        InstructionStep(
                            number: 2,
                            text: "Open Developer Tools (F12 or right-click → Inspect)"
                        )
                        
                        InstructionStep(
                            number: 3,
                            text: "Go to the Application or Storage tab"
                        )
                        
                        InstructionStep(
                            number: 4,
                            text: "Find Cookies → https://www.floatplane.com"
                        )
                        
                        InstructionStep(
                            number: 5,
                            text: "Copy the value of the 'sails.sid' cookie"
                        )
                        
                        InstructionStep(
                            number: 6,
                            text: "Paste it into the settings field"
                        )
                    }
                    
                    Text("Note: This cookie gives full access to your Floatplane account. Keep it secure and don't share it with anyone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("Cookie Instructions")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.accentColor)
                .clipShape(Circle())
            
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}

#Preview("Cookie Info") {
    CookieInfoView()
}
