//
//  FloatplaneAPIService.swift
//  Pipit
//
//  API service for Floatplane using OpenAPI generated client
//

import Foundation
import OpenAPIRuntime
import OpenAPIURLSession
import HTTPTypes

@Observable
class FloatplaneAPIService {
    private let client: Client
    private let sailsSid: String
    
    init(sailsSid: String) {
        self.sailsSid = sailsSid
        
        // Create URLSession with custom configuration for cookie handling
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieAcceptPolicy = .always
        
        // Create cookie storage and add the sails.sid cookie
        let cookieStorage = HTTPCookieStorage.shared
        if let url = URL(string: "https://www.floatplane.com"),
           let cookie = HTTPCookie(properties: [
               .domain: ".floatplane.com",  // Note: domain includes subdomain prefix
               .path: "/",
               .name: "sails.sid",
               .value: sailsSid,
               .secure: "TRUE",
               .expires: Date.distantFuture
           ]) {
            cookieStorage.setCookie(cookie)
            print("Cookie set: \(cookie)")
        } else {
            print("Failed to create cookie")
        }
        
        let urlSession = URLSession(configuration: configuration)
        
        // Initialize the OpenAPI client with Floatplane-compatible date handling
        // Floatplane uses ISO8601 with milliseconds: "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        self.client = Client(
            serverURL: try! Servers.Server1.url(),
            configuration: .init(dateTranscoder: .iso8601WithFractionalSeconds),
            transport: URLSessionTransport(configuration: .init(session: urlSession))
        )
    }
    
    // MARK: - Content Methods
    
    /// Get content from multiple creators (content feed)
    func getMultiCreatorBlogPosts(creatorIds: [String], limit: Int = 20) async throws -> Components.Schemas.ContentCreatorListV3Response {
        let response = try await client.getMultiCreatorBlogPosts(query: .init(
            ids: creatorIds,
            limit: limit
        ))
        return try response.ok.body.json
    }
    
    // MARK: - Creator Methods
    
    /// Get detailed information about a creator
    func getCreator(creatorId: String) async throws -> Components.Schemas.CreatorModelV3 {
        let response = try await client.getCreator(query: .init(id: creatorId))
        return try response.ok.body.json
    }
    
    // MARK: - User Methods
    
    /// Get current user information
    func getSelf() async throws -> Components.Schemas.UserSelfV3Response {
        let response = try await client.getSelf()
        return try response.ok.body.json
    }
    
    /// Get user's subscriptions
    func listUserSubscriptions() async throws -> [Components.Schemas.UserSubscriptionModel] {
        do {
            let response = try await client.listUserSubscriptionsV3(.init())
            switch response {
            case .ok(let okResponse):
                return try okResponse.body.json
            case .badRequest(let error):
                print("Bad request error: \(error)")
                throw FloatplaneAPIError.badRequest("Bad request")
            case .unauthorized(let error):
                print("Unauthorized error: \(error)")
                throw FloatplaneAPIError.unauthorized
            case .forbidden(let error):
                print("Forbidden error: \(error)")
                throw FloatplaneAPIError.unauthorized
            case .notFound(let error):
                print("Not found error: \(error)")
                throw FloatplaneAPIError.badRequest("Resource not found")
            case .tooManyRequests(let error):
                print("Rate limited: \(error)")
                throw FloatplaneAPIError.badRequest("Too many requests")
            case .default(let statusCode, let payload):
                print("Unexpected response: \(statusCode), payload: \(payload)")
                throw FloatplaneAPIError.unexpectedResponse(statusCode)
            }
        } catch let error as FloatplaneAPIError {
            print("FloatplaneAPIError: \(error)")
            throw error
        } catch {
            print("Error fetching subscriptions: \(error)")
            throw error
        }
    }
    
    // MARK: - Video Delivery Methods
    
    /// Get video content details including title and thumbnail
    func getVideoContent(videoId: String) async throws -> Components.Schemas.ContentVideoV3Response {
        let response = try await client.getVideoContent(query: .init(id: videoId))
        return try response.ok.body.json
    }
    
    /// Get video delivery information for streaming/downloading
    func getDeliveryInfo(entityId: String, scenario: Operations.GetDeliveryInfoV3.Input.Query.ScenarioPayload) async throws -> Components.Schemas.CdnDeliveryV3Response {
        let response = try await client.getDeliveryInfoV3(.init(query: .init(
            scenario: scenario,
            entityId: entityId
        )))
        return try response.ok.body.json
    }
}

// MARK: - Error Types

enum FloatplaneAPIError: LocalizedError {
    case unauthorized
    case badRequest(String)
    case unexpectedResponse(Int)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Authentication failed. Please check your cookie."
        case .badRequest(let message):
            return "Bad request: \(message)"
        case .unexpectedResponse(let code):
            return "Unexpected response code: \(code)"
        }
    }
}

