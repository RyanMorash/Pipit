//
//  ImageHelpers.swift
//  Pipit
//
//  Helper functions for working with Floatplane images
//

import Foundation

extension Components.Schemas.ImageModel {
    /// Constructs a full image URL with optional width and height parameters
    func url(width: Int? = nil, height: Int? = nil) -> URL? {
        var urlString = path
        
        // Add protocol if missing
        if !urlString.hasPrefix("http") {
            urlString = "https://pbs.floatplane.com" + urlString
        }
        
        // Add width/height query parameters if provided
        var components = URLComponents(string: urlString)
        var queryItems: [URLQueryItem] = []
        
        if let width = width {
            queryItems.append(URLQueryItem(name: "width", value: "\(width)"))
        }
        
        if let height = height {
            queryItems.append(URLQueryItem(name: "height", value: "\(height)"))
        }
        
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        
        return components?.url ?? URL(string: urlString)
    }
    
    /// Constructs a thumbnail URL suitable for small icons
    var thumbnailURL: URL? {
        url(width: 64, height: 64)
    }
    
    /// Constructs a URL at the original image dimensions
    var originalURL: URL? {
        url(width: width, height: height)
    }
}
