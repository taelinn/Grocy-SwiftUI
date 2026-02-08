# BarcodeBuddy Integration Plan for Grocy-SwiftUI

## Overview

Add a new **BarcodeBuddy** tab to the Grocy Mobile iOS app that connects to a BarcodeBuddy instance, displays unresolved barcodes (both "new" and "unknown"), and allows users to match them to Grocy products — all from within the app.

---

## Architecture Summary

### BarcodeBuddy API Details

| Item | Value |
|------|-------|
| Custom endpoint | `GET /api/system/unknownbarcodes` |
| Auth method | `BBUDDY-API-KEY` header |
| Returns | Both "new" (name looked up) and "unknown" barcodes together |
| Response format | Standard BB wrapper: `{ data: {...}, result: { result, http_code } }` |

### Sample Response

```json
{
  "data": {
    "count": 2,
    "barcodes": [
      { "barcode": "TEST123", "amount": 1 },
      { "barcode": "99B37", "amount": 1 }
    ]
  },
  "result": { "result": "OK", "http_code": 200 }
}
```

### Standard BB API Endpoints We'll Use

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/system/info` | GET | Health check, version info |
| `/api/system/unknownbarcodes` | GET | Fetch unresolved barcodes (custom) |
| `/api/action/scan` | GET/POST | Submit a barcode scan |
| `/api/state/getMode` | GET | Get current BB mode |

---

## Phase 1: Foundation — API Client & Settings

### 1.1 New Files to Create

```
Grocy Mobile/
├── BarcodeBuddy/
│   ├── API/
│   │   ├── BarcodeBuddyAPI.swift          // API client (async/await)
│   │   └── BarcodeBuddyEndpoint.swift     // Endpoint enum
│   ├── Models/
│   │   ├── BBResponse.swift               // Generic response wrapper
│   │   ├── BBUnknownBarcode.swift         // Barcode model
│   │   └── BBSystemInfo.swift             // System info model
│   ├── ViewModels/
│   │   └── BarcodeBuddyViewModel.swift    // Main view model
│   └── Views/
│       ├── BarcodeBuddyTabView.swift      // The new tab
│       ├── BBSettingsView.swift           // Connection settings
│       ├── BBBarcodeListView.swift        // Barcode list
│       └── BBBarcodeRowView.swift         // Individual barcode row
```

### 1.2 Swift Models

```swift
// MARK: - Generic BB API Response Wrapper
struct BBResponse<T: Codable>: Codable {
    let data: T
    let result: BBResult
}

struct BBResult: Codable {
    let result: String
    let httpCode: Int

    enum CodingKeys: String, CodingKey {
        case result
        case httpCode = "http_code"
    }
}

// MARK: - Unknown Barcodes
struct BBUnknownBarcodesData: Codable {
    let count: Int
    let barcodes: [BBUnknownBarcode]
}

struct BBUnknownBarcode: Codable, Identifiable, Hashable {
    var id: String { barcode }
    let barcode: String
    let amount: Int
}

// MARK: - System Info (for health check)
struct BBSystemInfo: Codable {
    let version: String
    // Add fields as needed from /api/system/info response
}
```

### 1.3 API Client

```swift
class BarcodeBuddyAPI {
    let serverURL: String
    let apiKey: String
    private let session: URLSession

    init(serverURL: String, apiKey: String) {
        self.serverURL = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.apiKey = apiKey
        self.session = URLSession.shared
    }

    // MARK: - Generic request
    private func request<T: Codable>(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil
    ) async throws -> BBResponse<T> {
        guard let url = URL(string: "\(serverURL)\(endpoint)") else {
            throw BBError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "BBUDDY-API-KEY")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = body {
            request.setValue("application/x-www-form-urlencoded",
                          forHTTPHeaderField: "Content-Type")
            // BB API uses form params for POST
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw BBError.serverError
        }

        return try JSONDecoder().decode(BBResponse<T>.self, from: data)
    }

    // MARK: - Endpoints
    func getUnknownBarcodes() async throws -> BBUnknownBarcodesData {
        let response: BBResponse<BBUnknownBarcodesData> =
            try await request(endpoint: "/api/system/unknownbarcodes")
        return response.data
    }

    func getSystemInfo() async throws -> BBSystemInfo {
        let response: BBResponse<BBSystemInfo> =
            try await request(endpoint: "/api/system/info")
        return response.data
    }

    func testConnection() async throws -> Bool {
        let _: BBResponse<BBSystemInfo> =
            try await request(endpoint: "/api/system/info")
        return true
    }
}

enum BBError: LocalizedError {
    case invalidURL
    case serverError
    case unauthorized
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid BarcodeBuddy server URL"
        case .serverError: return "BarcodeBuddy server error"
        case .unauthorized: return "Invalid API key"
        case .decodingError: return "Failed to parse server response"
        }
    }
}
```

### 1.4 Settings Storage

Store BB credentials alongside existing Grocy credentials. Follow the app's existing
pattern for `UserDefaults` / Keychain storage:

```swift
// Keys for UserDefaults
static let bbServerURL = "barcodeBuddyServerURL"
static let bbAPIKey = "barcodeBuddyAPIKey"
static let bbEnabled = "barcodeBuddyEnabled"
```

---

## Phase 2: BarcodeBuddy Tab & List View

### 2.1 Add Tab to Main Navigation

Add a new case to the app's tab enum and insert it into the TabView:

```swift
// New tab with barcode scanner icon
Label("Barcodes", systemImage: "barcode.viewfinder")
```

### 2.2 ViewModel

```swift
@Observable
class BarcodeBuddyViewModel {
    var unknownBarcodes: [BBUnknownBarcode] = []
    var isLoading = false
    var errorMessage: String?
    var isConnected = false
    var unknownCount: Int { unknownBarcodes.count }

    private var api: BarcodeBuddyAPI?

    func configure(serverURL: String, apiKey: String) {
        self.api = BarcodeBuddyAPI(serverURL: serverURL, apiKey: apiKey)
    }

    func fetchUnknownBarcodes() async {
        guard let api = api else { return }
        isLoading = true
        errorMessage = nil
        do {
            let data = try await api.getUnknownBarcodes()
            unknownBarcodes = data.barcodes
            isConnected = true
        } catch {
            errorMessage = error.localizedDescription
            isConnected = false
        }
        isLoading = false
    }

    func testConnection() async -> Bool {
        guard let api = api else { return false }
        do {
            isConnected = try await api.testConnection()
            return isConnected
        } catch {
            isConnected = false
            return false
        }
    }
}
```

### 2.3 Tab View Structure

```
BarcodeBuddyTabView
├── if not configured → BBSettingsView (setup prompt)
├── if configured →
│   ├── Badge showing unknownCount
│   ├── Pull-to-refresh list
│   │   ├── Section: "Unresolved Barcodes" (count)
│   │   │   ├── BBBarcodeRowView (barcode, amount, action button)
│   │   │   └── ...
│   │   └── Empty state if no barcodes
│   └── Toolbar: Settings gear, Refresh button
```

---

## Phase 3: Processing Barcodes

### 3.1 Match Barcode → Existing Grocy Product

When user taps a barcode row:
1. Present a **product picker** (reuse existing Grocy product list/search from the app)
2. User selects a Grocy product
3. Call **Grocy API** to add the barcode to that product:
   `POST /api/objects/product_barcodes` with `{ product_id, barcode }`
4. Optionally call BB to remove/acknowledge the barcode

### 3.2 Create New Grocy Product from Barcode

1. User taps "Create New Product"
2. Present the existing **product creation form** (already in Grocy-SwiftUI)
3. Pre-fill the barcode field
4. On save, the barcode is automatically linked

### 3.3 Delete / Dismiss Barcode

1. Swipe-to-delete or explicit dismiss button
2. Call BB API to remove the barcode from the unknown list
3. **Note:** This may require another custom endpoint on your BB fork,
   as the standard API doesn't have a delete-unknown-barcode action

---

## Recommended BB API Enhancements

To make the iOS experience richer, consider adding these fields to your
`/api/system/unknownbarcodes` response:

```json
{
  "data": {
    "count": 2,
    "barcodes": [
      {
        "id": 1,
        "barcode": "TEST123",
        "amount": 1,
        "name": "Organic Oat Milk",
        "bestMatch": { "grocyId": 42, "name": "Oat Milk" },
        "createdAt": "2025-02-07T10:30:00Z",
        "isLookedUp": true
      },
      {
        "id": 2,
        "barcode": "99B37",
        "amount": 1,
        "name": null,
        "bestMatch": null,
        "createdAt": "2025-02-07T11:00:00Z",
        "isLookedUp": false
      }
    ]
  },
  "result": { "result": "OK", "http_code": 200 }
}
```

### Why these fields matter:

| Field | Benefit |
|-------|---------|
| `id` | Stable identifier for delete/update operations |
| `name` | Shows looked-up product name in the list (huge UX win) |
| `bestMatch` | Pre-suggests a Grocy product match for quick one-tap resolution |
| `createdAt` | Sort by newest, show how long barcodes have been waiting |
| `isLookedUp` | Distinguish "new" vs "unknown" in the UI with different icons/sections |

### Additional endpoints to consider:

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `DELETE /api/system/unknownbarcodes/{id}` | DELETE | Remove a single barcode |
| `POST /api/system/unknownbarcodes/{id}/associate` | POST | Associate barcode with Grocy product |

---

## Implementation Order

| Step | What | Depends On |
|------|------|-----------|
| 1 | Swift models (`BBResponse`, `BBUnknownBarcode`, etc.) | Nothing |
| 2 | `BarcodeBuddyAPI` client with `getUnknownBarcodes()` | Step 1 |
| 3 | BB settings view (URL + API key input, test connection) | Step 2 |
| 4 | `BarcodeBuddyViewModel` | Steps 1-2 |
| 5 | `BarcodeBuddyTabView` + list view (read-only display) | Steps 3-4 |
| 6 | Add tab to main app navigation | Step 5 |
| 7 | Product picker integration (match barcode → product) | Step 6 |
| 8 | Create new product flow with pre-filled barcode | Step 7 |
| 9 | Delete/dismiss barcode (may need new BB endpoint) | Step 6 |
| 10 | Polish: badges, empty states, error handling, pull-to-refresh | Steps 6-9 |

---

## Open Questions

1. **BB endpoint for deleting/dismissing unknown barcodes** — does this exist, or do
   we need to add it to your BB fork?
2. **BB endpoint for associating a barcode with a product** — or do we only go through
   the Grocy API for this?
3. **Does `/api/system/info` return useful data for a connection test?** — we need to
   confirm the exact response shape
4. **Should the tab show processed barcodes too?** — could be a nice history view
   but adds complexity
5. **Enriching the response** — are you open to adding `name`, `isLookedUp`,
   `createdAt` fields to your custom endpoint?
