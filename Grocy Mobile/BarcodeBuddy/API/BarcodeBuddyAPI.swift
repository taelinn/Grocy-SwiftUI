//
//  BarcodeBuddyAPI.swift
//  Grocy Mobile
//
//  BarcodeBuddy API client
//

import Foundation

@MainActor
class BarcodeBuddyAPI: NSObject, URLSessionTaskDelegate {
    let serverURL: String
    let apiKey: String
    private var session: URLSession!
    
    override init() {
        fatalError("Use init(serverURL:apiKey:) instead")
    }
    
    init(serverURL: String, apiKey: String) {
        self.serverURL = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.apiKey = apiKey
        
        super.init()
        
        // Configure URLSession with custom delegate to preserve headers on redirect
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = 5
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        
        // Use self as delegate to handle redirects properly
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
    
    // MARK: - URLSessionTaskDelegate
    
    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        // Block redirects - a properly authenticated API request should never redirect
        // If we get a redirect, it means authentication failed
        completionHandler(nil)
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        // Log actual request details after the request completes
        for transaction in metrics.transactionMetrics {
            let request = transaction.request
            Task { @MainActor in
                GrocyLogger.info("Actual request sent - URL: \(request.url?.absoluteString ?? "nil")")
                GrocyLogger.info("Actual request sent - Method: \(request.httpMethod ?? "nil")")
                GrocyLogger.info("Actual request sent - All Headers: \(request.allHTTPHeaderFields ?? [:])")
            }
            
            if let response = transaction.response as? HTTPURLResponse {
                Task { @MainActor in
                    GrocyLogger.info("Response received - Status: \(response.statusCode)")
                    GrocyLogger.info("Response received - All Headers: \(response.allHeaderFields)")
                }
            }
        }
    }
    
    // MARK: - Generic Request Method
    private func request<T: Codable>(
        endpoint: String,
        method: String = "GET",
        body: [String: String]? = nil
    ) async throws -> BBResponse<T> {
        guard let url = URL(string: "\(serverURL)\(endpoint)") else {
            throw BBError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "BBUDDY-API-KEY")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("GrocyMobile/3.2.0", forHTTPHeaderField: "User-Agent")
        
        // Debug logging
        GrocyLogger.info("BarcodeBuddy API Request: \(method) \(url.absoluteString)")
        GrocyLogger.info("BarcodeBuddy API Key (length \(apiKey.count)): \(apiKey)")
        GrocyLogger.info("BarcodeBuddy Headers: \(request.allHTTPHeaderFields ?? [:])")
        
        // Handle POST body as form-encoded data
        if let body = body, method == "POST" {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            let formData = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            request.httpBody = formData.data(using: .utf8)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BBError.serverError(statusCode: 0)
            }
            
            // Debug logging
            GrocyLogger.info("BarcodeBuddy API Response: HTTP \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200...299:
                break
            case 300...399:
                // Redirect detected - authentication likely failed
                // Log redirect location for debugging
                if let location = httpResponse.value(forHTTPHeaderField: "Location") {
                    GrocyLogger.error("BarcodeBuddy redirect to: \(location)")
                }
                throw BBError.unauthorized
            case 401, 403:
                throw BBError.unauthorized
            case 404:
                throw BBError.notFound
            case 400:
                throw BBError.badRequest("Invalid request parameters")
            default:
                throw BBError.serverError(statusCode: httpResponse.statusCode)
            }
            
            do {
                let decoded = try JSONDecoder().decode(BBResponse<T>.self, from: data)
                return decoded
            } catch {
                throw BBError.decodingError(error)
            }
        } catch let error as BBError {
            throw error
        } catch {
            throw BBError.networkError(error)
        }
    }
    
    // MARK: - API Endpoints
    
    /// Test connection to BarcodeBuddy server
    func testConnection() async throws -> Bool {
        let _: BBResponse<BBSystemInfo> = try await request(endpoint: "/api/system/info")
        return true
    }
    
    /// Get system information
    func getSystemInfo() async throws -> BBSystemInfo {
        let response: BBResponse<BBSystemInfo> = try await request(endpoint: "/api/system/info")
        return response.data
    }
    
    /// Get all unknown/unresolved barcodes
    func getUnknownBarcodes() async throws -> BBUnknownBarcodesData {
        let response: BBResponse<BBUnknownBarcodesData> = try await request(endpoint: "/api/system/unknownbarcodes")
        return response.data
    }
    
    /// Delete/dismiss a barcode
    func deleteBarcode(id: Int) async throws -> BBDeleteResponse {
        let response: BBResponse<BBDeleteResponse> = try await request(
            endpoint: "/api/system/unknownbarcodes/\(id)",
            method: "DELETE"
        )
        return response.data
    }
    
    /// Associate a barcode with a Grocy product
    func associateBarcode(id: Int, productId: Int) async throws -> BBAssociateResponse {
        let response: BBResponse<BBAssociateResponse> = try await request(
            endpoint: "/api/system/unknownbarcodes/\(id)/associate",
            method: "POST",
            body: ["productId": "\(productId)"]
        )
        return response.data
    }
    
    /// Get barcode processing logs
    func getBarcodeLogs(limit: Int = 50) async throws -> BBBarcodeLogsData {
        let clampedLimit = min(max(limit, 1), 200)
        let response: BBResponse<BBBarcodeLogsData> = try await request(
            endpoint: "/api/system/barcodelogs?limit=\(clampedLimit)"
        )
        return response.data
    }
}
