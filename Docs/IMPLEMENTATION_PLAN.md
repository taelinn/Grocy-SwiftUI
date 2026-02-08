# Implementation Plan: BarcodeBuddy Integration + Additional Features

**Date:** February 7, 2026
**Status:** 📋 Planning Complete - Ready to Implement

---

## Overview

This document outlines the complete implementation plan for adding BarcodeBuddy integration and three additional features to the Grocy Mobile iOS app.

### Feature Summary

1. **BarcodeBuddy Integration** (Features 1-10): New tab for managing unresolved barcodes
2. **Print Labels** (Feature 11): Add print checkbox to stock interaction forms
3. **Alternate App Icons** (Feature 12): Icon selection in Settings
4. **Quick Add Tab** (Feature 13): Quick product addition with favorites

---

## Architecture Decisions

Based on Q&A session:

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **BB Credentials Storage** | Extend `ServerProfile` model | BB is tied to Grocy server, simplifies management |
| **BB Tab Visibility** | Show only when configured | Clean UX, conditional on BB credentials |
| **BB Tab Position** | Between Quick Scan and Stock Overview | Logical workflow position |
| **Product Picker** | Reuse `ProductField` component | Existing, proven component |
| **Product Creation** | Reuse `MDProductFormView` | Existing form with barcode pre-fill |
| **Error Handling** | Separate `BBError` enum | Clean separation of concerns |
| **Localization** | English strings first | Faster implementation, localize later |
| **Testing** | Real API, manual testing | Production BB instance available |
| **Print Method** | Checkbox on stock forms (Option A) | Follows Grocy web UI pattern |
| **Quick Add Config** | Edit mode in tab | In-place configuration |

---

## Phase 1: Foundation & Models

### Task 1.1: Extend ServerProfile for BarcodeBuddy Credentials
**File:** `Grocy Mobile/Grocy Mobile/Model/Login/ServerProfile.swift`

**Changes:**
```swift
// Add to ServerProfile model
var barcodeBuddyURL: String?
var barcodeBuddyAPIKey: String?

// Computed property
var hasBBConfigured: Bool {
    guard let url = barcodeBuddyURL, let key = barcodeBuddyAPIKey else {
        return false
    }
    return !url.isEmpty && !key.isEmpty
}
```

**Tests:**
- Verify SwiftData schema migration
- Test iCloud sync with new fields
- Verify existing profiles still load

---

### Task 1.2: Create BarcodeBuddy Models
**Location:** `Grocy Mobile/Grocy Mobile/BarcodeBuddy/Models/`

**Files to Create:**

#### 1.2.1: `BBResponse.swift`
```swift
// Generic wrapper for all BB API responses
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
```

#### 1.2.2: `BBUnknownBarcode.swift`
```swift
struct BBUnknownBarcodesData: Codable {
    let count: Int
    let barcodes: [BBUnknownBarcode]
}

struct BBUnknownBarcode: Codable, Identifiable, Hashable {
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

#### 1.2.3: `BBSystemInfo.swift`
```swift
struct BBSystemInfo: Codable {
    let version: String
    let versionInt: String

    enum CodingKeys: String, CodingKey {
        case version
        case versionInt = "version_int"
    }
}
```

#### 1.2.4: `BBBarcodeLog.swift`
```swift
struct BBBarcodeLogsData: Codable {
    let count: Int
    let logs: [BBBarcodeLog]
}

struct BBBarcodeLog: Codable, Identifiable {
    let id: Int
    let log: String
}
```

#### 1.2.5: `BBActionResponse.swift`
```swift
struct BBDeleteResponse: Codable {
    let deleted: Int
}

struct BBAssociateResponse: Codable {
    let associated: Bool
    let barcodeId: Int
    let barcode: String
    let productId: Int
}
```

---

### Task 1.3: Create BBError Enum
**File:** `Grocy Mobile/Grocy Mobile/BarcodeBuddy/API/BBError.swift`

```swift
enum BBError: LocalizedError {
    case invalidURL
    case serverError(statusCode: Int)
    case unauthorized
    case decodingError(Error)
    case networkError(Error)
    case notFound
    case badRequest(String)
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid BarcodeBuddy server URL"
        case .serverError(let statusCode):
            return "BarcodeBuddy server error (HTTP \(statusCode))"
        case .unauthorized:
            return "Invalid BarcodeBuddy API key"
        case .decodingError(let error):
            return "Failed to parse server response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .notFound:
            return "Resource not found"
        case .badRequest(let message):
            return "Bad request: \(message)"
        case .notConfigured:
            return "BarcodeBuddy is not configured"
        }
    }
}
```

---

## Phase 2: API Client

### Task 2.1: Create BarcodeBuddyAPI Client
**File:** `Grocy Mobile/Grocy Mobile/BarcodeBuddy/API/BarcodeBuddyAPI.swift`

**Implementation:**

```swift
@MainActor
class BarcodeBuddyAPI {
    private let serverURL: String
    private let apiKey: String
    private let session: URLSession

    init(serverURL: String, apiKey: String) {
        self.serverURL = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.apiKey = apiKey
        self.session = URLSession.shared
    }

    // MARK: - Generic Request Method
    private func request<T: Codable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> BBResponse<T> {
        // Implementation
    }

    // MARK: - Endpoints

    // System Info
    func getSystemInfo() async throws -> BBSystemInfo
    func testConnection() async throws -> Bool

    // Unknown Barcodes
    func getUnknownBarcodes() async throws -> BBUnknownBarcodesData
    func deleteBarcode(id: Int) async throws -> BBDeleteResponse
    func associateBarcode(id: Int, productId: Int) async throws -> BBAssociateResponse

    // Barcode Logs
    func getBarcodeLogs(limit: Int = 50) async throws -> BBBarcodeLogsData
}
```

**Implementation Details:**
- Use `URLSession.shared`
- Set `BBUDDY-API-KEY` header (NOT query param)
- Set `Accept: application/json`
- Handle HTTP status codes properly
- Decode BB response wrapper
- Throw appropriate `BBError` cases

---

## Phase 3: ViewModel & State Management

### Task 3.1: Create BarcodeBuddyViewModel
**File:** `Grocy Mobile/Grocy Mobile/BarcodeBuddy/ViewModels/BarcodeBuddyViewModel.swift`

**Properties:**
```swift
@MainActor
@Observable
class BarcodeBuddyViewModel {
    // Data
    var unknownBarcodes: [BBUnknownBarcode] = []
    var barcodeLogs: [BBBarcodeLog] = []

    // State
    var isLoading = false
    var errorMessage: String?
    var isConnected = false

    // API Client
    private var api: BarcodeBuddyAPI?

    // Computed Properties
    var newBarcodes: [BBUnknownBarcode] {
        unknownBarcodes.filter { $0.isLookedUp }
    }

    var trulyUnknownBarcodes: [BBUnknownBarcode] {
        unknownBarcodes.filter { !$0.isLookedUp }
    }

    var totalUnresolvedCount: Int {
        unknownBarcodes.count
    }
}
```

**Methods:**
```swift
// Configuration
func configure(serverURL: String, apiKey: String)

// Data Fetching
func fetchUnknownBarcodes() async
func fetchBarcodeLogs() async
func refresh() async  // Fetch both

// Actions
func deleteBarcode(id: Int) async
func associateBarcode(id: Int, productId: Int) async

// Connection
func testConnection() async -> Bool
```

---

### Task 3.2: Inject BarcodeBuddyViewModel into App
**File:** `Grocy Mobile/Grocy_MobileApp.swift`

**Changes:**
```swift
@main
struct Grocy_MobileApp: App {
    // ... existing properties ...
    @State private var bbViewModel = BarcodeBuddyViewModel()

    var body: some Scene {
        WindowGroup {
            // ... existing code ...
        }
        .environment(bbViewModel)  // Add this
    }
}
```

---

## Phase 4: Settings UI

### Task 4.1: Create BB Settings View
**File:** `Grocy Mobile/Grocy Mobile/BarcodeBuddy/Views/BBSettingsView.swift`

**UI Elements:**
- Server URL text field (placeholder: "http://192.168.1.50:9280")
- API Key secure text field
- "Test Connection" button (shows version on success)
- "Save" button
- Connection status indicator
- "Clear Configuration" button (if configured)

**Implementation:**
```swift
struct BBSettingsView: View {
    @Environment(BarcodeBuddyViewModel.self) private var bbVM
    @Environment(\.profileModelContext) private var profileContext
    @Environment(\.dismiss) var dismiss

    @AppStorage("selectedServerProfileID") private var selectedServerProfileID: UUID?

    @State private var serverURL: String = ""
    @State private var apiKey: String = ""
    @State private var isTestingConnection = false
    @State private var connectionTestResult: String?

    var body: some View {
        // Form implementation
    }
}
```

---

### Task 4.2: Add BB Settings to Main Settings
**File:** Find main Settings view

**Changes:**
- Add navigation link to `BBSettingsView`
- Label: "BarcodeBuddy Integration"
- Icon: `barcode.viewfinder`

---

## Phase 5: BarcodeBuddy Views

### Task 5.1: Create BBBarcodeRowView
**File:** `Grocy Mobile/Grocy Mobile/BarcodeBuddy/Views/BBBarcodeRowView.swift`

**Display:**
- Icon: `barcode` SF Symbol
- Primary text: `name` if available, otherwise barcode string
- Secondary text: barcode string if name shown, or "Unknown product"
- Badge: `amount` if > 1
- Indicator: Small badge if `possibleMatch` exists
- Visual distinction: Different icon tint for `isLookedUp` true/false

---

### Task 5.2: Create BBBarcodeListView
**File:** `Grocy Mobile/Grocy Mobile/BarcodeBuddy/Views/BBBarcodeListView.swift`

**Sections:**
1. **"New Barcodes"** - `newBarcodes` (isLookedUp == true)
2. **"Unknown Barcodes"** - `trulyUnknownBarcodes` (isLookedUp == false)
3. **"Processed History"** - Collapsible/separate section for logs

**Features:**
- Swipe to delete action
- Pull-to-refresh
- Empty state: "All clear! No unresolved barcodes."
- Tap row → open `BBBarcodeDetailSheet`

---

### Task 5.3: Create BBBarcodeDetailSheet
**File:** `Grocy Mobile/Grocy Mobile/BarcodeBuddy/Views/BBBarcodeDetailSheet.swift`

**Display:**
- Full barcode details (all fields from `BBUnknownBarcode`)
- Show `altNames` if available
- Show `price` and `bestBeforeInDays` if available

**Actions (3 buttons):**
1. **"Match to Product"**
   - Present `ProductField` picker
   - Pre-select `possibleMatch` if available
   - On selection → call `associateBarcode()`

2. **"Create New Product"**
   - Present `MDProductFormView` in sheet
   - Pass `queuedBarcode` parameter
   - On save → auto-associates

3. **"Dismiss"**
   - Show confirmation alert
   - Call `deleteBarcode()`

---

### Task 5.4: Create BBLogListView
**File:** `Grocy Mobile/Grocy Mobile/BarcodeBuddy/Views/BBLogListView.swift`

**Display:**
- List of log entries (most recent first)
- Each row shows log text
- Pull-to-refresh

---

### Task 5.5: Create BarcodeBuddyTabView (Main Tab)
**File:** `Grocy Mobile/Grocy Mobile/BarcodeBuddy/Views/BarcodeBuddyTabView.swift`

**Logic:**
```swift
struct BarcodeBuddyTabView: View {
    @Environment(BarcodeBuddyViewModel.self) private var bbVM
    @Environment(\.profileModelContext) private var profileContext
    @AppStorage("selectedServerProfileID") private var selectedServerProfileID: UUID?

    var currentProfile: ServerProfile? {
        // Fetch from profileContext
    }

    var isBBConfigured: Bool {
        currentProfile?.hasBBConfigured ?? false
    }

    var body: some View {
        if !isBBConfigured {
            // Setup prompt → navigate to BBSettingsView
        } else {
            NavigationStack {
                BBBarcodeListView()
                    .navigationTitle("Barcodes")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            // Settings gear icon
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            // Refresh button
                        }
                    }
            }
            .task {
                // Configure bbVM with credentials
                // Fetch data on appear
            }
        }
    }
}
```

---

## Phase 6: Navigation Integration

### Task 6.1: Add NavigationItem for BarcodeBuddy
**File:** Find `NavigationItem` enum

**Changes:**
```swift
enum NavigationItem {
    // ... existing cases ...
    case barcodeBuddy  // Add this
}
```

---

### Task 6.2: Add BB Tab to Tab Navigation
**File:** Find `AppTabNavigation.swift`

**Position:** Between Quick Scan and Stock Overview

**Implementation:**
```swift
if currentProfile?.hasBBConfigured ?? false {
    Tab("Barcodes", systemImage: "barcode.viewfinder") {
        BarcodeBuddyTabView()
    }
    .badge(bbViewModel.totalUnresolvedCount > 0 ? bbViewModel.totalUnresolvedCount : nil)
}
```

---

### Task 6.3: Add BB to Sidebar Navigation
**File:** Find `AppSidebarNavigation.swift`

**Changes:** Add conditional sidebar item for BarcodeBuddy

---

### Task 6.4: Add Route Handler
**File:** Find `Navigation.swift` (central router)

**Changes:**
```swift
switch item {
    // ... existing cases ...
    case .barcodeBuddy:
        BarcodeBuddyTabView()
}
```

---

## Phase 7: Badge Implementation

### Task 7.1: Background Refresh Logic
**Considerations:**
- When to refresh badge count?
- Options:
  - On app foreground
  - Periodic background fetch
  - Manual refresh only

**Implementation:**
- Use `.onAppear` in tab
- Call `bbViewModel.fetchUnknownBarcodes()` silently
- Update `totalUnresolvedCount`
- Tab badge automatically updates via binding

---

## Phase 8: Feature 11 - Print Label Checkbox

### Task 8.1: Find Stock Interaction Forms
**Files to Modify:**
- Stock purchase form
- Stock consume form
- Stock transfer form
- Stock inventory form

**Search for:** Stock interaction views

---

### Task 8.2: Add Print Checkbox to Stock Forms
**Implementation:**

```swift
// Add to form state
@State private var shouldPrintLabel: Bool = false

// Add to form UI (before Save button)
Section {
    Toggle("Print label after save", isOn: $shouldPrintLabel)
}

// Modify save action
func saveStockAction() async {
    // ... existing save logic ...

    if shouldPrintLabel {
        // Grocy webhook triggers automatically on stock change
        // No additional API call needed!
    }
}
```

**Note:** Grocy's webhook system triggers automatically when stock is added/modified if the print flag is set. We just need to pass a print parameter in the stock POST request if the Grocy API supports it. **Need to verify this with Grocy API documentation or code inspection.**

---

### Task 8.3: Investigate Grocy Print Parameter
**Action Required:**
- Search Grocy API for print/label parameter in stock POST requests
- Check if existing `postStockObject()` needs modification
- Document the correct parameter name

---

## Phase 9: Feature 12 - Alternate App Icons

### Task 9.1: Add Alternate Icon Assets
**Location:** `Grocy Mobile/Assets.xcassets/`

**Requirements:**
- Create alternate icon image sets
- Follow Apple naming conventions
- Sizes: @2x and @3x for all icons

**Suggested Icons:**
- Default (current)
- Dark Mode variant
- Colorful variant
- Minimal variant

---

### Task 9.2: Configure Info.plist for Alternate Icons
**File:** `Grocy Mobile/Info.plist`

**Add:**
```xml
<key>CFBundleIcons</key>
<dict>
    <key>CFBundleAlternateIcons</key>
    <dict>
        <key>DarkIcon</key>
        <dict>
            <key>CFBundleIconFiles</key>
            <array>
                <string>DarkIcon</string>
            </array>
        </dict>
        <!-- Additional icons -->
    </dict>
</dict>
```

---

### Task 9.3: Create Icon Selection View
**File:** `Grocy Mobile/Grocy Mobile/Views/Settings/AppIconSettingsView.swift`

**UI:**
- Grid of icon options
- Shows current selection
- Tap to change
- Uses `UIApplication.shared.setAlternateIconName()`

**Implementation:**
```swift
struct AppIconSettingsView: View {
    @AppStorage("selectedAppIcon") private var selectedIcon: String = "Default"

    let icons = [
        ("Default", "Default App Icon", nil),
        ("DarkIcon", "Dark Theme", "DarkIcon"),
        ("ColorfulIcon", "Colorful", "ColorfulIcon"),
        ("MinimalIcon", "Minimal", "MinimalIcon")
    ]

    var body: some View {
        // Grid of icon options
    }

    func changeIcon(to iconName: String?) {
        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                GrocyLogger.error("Failed to change icon: \(error)")
            } else {
                selectedIcon = iconName ?? "Default"
            }
        }
    }
}
```

---

### Task 9.4: Add Icon Settings to Main Settings
**File:** Find main Settings view

**Changes:**
- Add navigation link to `AppIconSettingsView`
- Label: "App Icon"
- Icon: `app.badge`

---

## Phase 10: Feature 13 - Quick Add Tab

### Task 10.1: Create Quick Add Model
**File:** `Grocy Mobile/Grocy Mobile/Model/QuickAdd/QuickAddItem.swift`

```swift
import SwiftData

@Model
class QuickAddItem {
    @Attribute(.unique) var id: UUID
    var productID: Int
    var sortOrder: Int

    init(productID: Int, sortOrder: Int) {
        self.id = UUID()
        self.productID = productID
        self.sortOrder = sortOrder
    }
}
```

---

### Task 10.2: Add QuickAddItem to SwiftData Schema
**File:** `Grocy Mobile/Grocy_MobileApp.swift`

**Changes:**
```swift
let mainSchema = Schema([
    // ... existing models ...
    QuickAddItem.self,  // Add this
])
```

---

### Task 10.3: Create Quick Add List View
**File:** `Grocy Mobile/Grocy Mobile/Views/QuickAdd/QuickAddListView.swift`

**Features:**
- `@Query` to fetch `QuickAddItem` sorted by `sortOrder`
- Join with `MDProduct` to show product details
- Tap product → open `QuickAddInteractionSheet`
- Toolbar: Edit button for configuration mode
- Empty state: "No quick add items. Tap Edit to add products."

---

### Task 10.4: Create Quick Add Interaction Sheet
**File:** `Grocy Mobile/Grocy Mobile/Views/QuickAdd/QuickAddInteractionSheet.swift`

**UI:**
- Product name (read-only)
- Amount picker (default: 1)
- Location picker (default: product's default location)
- Best before date picker (optional)
- "Add to Stock" button

**Action:**
- Calls `grocyVM.postStockObject()` with PURCHASE mode
- Dismisses on success
- Shows error on failure

---

### Task 10.5: Create Quick Add Configuration View
**File:** `Grocy Mobile/Grocy Mobile/Views/QuickAdd/QuickAddConfigView.swift`

**Features:**
- Edit mode for `QuickAddListView`
- Swipe to delete
- Drag to reorder (updates `sortOrder`)
- "Add Product" button → `ProductField` picker
- On product selection → insert new `QuickAddItem`

---

### Task 10.6: Create Quick Add Tab View (Main)
**File:** `Grocy Mobile/Grocy Mobile/Views/QuickAdd/QuickAddTabView.swift`

```swift
struct QuickAddTabView: View {
    @Environment(GrocyViewModel.self) private var grocyVM
    @State private var isEditMode = false

    var body: some View {
        NavigationStack {
            if isEditMode {
                QuickAddConfigView(isEditMode: $isEditMode)
            } else {
                QuickAddListView()
            }
        }
        .navigationTitle("Quick Add")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditMode ? "Done" : "Edit") {
                    isEditMode.toggle()
                }
            }
        }
    }
}
```

---

### Task 10.7: Add Quick Add to Navigation
**Files:**
- `NavigationItem` enum: Add `.quickAdd` case
- `AppTabNavigation.swift`: Add tab
- `AppSidebarNavigation.swift`: Add sidebar item
- `Navigation.swift`: Add route handler

**Position:** New tab (after Shopping List? Or at end?)

---

## Phase 11: Testing & Refinement

### Task 11.1: Test BarcodeBuddy Integration
**Test Cases:**
1. Configure BB credentials in settings
2. View unresolved barcodes list
3. Delete a barcode
4. Associate barcode with existing product
5. Create new product from barcode
6. View processed logs
7. Test with production BB instance
8. Verify badge updates

---

### Task 11.2: Test Print Label Feature
**Test Cases:**
1. Add stock with print checkbox enabled
2. Verify webhook triggers
3. Check label prints correctly
4. Test on different stock actions (purchase, inventory, etc.)

---

### Task 11.3: Test Alternate Icons
**Test Cases:**
1. Change app icon
2. Verify icon changes on home screen
3. Test all icon variants
4. Restart app to ensure persistence

---

### Task 11.4: Test Quick Add
**Test Cases:**
1. Add products to Quick Add list
2. Reorder products
3. Remove products
4. Quick add stock with default location
5. Quick add stock with custom location/amount
6. Verify stock updates in Grocy

---

## Phase 12: Polish & Documentation

### Task 12.1: Add Loading States
- Skeleton loaders
- Progress indicators
- Refresh animations

---

### Task 12.2: Add Error Handling UI
- Error alerts
- Retry buttons
- Helpful error messages

---

### Task 12.3: Add Empty States
- Meaningful empty state messages
- Action buttons to guide users
- Illustrations or icons

---

### Task 12.4: Update CLAUDE.md
- Document new BB integration
- Document print feature
- Document icon selection
- Document quick add feature

---

## Implementation Order

**Recommended sequence:**

1. **Phase 1** (Foundation) - Start here
2. **Phase 2** (API Client) - Core functionality
3. **Phase 3** (ViewModel) - State management
4. **Phase 4** (Settings) - Enable configuration
5. **Phase 5** (BB Views) - Build UI
6. **Phase 6** (Navigation) - Wire everything up
7. **Phase 7** (Badge) - Polish BB feature
8. **Test BB Integration** (Phase 11.1)
9. **Phase 8** (Print) - Add print checkbox
10. **Test Print** (Phase 11.2)
11. **Phase 9** (Icons) - Add icon selection
12. **Test Icons** (Phase 11.3)
13. **Phase 10** (Quick Add) - New feature
14. **Test Quick Add** (Phase 11.4)
15. **Phase 12** (Polish) - Final touches

---

## Estimated Task Count

| Phase | Tasks | Complexity |
|-------|-------|------------|
| Phase 1: Foundation | 3 | Medium |
| Phase 2: API Client | 1 | Medium |
| Phase 3: ViewModel | 2 | Medium |
| Phase 4: Settings | 2 | Low |
| Phase 5: BB Views | 5 | High |
| Phase 6: Navigation | 4 | Low |
| Phase 7: Badge | 1 | Low |
| Phase 8: Print | 3 | Medium |
| Phase 9: Icons | 4 | Medium |
| Phase 10: Quick Add | 7 | High |
| Phase 11: Testing | 4 | High |
| Phase 12: Polish | 4 | Medium |
| **Total** | **40 tasks** | **Mixed** |

---

## Risk Assessment

### High Risk Items
1. **SwiftData schema changes** - May require data migration
2. **Print webhook integration** - Need to verify Grocy API parameter
3. **Production BB testing** - Limited testing capacity

### Medium Risk Items
1. **Badge background refresh** - Battery/performance considerations
2. **Icon asset creation** - Design resources needed
3. **Quick Add UX** - Complex interaction patterns

### Low Risk Items
1. **BB API client** - Well-documented API
2. **Settings UI** - Standard patterns
3. **Navigation integration** - Established patterns

---

## Open Questions

1. **Print Feature**: What parameter does Grocy API use for "print label" flag?
2. **Badge Refresh**: How often should we refresh the BB badge count?
3. **Quick Add Position**: Should Quick Add tab be after Shopping List or at the end?
4. **Icon Design**: Who will design the alternate app icons?

---

## Success Criteria

### BarcodeBuddy Integration
- ✅ User can configure BB credentials
- ✅ User can view unresolved barcodes
- ✅ User can associate barcodes with products
- ✅ User can create new products from barcodes
- ✅ User can dismiss barcodes
- ✅ User can view processing logs
- ✅ Badge shows unresolved count

### Print Labels
- ✅ Checkbox appears on stock forms
- ✅ Labels print when checkbox is enabled
- ✅ Works for all stock actions

### Alternate Icons
- ✅ User can select app icon in settings
- ✅ Icon changes persist across restarts
- ✅ Multiple icon variants available

### Quick Add
- ✅ User can configure quick add list
- ✅ User can reorder products
- ✅ Tapping product shows interaction sheet
- ✅ Stock adds successfully to Grocy
- ✅ Default location pre-selected

---

**Document prepared by:** Claude Code
**Next step:** Begin Phase 1 implementation
