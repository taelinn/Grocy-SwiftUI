# Quick Add Feature - Implementation Summary

**Version:** 1.0
**Date:** February 2026
**Status:** Complete - Ready for TestFlight

---

## Overview

The Quick Add feature provides a streamlined way to add frequently purchased products to stock with a single tap. All configuration is managed server-side via Grocy UserFields, enabling consistent behavior across all users and devices connecting to the same Grocy instance.

---

## Key Features Implemented

### 1. Server-Side Favorites Management
- **UserField-Based Storage**: Favorites are stored using the `quick_add` UserField on the Grocy server
- **Cross-User Sharing**: All users connecting to the same Grocy instance see the same favorites
- **Product Group Support**: Mark entire product groups as favorites for bulk configuration
- **Inheritance Model**: Products automatically inherit favorite status from their product group (unless overridden)

### 2. Server-Side Note Requirements
- **UserField-Based Storage**: Note requirements stored using the `note_required` UserField
- **Product-Level Control**: Individual products can require notes
- **Product Group-Level Control**: Entire product groups can require notes
- **Inheritance**: Products inherit note requirements from their group (unless overridden at product level)
- **Dynamic UI**: Note field appears/disappears based on server configuration

### 3. Synchronization
- **Pull-to-Refresh**: Quick Add tab supports pull-to-refresh for instant sync
- **Manual Sync**: Settings button for full refresh from server
- **Local Caching**: Favorites cached locally in SwiftData for fast access
- **Two-Level Sync**: Checks both product groups and individual products

### 4. Label Printing
- **Automatic Printing**: Uses `stock_label_type: 2` parameter in purchase requests
- **No Separate API Call**: Label printing handled automatically by Grocy server
- **Single Transaction**: Stock addition and label printing in one API call

### 5. UI/UX Enhancements
- **Simplified Product Picker**: Removed configuration sheet - products added immediately
- **Product Group Categorization**: Favorites organized by native Grocy product groups
- **Tab Visibility Control**: Users can hide Quick Add tab if not needed
- **Setup Instructions**: Comprehensive empty state guidance
- **Note Field Positioning**: Note field appears at top of form (after product name)

---

## Architecture

### Server-Side Storage (Grocy UserFields)

```
┌─────────────────────────────────────────────────────────┐
│                    Grocy Server                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │  Products   │  │ UserFields  │  │ Product Groups  │ │
│  │ (id, name,  │  │ quick_add   │  │ (id, name)      │ │
│  │ productGrp) │  │ note_reqd   │  │                 │ │
│  └─────────────┘  └─────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────┘
                          │
                    API Calls
                          │
┌─────────────────────────────────────────────────────────┐
│                    iOS App                               │
│  ┌─────────────────────────────────────────────────┐   │
│  │ QuickAddFavorite (local SwiftData cache)       │   │
│  │ - productID (unique key)                       │   │
│  │ - sortOrder (UI preference)                    │   │
│  │ - grocyServerURL (scope per server)            │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Sync from Server**: App fetches `quick_add` and `note_required` userfields for all products and product groups
2. **Local Cache**: Stores favorite product IDs locally in SwiftData for fast UI rendering
3. **Adding Favorite**: Updates server userfield AND creates local cache entry
4. **Removing Favorite**: Clears server userfield AND deletes local cache entry
5. **Purchase Flow**: Checks server for `note_required` status dynamically when sheet opens

---

## Implementation Details

### Required Grocy UserFields

Users must create these UserFields in Grocy for the feature to work:

#### 1. quick_add (Required)
- **Name**: `quick_add`
- **Entity**: Products and Product Groups
- **Type**: Checkbox
- **Purpose**: Marks products/groups as Quick Add favorites

#### 2. note_required (Optional)
- **Name**: `note_required`
- **Entity**: Products and Product Groups
- **Type**: Checkbox
- **Purpose**: Requires note entry when adding to stock

---

## Files Modified

### Core API & Data Layer

#### `Grocy Mobile/Model/GrocyAPI.swift`
**Changes**: Added UserFields API support
- Added `getUserfields(entity:objectId:)` method
- Added `putUserfields(entity:objectId:content:)` method
- Return type: `[String: String?]` to handle null values

**Key Methods**:
```swift
func getUserfields(entity: ObjectEntities, objectId: Int) async throws -> [String: String?]
func putUserfields(entity: ObjectEntities, objectId: Int, content: Data) async throws
```

#### `Grocy Mobile/Model/GrocyViewModel.swift`
**Changes**: Added favorite management and sync logic
- `setProductFavorite(productID:isFavorite:)` - Set favorite status on server
- `getProductUserfields(productID:)` - Fetch userfields for a product
- `isProductFavorite(productID:)` - Check if product is favorite
- `isNoteRequired(for:)` - Check if product/group requires note (with inheritance)
- `syncFavoritesFromServer(modelContext:)` - Two-level sync from server (groups + products)

**Key Logic**:
```swift
// Note requirement check with inheritance
func isNoteRequired(for product: MDProduct) async -> Bool {
    // 1. Check product-level userfield
    // 2. If not set, check product group userfield
    // 3. Return true if either is "1"
}
```

#### `Grocy Mobile/Helper/AppSpecificUserFields.swift`
**Changes**: Added new UserField constants
```swift
enum AppSpecificUserFields: String {
    case storeLogo = "storeLogo"
    case locationPicture = "locationPicture"
    case quickAddFavorite = "quick_add"        // NEW
    case noteRequired = "note_required"        // NEW
}
```

### Data Models

#### `Grocy Mobile/Model/QuickAdd/QuickAddFavorite.swift`
**Changes**: Simplified to remove server-side data
- **Removed**: `requiresNote` property (now on server)
- **Kept**: `productID`, `sortOrder`, `grocyServerURL`, `dateAdded`

**Before**:
```swift
@Model
final class QuickAddFavorite {
    @Attribute(.unique) var productID: Int
    var sortOrder: Int
    var requiresNote: Bool           // REMOVED
    var grocyServerURL: String
    var dateAdded: Date
}
```

**After**:
```swift
@Model
final class QuickAddFavorite {
    @Attribute(.unique) var productID: Int
    var sortOrder: Int
    var grocyServerURL: String
    var dateAdded: Date
}
```

#### `Grocy Mobile/Model/Stock/Transaction/ProductBuyModel.swift`
**Changes**: Added label printing parameter
- Added `stockLabelType: Int?` property
- Maps to `stock_label_type` in API request
- Value `2` triggers automatic label printing

### Views

#### `Grocy Mobile/Views/QuickAdd/QuickAddTabView.swift`
**Changes**: Major refactor for server-side favorites
- Removed category-based organization
- Added Product Group grouping
- Added pull-to-refresh support
- Updated empty state instructions
- Simplified `addFavorite()` method (no `requiresNote` parameter)
- Removed note requirement icon from rows

**Key Features**:
- Pull-to-refresh calls `syncFavoritesFromServer()`
- Groups favorites by `MDProductGroup`
- Shows "Uncategorized" section for products without groups
- Empty state explains UserField setup

#### `Grocy Mobile/Views/QuickAdd/QuickAddProductPickerView.swift`
**Changes**: Simplified - removed configuration sheet
- **Removed**: `QuickAddConfigSheet` entirely (~60 lines removed)
- **Changed**: Callback from `(Int, Bool) -> Void` to `(Int) -> Void`
- **Behavior**: Products added immediately on tap (no config needed)

**Before**: Tap product → Config sheet → Add
**After**: Tap product → Add immediately

#### `Grocy Mobile/Views/QuickAdd/QuickAddPurchaseSheet.swift`
**Changes**: Dynamic note field based on server
- Added `@State private var noteRequired: Bool = false`
- Added `.task` to fetch server-side note requirement
- Note field positioned at top (after product section)
- Removed dependency on `favorite.requiresNote`

**Field Order**:
1. Product
2. Note (if `noteRequired`)
3. Amount
4. Quantity Unit
5. Location
6. Stock Amount (summary)

#### `Grocy Mobile/Views/Stock/StockInteraction/PurchaseProductView.swift`
**Changes**: Updated label printing
- Replaced manual `printStockEntryLabel()` call
- Now uses `stockLabelType` parameter in purchase request
- Simplified from two API calls to one

**Before**:
```swift
try await grocyVM.postStockObject(...)
try await grocyVM.printStockEntryLabel(entryID: stockRowID)
```

**After**:
```swift
let purchaseInfo = ProductBuy(..., stockLabelType: printLabel ? 2 : nil)
try await grocyVM.postStockObject(..., content: purchaseInfo)
```

#### `Grocy Mobile/Views/Settings/SettingsView.swift`
**Changes**: Added manual sync button
- Added "Sync Quick Add favorites" button
- Shows progress indicator while syncing
- Displays success/error alerts
- Calls `grocyVM.syncFavoritesFromServer()`

#### `Grocy Mobile/Views/Navigation/AppTabNavigation.swift`
**Changes**: Added tab visibility support
- Added `@AppStorage("enableQuickAdd")` variable
- Added `.hidden(!enableQuickAdd)` modifier for both iPhone and iPad tabs

#### `Grocy Mobile/Helper/TabOrderManager.swift`
**Changes**: Added Quick Add visibility parameter
- Added `enableQuickAdd: Bool` parameter to `syncWithAppStorage()`
- Supports hiding Quick Add tab via Settings

---

## Files Deleted

### `Grocy Mobile/Views/QuickAdd/QuickAddCategoryManagerView.swift`
**Reason**: Custom categories replaced by native Grocy Product Groups

---

## User Workflow

### Setup (One-Time)

1. **Create UserFields in Grocy**:
   - Log into Grocy web UI
   - Go to Settings → User Fields
   - Create `quick_add` (Checkbox, Products)
   - Create `note_required` (Checkbox, Products) [optional]
   - Optionally create same fields for Product Groups

2. **Mark Favorites in Grocy**:
   - Edit products or product groups
   - Check the `quick_add` checkbox
   - Check `note_required` if notes should be mandatory

3. **Sync in iOS App**:
   - Open Quick Add tab and pull-to-refresh, OR
   - Go to Settings → Sync Quick Add favorites

### Daily Use

1. **Adding to Stock**:
   - Open Quick Add tab
   - Tap product
   - Adjust amount/location if needed
   - Add note if required
   - Tap "Add"
   - Label prints automatically (if enabled)

2. **Adding New Favorites**:
   - Tap + button in Quick Add tab
   - Select product from list
   - Product added to favorites immediately
   - Server updated automatically

3. **Removing Favorites**:
   - Swipe left on product in Quick Add
   - Tap Delete
   - Server updated automatically

---

## Testing Checklist

### Basic Functionality
- [ ] Create `quick_add` UserField in Grocy
- [ ] Mark product as favorite in Grocy web UI
- [ ] Sync favorites in iOS app
- [ ] Verify product appears in Quick Add tab
- [ ] Add product to stock via Quick Add
- [ ] Verify stock was added correctly

### Product Group Features
- [ ] Create `quick_add` UserField for Product Groups entity
- [ ] Mark product group as favorite in Grocy
- [ ] Sync favorites
- [ ] Verify all products in group appear in Quick Add
- [ ] Products should be grouped under group name

### Note Requirement
- [ ] Create `note_required` UserField for Products
- [ ] Mark product as requiring note in Grocy
- [ ] Open Quick Add purchase sheet for product
- [ ] Verify note field appears at top
- [ ] Verify "Add" button disabled when note empty
- [ ] Add with note - verify note saved

### Note Requirement Inheritance
- [ ] Create `note_required` UserField for Product Groups
- [ ] Mark product group as requiring note
- [ ] Open purchase sheet for product in that group
- [ ] Verify note field appears (inherited from group)

### Label Printing
- [ ] Add product via Quick Add
- [ ] Verify label prints automatically
- [ ] Check Grocy logs for single API call (not two)

### Pull-to-Refresh
- [ ] Add favorite in Grocy web UI
- [ ] Pull down on Quick Add tab to refresh
- [ ] Verify new favorite appears

### Manual Sync
- [ ] Add favorite in Grocy web UI
- [ ] Go to Settings → Sync Quick Add favorites
- [ ] Verify progress indicator appears
- [ ] Verify success message
- [ ] Return to Quick Add - verify favorite appears

### Tab Visibility
- [ ] Go to Settings → Tab Order
- [ ] Disable Quick Add
- [ ] Verify Quick Add tab disappears
- [ ] Re-enable - verify tab reappears

### Multi-Device Sync
- [ ] Add favorite on Device A
- [ ] Sync on Device B
- [ ] Verify favorite appears on Device B
- [ ] Remove favorite on Device B
- [ ] Sync on Device A
- [ ] Verify favorite removed on Device A

### Error Handling
- [ ] Try syncing without `quick_add` UserField
- [ ] Verify appropriate error message
- [ ] Try adding to stock while offline
- [ ] Verify appropriate error handling

---

## Known Limitations

### Version 1.0

1. **UserField Setup Required**: Users must manually create UserFields in Grocy - the app cannot create them automatically
2. **No Offline Writes**: Adding/removing favorites requires network connection
3. **No Bulk Userfield API**: App must fetch userfields for each product individually (can be slow on large product catalogs)
4. **Schema Migration**: Changing `QuickAddFavorite` model deletes existing favorites (users must re-sync)

### Future Enhancements

1. **Bulk UserField Endpoint**: Request Grocy team add `/api/userfields/products` to fetch all at once
2. **Server-Side Sort Order**: Add userfield for custom sort order shared across devices
3. **Automatic UserField Detection**: Check if userfields exist and guide user through setup
4. **Offline Queue**: Queue favorite add/remove operations when offline, sync when online
5. **Sync Indicator**: Show last sync timestamp in Quick Add tab
6. **Conflict Resolution**: Handle simultaneous edits from multiple devices

---

## API Endpoints Used

### Grocy API

#### Get UserFields
```
GET /api/userfields/{entity}/{objectId}
Headers: GROCY-API-KEY: {api_key}
Response: { "quick_add": "1", "note_required": "0" }
```

#### Set UserFields
```
PUT /api/userfields/{entity}/{objectId}
Headers: GROCY-API-KEY: {api_key}
Body: { "quick_add": "1" }
```

#### Add Stock with Label Printing
```
POST /api/stock/products/{productId}/add
Headers: GROCY-API-KEY: {api_key}
Body: {
  "amount": 1,
  "best_before_date": "2026-03-01",
  "transaction_type": "purchase",
  "location_id": 1,
  "stock_label_type": 2    // Triggers automatic label printing
}
```

---

## Migration Notes

### From Local Storage to Server-Side

Users upgrading from a previous version with local-only favorites:

1. **Existing Favorites Lost**: Local favorites are NOT migrated automatically
2. **Manual Setup Required**: Users must create UserFields and mark favorites in Grocy
3. **One-Time Sync**: After setup, sync once to populate favorites

### SwiftData Schema Changes

The `QuickAddFavorite` model was changed:
- Removed `requiresNote` property
- This triggers a schema migration
- **Result**: All existing `QuickAddFavorite` entries are deleted
- **Recovery**: Users must sync from server after update

---

## Technical Notes

### Why Server-Side Storage?

**Benefits**:
- Favorites shared across all users connecting to same Grocy instance
- Single source of truth (no sync conflicts)
- Business logic belongs on server (e.g., "this product requires a note")
- Consistent behavior regardless of device or user
- Survives app reinstalls (no local data loss)

**Trade-offs**:
- Requires network for add/remove operations
- Slower initial sync (individual API calls per product)
- Requires manual UserField setup in Grocy

### Null Value Handling

UserFields can have three states:
- `"1"` - Enabled
- `"0"` - Disabled
- `null` - Not set

API returns `[String: String?]` to handle null values:
```swift
let fieldValue = userfields["quick_add"] ?? nil
let isFavorite = fieldValue == "1"
```

### Product Group Inheritance

Inheritance logic for favorites:
1. Check if product's group has `quick_add = "1"`
2. If yes, product is favorite (regardless of product-level field)
3. If no, check product-level `quick_add` field
4. Individual product field does NOT override group (additive only)

Inheritance logic for note requirement:
1. Check product-level `note_required`
2. If `"1"`, require note
3. If not set or `"0"`, check group-level `note_required`
4. Product-level CAN override group (precedence)

---

## Performance Considerations

### Sync Performance

With 500 products:
- **Worst Case**: 500 individual API calls (~30-60 seconds)
- **Network**: Each call ~100ms roundtrip
- **Optimization**: Only sync on manual request or pull-to-refresh

### UI Performance

- **Local Cache**: SwiftData query for favorites is instant
- **@Query Refresh**: Automatic UI updates when cache changes
- **Product Group Grouping**: Handled by SwiftUI ForEach (performant)

### API Call Optimization

Current:
- Sync: N calls (one per product)
- Add favorite: 1 PUT call
- Remove favorite: 1 PUT call

Future optimization:
- Request bulk endpoint from Grocy team
- Single call for all product userfields

---

## Localization Notes

User-facing strings that may need localization:

- "Quick Add"
- "No Favorites"
- "Requires note"
- "Sync Quick Add favorites"
- Empty state instructions
- Error messages

Currently all strings are in English (US).

---

## Documentation References

Related documentation:
- `barcode-buddy-integration-plan.md` - BarcodeBuddy feature (separate)
- `SPEC-grocy-swiftui-ios.md` - Full iOS app specification
- `IMPLEMENTATION_PLAN.md` - Original server-side Quick Add plan

---

## Version History

### 1.0 (February 2026)
- Server-side favorites via `quick_add` UserField
- Server-side note requirements via `note_required` UserField
- Product Group support for both features
- Pull-to-refresh sync
- Automatic label printing via `stock_label_type`
- Simplified UI (removed configuration sheet)
- Tab visibility control
- Comprehensive setup instructions

---

## Credits

**Implementation**: Claude Code (Anthropic)
**Testing**: Garth (Project Owner)
**Grocy API**: Bernd Bestel and contributors

---

## Support

For issues or questions:
1. Check setup instructions in Quick Add empty state
2. Verify UserFields created correctly in Grocy
3. Check Grocy API version (requires 4.5+)
4. Review app logs for error messages
5. File issue on GitHub repository

---

**End of Document**
