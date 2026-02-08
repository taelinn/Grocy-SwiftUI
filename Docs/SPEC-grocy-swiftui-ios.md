# Grocy-SwiftUI — BarcodeBuddy Integration Spec
# For use with Claude Code in Xcode

## Context

This is a fork of Grocy-SwiftUI (https://github.com/supergeorg/Grocy-SwiftUI), a SwiftUI iOS/macOS client for the Grocy grocery management system. We are adding a new tab that connects to a BarcodeBuddy instance to review and process unresolved barcodes.

The app targets iOS 26 with Liquid Glass design, uses async/await networking, and follows the existing architecture patterns (GrocyViewModel, etc.).

## BarcodeBuddy API Details

- **Base URL:** User-configured (e.g. `http://192.168.1.50:9280`)
- **Auth:** `BBUDDY-API-KEY` header (not query param)
- **Response wrapper:** All endpoints return `{ "data": <payload>, "result": { "result": "OK", "http_code": 200 } }`

### Endpoints

#### GET /api/system/info
Health check / version info.
```json
{
    "data": { "version": "1.8.1.8", "version_int": "1818" },
    "result": { "result": "OK", "http_code": 200 }
}
```

#### GET /api/system/unknownbarcodes
Returns all unresolved barcodes (both looked-up and truly unknown).
```json
{
    "data": {
        "count": 3,
        "barcodes": [
            {
                "id": 1,
                "barcode": "4006381333931",
                "amount": 1,
                "name": "Organic Oat Milk 1L",
                "possibleMatch": 42,
                "isLookedUp": true,
                "bestBeforeInDays": 90,
                "price": "2.49",
                "altNames": ["Oat Drink", "Hafermilch"]
            },
            {
                "id": 2,
                "barcode": "TEST123",
                "amount": 1,
                "name": null,
                "possibleMatch": null,
                "isLookedUp": false,
                "bestBeforeInDays": null,
                "price": null,
                "altNames": null
            }
        ]
    },
    "result": { "result": "OK", "http_code": 200 }
}
```

Key distinctions:
- `isLookedUp: true` + `name` present = "New Barcode" (name was found via lookup)
- `isLookedUp: false` + `name: null` = "Unknown Barcode" (lookup failed)
- `possibleMatch` = a Grocy product ID that BB thinks is a match (can be null)

#### DELETE /api/system/unknownbarcodes/{id}
Dismiss/delete a single barcode.
```json
{
    "data": { "deleted": 2 },
    "result": { "result": "OK", "http_code": 200 }
}
```

#### POST /api/system/unknownbarcodes/{id}/associate
Associate a barcode with a Grocy product. Expects form parameter `productId`.
```json
{
    "data": {
        "associated": true,
        "barcodeId": 1,
        "barcode": "4006381333931",
        "productId": 42
    },
    "result": { "result": "OK", "http_code": 200 }
}
```

#### GET /api/system/barcodelogs?limit=50
Processed barcodes history.
```json
{
    "data": {
        "count": 3,
        "logs": [
            { "id": 150, "log": "Consumed 1x Milk" },
            { "id": 149, "log": "Added 1x Bread" }
        ]
    },
    "result": { "result": "OK", "http_code": 200 }
}
```

---

## File Structure

Create a new `BarcodeBuddy` group/folder alongside the existing app code:

```
Grocy Mobile/
├── BarcodeBuddy/
│   ├── API/
│   │   ├── BarcodeBuddyAPI.swift
│   │   └── BBError.swift
│   ├── Models/
│   │   ├── BBResponse.swift
│   │   ├── BBUnknownBarcode.swift
│   │   ├── BBSystemInfo.swift
│   │   └── BBBarcodeLog.swift
│   ├── ViewModels/
│   │   └── BarcodeBuddyViewModel.swift
│   └── Views/
│       ├── BarcodeBuddyTabView.swift
│       ├── BBSettingsView.swift
│       ├── BBBarcodeListView.swift
│       ├── BBBarcodeRowView.swift
│       ├── BBBarcodeDetailSheet.swift
│       └── BBLogListView.swift
```

---

## Task 1: Swift Data Models

Create Codable models for all BB API responses. Follow the existing app's model patterns.

### BBResponse.swift — Generic response wrapper
- Generic struct `BBResponse<T: Codable>: Codable` with `data: T` and `result: BBResult`
- `BBResult: Codable` with `result: String` and `httpCode: Int` (maps from `http_code` via CodingKeys)

### BBUnknownBarcode.swift
- Struct conforming to `Codable`, `Identifiable`, `Hashable`
- Properties: `id: Int`, `barcode: String`, `amount: Int`, `name: String?`, `possibleMatch: Int?`, `isLookedUp: Bool`, `bestBeforeInDays: Int?`, `price: String?`, `altNames: [String]?`
- Wrapper struct `BBUnknownBarcodesData: Codable` with `count: Int` and `barcodes: [BBUnknownBarcode]`

### BBSystemInfo.swift
- Struct with `version: String` and `versionInt: String` (maps from `version_int`)

### BBBarcodeLog.swift
- Struct conforming to `Codable`, `Identifiable` with `id: Int` and `log: String`
- Wrapper struct `BBBarcodeLogsData: Codable` with `count: Int` and `logs: [BBBarcodeLog]`

### Additional response models for action endpoints
- `BBDeleteResponse: Codable` with `deleted: Int`
- `BBAssociateResponse: Codable` with `associated: Bool`, `barcodeId: Int`, `barcode: String`, `productId: Int`

---

## Task 2: API Client

Create `BarcodeBuddyAPI.swift` — a networking client using async/await, following the same patterns as the existing Grocy API client in the app.

### Requirements:
- Init with `serverURL: String` and `apiKey: String`
- Strip trailing slashes from serverURL
- Use URLSession.shared
- Set `BBUDDY-API-KEY` header on all requests (not as a query parameter)
- Set `Accept: application/json` header
- Generic private method for making requests that returns decoded `BBResponse<T>`
- Handle HTTP errors, decoding errors, and network errors with a custom `BBError` enum

### Public methods:
- `testConnection() async throws -> Bool` — calls `/api/system/info`
- `getSystemInfo() async throws -> BBSystemInfo` — calls `/api/system/info`
- `getUnknownBarcodes() async throws -> BBUnknownBarcodesData` — calls `/api/system/unknownbarcodes`
- `deleteBarcode(id: Int) async throws -> BBDeleteResponse` — calls `DELETE /api/system/unknownbarcodes/{id}`
- `associateBarcode(id: Int, productId: Int) async throws -> BBAssociateResponse` — calls `POST /api/system/unknownbarcodes/{id}/associate` with `productId` as form-encoded body
- `getBarcodeLogs(limit: Int = 50) async throws -> BBBarcodeLogsData` — calls `/api/system/barcodelogs?limit=N`

### BBError.swift
- Enum conforming to `LocalizedError`
- Cases: `invalidURL`, `serverError(statusCode: Int)`, `unauthorized`, `decodingError(Error)`, `networkError(Error)`, `notFound`, `badRequest(String)`
- Provide `errorDescription` for each case

---

## Task 3: Settings & Credential Storage

### Storage
- Store BarcodeBuddy server URL and API key using the same storage mechanism the app already uses for Grocy credentials (UserDefaults or Keychain — match existing pattern)
- Add keys: `barcodeBuddyServerURL`, `barcodeBuddyAPIKey`, `barcodeBuddyEnabled`

### BBSettingsView.swift
- Text field for BB server URL (with placeholder like "http://192.168.1.50:9280")
- Secure text field for BB API key
- "Test Connection" button that calls `testConnection()` and shows success/failure with the BB version number on success
- Save/Done button
- If already configured, show current connection status and a "Disconnect" option to clear credentials
- Follow the existing settings view style in the app

---

## Task 4: ViewModel

Create `BarcodeBuddyViewModel.swift` using `@Observable` (or `@ObservableObject` — match whatever the existing app uses for its view models).

### Properties:
- `unknownBarcodes: [BBUnknownBarcode]` — all unresolved barcodes
- `barcodeLogs: [BBBarcodeLog]` — processed history
- `isLoading: Bool`
- `errorMessage: String?`
- `isConnected: Bool`
- Computed: `newBarcodes` — filter unknownBarcodes where `isLookedUp == true`
- Computed: `trulyUnknownBarcodes` — filter where `isLookedUp == false`
- Computed: `totalUnresolvedCount: Int`

### Methods:
- `configure(serverURL:apiKey:)` — create the API client instance
- `fetchUnknownBarcodes() async` — fetch and populate the list, handle errors
- `fetchBarcodeLogs() async` — fetch processed history
- `deleteBarcode(id:) async` — call delete, remove from local array on success
- `associateBarcode(id:productId:) async` — call associate, remove from local array on success
- `testConnection() async -> Bool`
- `refresh() async` — fetch both unknown barcodes and logs

---

## Task 5: Views

### BarcodeBuddyTabView.swift — The main tab view
- If BB is not configured (no credentials saved), show a setup prompt that navigates to BBSettingsView
- If configured, show the barcode list with a toolbar containing a settings gear icon and refresh button
- Support pull-to-refresh
- Load data on appear

### BBBarcodeListView.swift — The barcode list
- Two sections:
  1. **"New Barcodes"** — barcodes where `isLookedUp == true`. Show the looked-up `name` prominently, barcode value as secondary text, and `amount` if > 1
  2. **"Unknown Barcodes"** — barcodes where `isLookedUp == false`. Show the barcode value, "Unknown product" as secondary text
- Each row is tappable — opens BBBarcodeDetailSheet
- Swipe actions: Delete (dismiss barcode)
- Empty state when no barcodes: "All clear! No unresolved barcodes."
- Section for "Processed History" showing recent log entries (collapsible or as a separate tab/segment)

### BBBarcodeRowView.swift — Individual barcode row
- Show barcode icon (SF Symbol: `barcode`)
- Primary text: `name` if available, otherwise the barcode string
- Secondary text: barcode string if name is shown, or "Unknown product"
- Badge for `amount` if > 1
- If `possibleMatch` is set, show a small indicator that a match suggestion exists
- Differentiate looked-up vs unknown visually (e.g. different icon colour or a small label)

### BBBarcodeDetailSheet.swift — Action sheet for a selected barcode
- Show full barcode details: barcode value, name, amount, price, bestBeforeInDays, altNames
- Three action buttons:
  1. **"Match to Product"** — presents the existing Grocy product picker/search from the app. If `possibleMatch` is set, pre-select that product. On selection, call `associateBarcode()`. Look at how the existing app handles product selection in other views and reuse that component.
  2. **"Create New Product"** — navigate to the existing product creation form in the app, pre-filling the barcode field. Look at how the existing app creates new products and reuse that flow.
  3. **"Dismiss"** — call `deleteBarcode()` with a confirmation alert

### BBLogListView.swift — Processed history
- Simple list of log entries, most recent first
- Each row shows the log text
- Pull-to-refresh

---

## Task 6: Add Tab to Main App Navigation

- Find where the app's main TabView is defined
- Add a new tab for BarcodeBuddy with:
  - Label: "Barcodes"
  - SF Symbol: `barcode.viewfinder`
  - Badge: show the `totalUnresolvedCount` from the view model when > 0
- The tab should only appear if BarcodeBuddy is enabled in settings (check `barcodeBuddyEnabled`)
- Instantiate and inject the `BarcodeBuddyViewModel` at the app level, following whatever dependency injection pattern the app uses (environment object, etc.)

---

## General Guidelines

- Follow the existing code patterns, naming conventions, and architecture in the Grocy-SwiftUI codebase
- Use the same error handling patterns as the existing Grocy API calls
- Match the existing UI style — colours, fonts, spacing, list styles
- Reuse existing components wherever possible (product picker, product creation form, loading indicators, error views)
- Support both iOS and macOS (the app is multiplatform)
- All strings should be localisable — use the same localisation approach as the rest of the app
- Handle edge cases: no network, BB server offline, invalid API key, empty states
