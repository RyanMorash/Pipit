//
//  CachedAsyncImage.swift
//  Pipit
//
//  Cached async image view to prevent cancellation issues
//

import SwiftUI

/// Priority level for cached images
enum ImageCachePriority: Int, Comparable {
    case thumbnail = 0  // Lower priority - evicted first
    case icon = 1       // Higher priority - kept longer
    
    static func < (lhs: ImageCachePriority, rhs: ImageCachePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A view that loads and caches images asynchronously
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let priority: ImageCachePriority
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var image: Image?
    @State private var isLoading = false
    
    init(
        url: URL?,
        priority: ImageCachePriority = .thumbnail,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.priority = priority
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(image)
            } else {
                placeholder()
                    .task(id: url) {
                        await loadImage()
                    }
            }
        }
    }
    
    private func loadImage() async {
        guard let url = url else { return }
        
        // Check cache first
        if let cached = ImageCache.shared.get(url: url) {
            #if os(iOS)
            self.image = Image(uiImage: cached)
            #else
            self.image = Image(nsImage: cached)
            #endif
            return
        }
        
        guard !isLoading else { return }
        isLoading = true
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            #if os(iOS)
            if let loadedImage = UIImage(data: data) {
                ImageCache.shared.set(url: url, image: loadedImage, priority: priority)
                self.image = Image(uiImage: loadedImage)
            }
            #else
            if let loadedImage = NSImage(data: data) {
                ImageCache.shared.set(url: url, image: loadedImage, priority: priority)
                self.image = Image(nsImage: loadedImage)
            }
            #endif
        } catch {
            // Silently fail for cancellation errors
            if (error as NSError).code != -999 {
                print("Failed to load image from \(url): \(error)")
            }
        }
        
        isLoading = false
    }
}

// MARK: - Image Cache

class ImageCache {
    static let shared = ImageCache()
    
    #if os(iOS)
    private var memoryCache = NSCache<NSURL, UIImage>()
    #else
    private var memoryCache = NSCache<NSURL, NSImage>()
    #endif
    
    // Track priorities for cached images
    private var priorities: [URL: ImageCachePriority] = [:]
    private let priorityQueue = DispatchQueue(label: "com.pipit.imagecache.priority")
    
    private let diskCacheURL: URL
    private let fileManager = FileManager.default
    private let cacheExpirationInterval: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    private init() {
        // Configure memory cache
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
        
        // Set up disk cache directory
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = cacheDirectory.appendingPathComponent("ImageCache", isDirectory: true)
        
        // Create cache directory if needed
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        // Clean expired cache on init
        Task {
            await cleanExpiredCache()
        }
    }
    
    #if os(iOS)
    func get(url: URL) -> UIImage? {
        // Check memory cache first
        if let cached = memoryCache.object(forKey: url as NSURL) {
            return cached
        }
        
        // Check disk cache
        if let diskImage = loadFromDisk(url: url) {
            // Store in memory cache for faster access next time
            memoryCache.setObject(diskImage, forKey: url as NSURL)
            return diskImage
        }
        
        return nil
    }
    
    func set(url: URL, image: UIImage, priority: ImageCachePriority = .thumbnail) {
        // Store priority
        priorityQueue.sync {
            priorities[url] = priority
        }
        
        // Store in memory cache
        memoryCache.setObject(image, forKey: url as NSURL)
        
        // Store on disk asynchronously
        Task.detached(priority: .background) {
            await self.saveToDisk(url: url, image: image, priority: priority)
        }
    }
    
    private func loadFromDisk(url: URL) -> UIImage? {
        let fileURL = diskCacheFileURL(for: url)
        
        // Check if file exists and is not expired
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let modificationDate = attributes[.modificationDate] as? Date,
              Date().timeIntervalSince(modificationDate) < cacheExpirationInterval,
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        return image
    }
    
    private func saveToDisk(url: URL, image: UIImage, priority: ImageCachePriority) async {
        let fileURL = diskCacheFileURL(for: url)
        let metadataURL = diskCacheMetadataURL(for: url)
        
        // Convert to PNG data for quality preservation
        guard let data = image.pngData() else { return }
        
        try? data.write(to: fileURL, options: .atomic)
        
        // Save priority metadata
        let metadata = ["priority": priority.rawValue]
        if let metadataData = try? JSONEncoder().encode(metadata) {
            try? metadataData.write(to: metadataURL, options: .atomic)
        }
    }
    #else
    func get(url: URL) -> NSImage? {
        // Check memory cache first
        if let cached = memoryCache.object(forKey: url as NSURL) {
            return cached
        }
        
        // Check disk cache
        if let diskImage = loadFromDisk(url: url) {
            // Store in memory cache for faster access next time
            memoryCache.setObject(diskImage, forKey: url as NSURL)
            return diskImage
        }
        
        return nil
    }
    
    func set(url: URL, image: NSImage, priority: ImageCachePriority = .thumbnail) {
        // Store priority
        priorityQueue.sync {
            priorities[url] = priority
        }
        
        // Store in memory cache
        memoryCache.setObject(image, forKey: url as NSURL)
        
        // Store on disk asynchronously
        Task.detached(priority: .background) {
            await self.saveToDisk(url: url, image: image, priority: priority)
        }
    }
    
    private func loadFromDisk(url: URL) -> NSImage? {
        let fileURL = diskCacheFileURL(for: url)
        
        // Check if file exists and is not expired
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let modificationDate = attributes[.modificationDate] as? Date,
              Date().timeIntervalSince(modificationDate) < cacheExpirationInterval,
              let data = try? Data(contentsOf: fileURL),
              let image = NSImage(data: data) else {
            return nil
        }
        
        return image
    }
    
    private func saveToDisk(url: URL, image: NSImage, priority: ImageCachePriority) async {
        let fileURL = diskCacheFileURL(for: url)
        let metadataURL = diskCacheMetadataURL(for: url)
        
        // Convert to PNG data for quality preservation
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            return
        }
        
        try? data.write(to: fileURL, options: .atomic)
        
        // Save priority metadata
        let metadata = ["priority": priority.rawValue]
        if let metadataData = try? JSONEncoder().encode(metadata) {
            try? metadataData.write(to: metadataURL, options: .atomic)
        }
    }
    #endif
    
    // MARK: - Common Methods
    
    private func diskCacheFileURL(for url: URL) -> URL {
        // Create a safe filename from the URL
        let filename = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        return diskCacheURL.appendingPathComponent(filename)
    }
    
    private func diskCacheMetadataURL(for url: URL) -> URL {
        let filename = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        return diskCacheURL.appendingPathComponent("\(filename).metadata")
    }
    
    private func loadPriority(for url: URL) -> ImageCachePriority {
        let metadataURL = diskCacheMetadataURL(for: url)
        guard let data = try? Data(contentsOf: metadataURL),
              let metadata = try? JSONDecoder().decode([String: Int].self, from: data),
              let priorityValue = metadata["priority"],
              let priority = ImageCachePriority(rawValue: priorityValue) else {
            return .thumbnail // Default to thumbnail if no metadata
        }
        return priority
    }
    
    private func cleanExpiredCache() async {
        guard let files = try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }
        
        // Filter out metadata files
        let imageFiles = files.filter { !$0.lastPathComponent.hasSuffix(".metadata") }
        
        let now = Date()
        var cleanedCount = 0
        
        // Separate files by priority
        var thumbnails: [(URL, Date)] = []
        var icons: [(URL, Date)] = []
        
        for fileURL in imageFiles {
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let modificationDate = attributes[.modificationDate] as? Date else {
                continue
            }
            
            // Reconstruct URL to check priority
            let filename = fileURL.lastPathComponent
            guard let urlString = filename.removingPercentEncoding,
                  let originalURL = URL(string: urlString) else {
                continue
            }
            
            let priority = loadPriority(for: originalURL)
            let isExpired = now.timeIntervalSince(modificationDate) >= cacheExpirationInterval
            
            if isExpired {
                if priority == .icon {
                    icons.append((fileURL, modificationDate))
                } else {
                    thumbnails.append((fileURL, modificationDate))
                }
            }
        }
        
        // Delete expired thumbnails first
        for (fileURL, _) in thumbnails {
            try? fileManager.removeItem(at: fileURL)
            // Also remove metadata
            let metadataPath = fileURL.path + ".metadata"
            try? fileManager.removeItem(atPath: metadataPath)
            cleanedCount += 1
        }
        
        // Only delete expired icons if needed (they get extra time)
        for (fileURL, _) in icons {
            try? fileManager.removeItem(at: fileURL)
            let metadataPath = fileURL.path + ".metadata"
            try? fileManager.removeItem(atPath: metadataPath)
            cleanedCount += 1
        }
        
        if cleanedCount > 0 {
            print("Cleaned \(cleanedCount) expired image(s) from cache (\(thumbnails.count) thumbnails, \(icons.count) icons)")
        }
    }
    
    /// Clears all cached images (both memory and disk)
    func clearAll() {
        #if os(iOS)
        memoryCache.removeAllObjects()
        #else
        memoryCache.removeAllObjects()
        #endif
        
        priorityQueue.sync {
            priorities.removeAll()
        }
        
        try? fileManager.removeItem(at: diskCacheURL)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
    
    /// Clears only thumbnail images, preserving icons
    func clearThumbnails() {
        guard let files = try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: nil) else {
            return
        }
        
        let imageFiles = files.filter { !$0.lastPathComponent.hasSuffix(".metadata") }
        var clearedCount = 0
        
        for fileURL in imageFiles {
            let filename = fileURL.lastPathComponent
            guard let urlString = filename.removingPercentEncoding,
                  let originalURL = URL(string: urlString) else {
                continue
            }
            
            let priority = loadPriority(for: originalURL)
            if priority == .thumbnail {
                try? fileManager.removeItem(at: fileURL)
                let metadataPath = fileURL.path + ".metadata"
                try? fileManager.removeItem(atPath: metadataPath)
                
                // Remove from memory cache and priority tracking
                memoryCache.removeObject(forKey: originalURL as NSURL)
                priorityQueue.sync {
                    priorities.removeValue(forKey: originalURL)
                }
                clearedCount += 1
            }
        }
        
        if clearedCount > 0 {
            print("Cleared \(clearedCount) thumbnail(s) from cache")
        }
    }
    
    /// Returns the total size of disk cache in bytes
    func diskCacheSize() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        return files.reduce(0) { total, fileURL in
            let size = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
            return total + size
        }
    }
}
