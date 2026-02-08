# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Grocy Mobile is a native iOS/iPadOS/macOS companion app for [Grocy](https://grocy.info/) (grocery management system). The app requires iOS 26+ and uses the Liquid Glass design system. It connects to remote Grocy servers (4.5+) via REST API.

**Key Features**: Stock management, shopping lists, recipes, chores, master data CRUD, barcode scanning, offline caching.

## Build & Test Commands

### Building
```bash
# Build the main app
xcodebuild -scheme "Grocy Mobile" -configuration Debug build

# Build for specific platform
xcodebuild -scheme "Grocy Mobile" -destination 'platform=iOS Simulator,name=iPhone 15' build

# Build widget extension
xcodebuild -scheme "Grocy WidgetExtension" build
```

### Testing
```bash
# Run all tests
xcodebuild test -scheme "Grocy Mobile" -destination 'platform=iOS Simulator,name=iPhone 15'

# Run unit tests only
xcodebuild test -scheme "Grocy MobileTests" -destination 'platform=iOS Simulator,name=iPhone 15'

# Run UI tests only
xcodebuild test -scheme "Grocy MobileUITests" -destination 'platform=iOS Simulator,name=iPhone 15'
```

**Note**: The project uses the Swift Testing framework (not XCTest) for new tests. Use `@Test` macro instead of `XCTestCase`.

### Xcode Operations
Use the MCP xcode-tools for all Xcode operations:
- `BuildProject` - Build in Xcode
- `RunAllTests` - Run all tests
- `RunSomeTests` - Run specific tests
- `XcodeRead/XcodeWrite/XcodeUpdate` - File operations in project structure
- `XcodeGrep/XcodeGlob` - Search within project
- `ExecuteSnippet` - Fast code execution for testing ideas
- `RenderPreview` - Render SwiftUI previews

## Architecture Overview

### MVVM with Centralized State

The app uses a **modified MVVM pattern** with a single central ViewModel:

```
┌─────────────────────────────────────────┐
│      GrocyViewModel (@Observable)       │  <- Single source of truth
│  - Manages all API calls                │
│  - Coordinates SwiftData sync           │
│  - Holds all cached data                │
└─────────────────────────────────────────┘
         ↓                    ↓
    ┌────────┐         ┌──────────────┐
    │ GrocyAPI│         │SwiftDataSync │
    │(REST)   │         │(Persistence) │
    └────────┘         └──────────────┘
         ↓                    ↓
    Backend Server      Local Database
```

**Key File**: `Grocy Mobile/Model/GrocyViewModel.swift` (811 lines)
- Central `@Observable` class managing all state
- Accessed via `@Environment(GrocyViewModel.self)` in views
- Methods like `requestData()`, `updateData()`, `postStockObject()`

### Data Layer: Dual SwiftData Containers

The app uses **two separate ModelContainers**:

1. **Main Container** (`default.store` in app group) - Non-iCloud
   - All cached API data (products, stock, recipes, chores, etc.)
   - Stored in: `group.georgappdev.Grocy/Library/Application Support/`

2. **Profile Container** (`profiles.store`) - iCloud Synced
   - `ServerProfile` - Server credentials and URLs
   - `LoginCustomHeader` - Custom authentication headers

**Why Dual Containers?**
- Prevents large data volumes from syncing to iCloud
- Allows profile sharing across devices while keeping cached data local
- Avoids SwiftData sync conflicts with frequently changing data

**Key Files**:
- `Grocy Mobile/Grocy_MobileApp.swift` (lines 100-241) - Container initialization
- `Grocy Mobile/Model/SwiftDataSync.swift` - Synchronization helpers

### Synchronization Pattern

All API data flows through `SwiftDataSynchronizer`:

```swift
API Response (JSON)
  ↓ Decode
  ↓ SwiftDataSynchronizer.syncCollection() / syncSingleton()
  ↓ Identity-based deduplication
  ↓ Atomic save to ModelContext
  ↓ @Query refreshes UI automatically
```

**Important**: The synchronizer uses **identity-based deduplication** (matching by `id`) and performs **atomic transactions** (rollback on error).

### API Communication

**Protocol-Based Design**: `GrocyAPI` protocol with `GrocyApi` implementation

**File**: `Grocy Mobile/Model/GrocyAPI.swift` (729 lines)

The API uses enum-based organization:
- `ObjectEntities` - CRUD objects (products, locations, recipes, etc.)
- `AdditionalEntities` - Computed/aggregate data (system info, stock status, etc.)
- `StockProductPost` - Stock operations (add, consume, transfer, inventory, open)

**Authentication**:
- API Key in `GROCY-API-KEY` header
- Optional custom headers via `LoginCustomHeader`
- Home Assistant Ingress support (WebSocket auth)

### Navigation Architecture

**Adaptive Layout**:
- iPhone compact: Tab bar navigation (`AppTabNavigation`)
- iPad/Mac: Sidebar navigation (`AppSidebarNavigation`)
- Selection controlled by `@AppStorage` keys: `iPhoneTabNavigation`, `iPadTabNavigation`

**Routing**: Enum-based with 40+ destinations
- `NavigationItem` enum defines all routes
- Central `Navigation` component handles routing with switch statement
- Local `@Observable` routers for feature-specific state (e.g., `StockInteractionNavigationRouter`)

**Deep Links**: `DeepLinkManager` handles URL schemes
- Format: `grocy://stock?filter=expiringSoon`
- Processed in `Grocy_MobileApp.swift:255-259`

**Key Files**:
- `Grocy Mobile/Views/Navigation/ContentView.swift` - Platform selector
- `Grocy Mobile/Views/Navigation/Navigation.swift` - Route switch
- `Grocy Mobile/Views/Navigation/AppSidebarNavigation.swift` - Sidebar layout
- `Grocy Mobile/Views/Navigation/AppTabNavigation.swift` - Tab layout

### View Organization

```
Views/
├── Navigation/       - Routing, sidebar, tabs
├── Stock/           - Stock view, interact, filter, journal
├── ShoppingList/    - Shopping list UI and forms
├── Recipes/         - Recipe viewing and editing
├── Chores/          - Chore tracking and logs
├── Tasks/           - Task management
├── MasterData/      - CRUD for all master data types
├── Settings/        - App configuration and user settings
├── Admin/           - User management (admin only)
├── Components/      - Reusable UI elements (20+ components)
├── Scanner/         - Camera barcode scanning
├── Onboarding/      - Initial setup and login flows
└── Additional/      - Utilities (ServerProblemView, etc.)
```

**Common Patterns**:
```swift
// Access central ViewModel
@Environment(GrocyViewModel.self) private var grocyVM

// Query local SwiftData
@Query(sort: \MDProduct.name) private var products: [MDProduct]

// Access ModelContext for writes
@Environment(\.modelContext) private var modelContext

// Access profile data
@Environment(\.profileModelContext) private var profileContext
```

### Offline Functionality

**Limited Offline Support** - Read-only cache:

1. All API responses cached to SwiftData
2. UI reads from local database via `@Query`
3. **No offline writes** - Network errors prevent modifications
4. Failed requests tracked in `failedToLoadObjects` / `failedToLoadAdditionalObjects`
5. `ServerProblemView` displays connection errors with retry option

**Cache Clearing**:
- `GrocyViewModel.deleteAllCachedData()` - Wipes all local data
- Separate containers allow selective clearing
- Profile data persists unless explicitly cleared

### Key Helpers

| Helper | Purpose |
|--------|---------|
| `GrocyLogger.swift` | Centralized logging (info/warning/error) |
| `Decoder.swift` | Custom JSON decoder with flexible type conversion |
| `DateFormatter.swift` | Grocy-specific date formatting |
| `AICategoryMatcher.swift` | Apple Intelligence integration for category matching |
| `ReminderStore.swift` | Sync shopping list to iOS Reminders app |
| `Translators.swift` | Localization helpers |
| `AppStorage.swift` | AppStorage key definitions |
| `DeepLinkHandler.swift` | URL scheme parsing |

## Common Development Patterns

### Adding a New Master Data Type

1. Create model in `Model/MasterData/MD{Type}Model.swift`
   - Conform to `Codable`, `Identifiable`, `Equatable`
   - Add `@Model` macro for SwiftData
   - Use `@Attribute(.unique)` for `id` field

2. Add to `ObjectEntities` enum in `GrocyAPI.swift`

3. Add array property to `GrocyViewModel` (e.g., `var mdNewType: [MDNewType] = []`)

4. Add to schema in `Grocy_MobileApp.swift` (lines 102-133)

5. Implement API methods in `GrocyAPI.swift` and `GrocyApi.swift`

6. Add sync call in `GrocyViewModel.requestData()`

7. Create CRUD views in `Views/MasterData/{Type}/`

### Adding a New View

1. Create view file in appropriate `Views/` subfolder
2. Add route to `NavigationItem` enum
3. Add case to `Navigation` switch statement
4. Use `@Environment(GrocyViewModel.self)` for data access
5. Use `@Query` for filtered/sorted local data
6. Use `#Preview` with `PreviewContainer` for preview data

### Working with Stock Operations

Stock modifications flow through `GrocyViewModel.postStockObject()`:

```swift
// Consume stock
let action = StockProductPost.consume
let body = StockConsume(amount: 1, transactionType: .consume, ...)
try await grocyVM.postStockObject(
    id: productID,
    stockMode: action,
    content: body
)
await grocyVM.requestData(objects: [.stock, .stock_log])
```

### Error Handling

- API errors use `APIError` enum (serverError, decodingError, timeout, etc.)
- Failed requests tracked in ViewModel sets
- Display errors with `ServerProblemView`
- Log with `GrocyLogger.error()` for debugging

## Important Architectural Decisions

| Decision | Rationale | Impact |
|----------|-----------|--------|
| Single GrocyViewModel | Avoid state sync issues across distributed ViewModels | All views share same state source |
| Dual ModelContainers | Separate iCloud profiles from large local cache | Prevents sync conflicts |
| No offline writes | Simplifies sync logic, avoids merge conflicts | Requires network for modifications |
| Enum-based routing | Type-safe navigation | Easy to add/modify routes |
| Identity-based sync | Deduplication via `id` matching | Prevents duplicates in database |
| @Observable over @ObservedObject | Modern concurrency support | Better performance, cleaner code |

## Model Data Flow Example

**User views stock screen**:
1. `StockView` uses `@Query` to fetch `StockElement` from SwiftData
2. On appear, `GrocyViewModel.updateData()` triggers API refresh
3. `GrocyAPI.getStock()` fetches JSON from server
4. Response decoded with custom `Decoder`
5. `SwiftDataSynchronizer.syncStockElements()` deduplicates and saves
6. `@Query` automatically refreshes UI

## SwiftData Schema Notes

- Main schema: 30+ model types (see `Grocy_MobileApp.swift:102-133`)
- Profile schema: 2 types (`ServerProfile`, `LoginCustomHeader`)
- All models use `@Model` macro
- Unique IDs: `@Attribute(.unique) var id: Int`
- Relationships: `var product: MDProduct?` (optional for SwiftData)
- No migration plan - store deleted on schema changes

## Testing Strategy

- Unit tests: `Grocy MobileTests/Grocy_MobileTests.swift`
- UI tests: `Grocy MobileUITests/`
- Uses Swift Testing framework (`@Test` macro, not XCTest)
- Preview data: `Model/Preview/TestData/` (60+ JSON files)
- Preview container: `Model/Preview/PreviewContainer.swift`

## App Group & Storage

- **App Group ID**: `group.georgappdev.Grocy`
- **Main Store**: `group.georgappdev.Grocy/Library/Application Support/default.store`
- **Profile Store**: `~/Library/Application Support/profiles.store`
- **iCloud Container**: `iCloud.georgappdev.Grocy` (profiles only, disabled on simulator)

## Common Issues

### SwiftData Migration Errors
The app automatically deletes and recreates stores on schema changes (see `Grocy_MobileApp.swift:177-224`). This is intentional - all data is cached from server and can be refetched.

### Dual Container Access
Use correct context:
- `@Environment(\.modelContext)` for main data
- `@Environment(\.profileModelContext)` for server profiles

### Navigation State
Each feature may have its own `@Observable` router for local navigation. Don't confuse with central `NavigationItem` enum for global routing.

## Code Style Notes

- PascalCase for types, camelCase for properties/methods
- Use `@State private var` for SwiftUI state
- `let` for constants, `var` for mutable
- 4-space indentation
- Use Swift's async/await (not Combine where possible)
- Prefer `.self` property for type references in generics
- Comments for complex logic only

## Minimum Requirements

- Xcode 26+
- iOS 26+ / macOS 26 Tahoe+
- Grocy server 4.5+
- Swift 5.9+ features: `@Observable`, `@Query`, async/await, Regex

## Current Development: BarcodeBuddy Integration

The project is currently adding BarcodeBuddy integration to handle unresolved barcodes within the iOS app. This is a significant feature addition.

### BarcodeBuddy Context

**BarcodeBuddy** is a companion service that processes barcodes before they reach Grocy. It can:
- Look up unknown barcodes via external APIs (OpenFoodFacts, etc.)
- Suggest product matches
- Batch process scanned barcodes
- Track unresolved barcodes that need manual intervention

**Integration Goal**: Add a new tab in the iOS app to view and resolve unresolved barcodes directly from the device, without needing to access the BarcodeBuddy web UI.

### BarcodeBuddy API

The project includes a **forked BarcodeBuddy** with custom API enhancements. See `Docs/API_ENHANCEMENTS_SUMMARY.md` for full details.

**Key Custom Endpoints** (added to BarcodeBuddy):
- `GET /api/system/unknownbarcodes` - Returns all unresolved barcodes (enriched with lookup data)
- `DELETE /api/system/unknownbarcodes/{id}` - Dismiss a barcode
- `POST /api/system/unknownbarcodes/{id}/associate` - Associate barcode with Grocy product
- `GET /api/system/barcodelogs` - View processing history

**Authentication**: `BBUDDY-API-KEY` header (not query parameter)

**Response Format**: All endpoints return `{ "data": {...}, "result": { "result": "OK", "http_code": 200 } }`

### BB Unresolved Barcode Types

The API distinguishes between two types of unresolved barcodes:

1. **"New Barcodes"** (`isLookedUp: true`)
   - Name was successfully looked up (e.g., "Organic Oat Milk")
   - May have `possibleMatch` suggesting a Grocy product ID
   - User just needs to confirm/match to product

2. **"Unknown Barcodes"** (`isLookedUp: false`)
   - Lookup failed, `name` is null
   - User needs to either create new product or manually match

### Implementation Specifications

Detailed specs are in the `Docs/` folder:
- `SPEC-grocy-swiftui-ios.md` - Full iOS integration specification
- `barcode-buddy-integration-plan.md` - Phase-by-phase implementation plan
- `PANTRY_BUDDY_SYSTEM_OVERVIEW.md` - Related PantryBuddy hardware system context

### Recommended File Structure for BB Integration

```
Grocy Mobile/Grocy Mobile/
├── BarcodeBuddy/
│   ├── API/
│   │   ├── BarcodeBuddyAPI.swift           # Main API client
│   │   └── BBError.swift                   # Error types
│   ├── Models/
│   │   ├── BBResponse.swift                # Generic wrapper
│   │   ├── BBUnknownBarcode.swift          # Barcode model
│   │   ├── BBSystemInfo.swift              # System info
│   │   └── BBBarcodeLog.swift              # Log entry
│   ├── ViewModels/
│   │   └── BarcodeBuddyViewModel.swift     # State management
│   └── Views/
│       ├── BarcodeBuddyTabView.swift       # Main tab
│       ├── BBSettingsView.swift            # Connection settings
│       ├── BBBarcodeListView.swift         # List of barcodes
│       ├── BBBarcodeRowView.swift          # Individual row
│       ├── BBBarcodeDetailSheet.swift      # Detail/action sheet
│       └── BBLogListView.swift             # History view
```

### BB Integration Key Points

1. **Storage**: Store BB credentials using same pattern as Grocy credentials (ServerProfile pattern with dual containers)
2. **Navigation**: Add new tab with SF Symbol `barcode.viewfinder`, badge showing unresolved count
3. **Product Matching**: Reuse existing Grocy product picker/search components
4. **Product Creation**: Reuse existing product creation form, pre-fill barcode field
5. **Architecture**: Follow existing patterns - `@Observable` ViewModel, `@Query` for local data, `@Environment` injection
6. **Error Handling**: Use same `APIError` patterns as `GrocyAPI`
7. **Async Operations**: Use async/await throughout (not Combine)

### BB API Models Pattern

```swift
// Generic wrapper for all BB responses
struct BBResponse<T: Codable>: Codable {
    let data: T
    let result: BBResult
}

struct BBResult: Codable {
    let result: String      // "OK" or error
    let httpCode: Int

    enum CodingKeys: String, CodingKey {
        case result
        case httpCode = "http_code"
    }
}

// Specific data models
struct BBUnknownBarcode: Codable, Identifiable {
    let id: Int
    let barcode: String
    let amount: Int
    let name: String?
    let possibleMatch: Int?
    let isLookedUp: Bool
    let bestBeforeInDays: Int?
    let price: String?
    let altNames: [String]?
}
```

### Related System: PantryBuddy

The `PANTRY_BUDDY_SYSTEM_OVERVIEW.md` document describes a Raspberry Pi-based scanner station that integrates with both Grocy and BarcodeBuddy. This provides context for how barcodes flow through the system:

```
Scanner → BarcodeBuddy → Grocy
                ↓
         Unresolved barcodes → iOS App (new feature)
```

The iOS integration allows users to resolve barcodes that couldn't be automatically processed by the scanner station.
