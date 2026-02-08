# Bundle ID Migration Guide

## Overview

This document outlines all the changes needed to migrate the Grocy-SwiftUI app from the old `georgappdev` Apple Developer account to your new account.

---

## Current Bundle Identifiers

### Main App
- **Bundle ID:** `georgappdev.Grocy`
- **App Group:** `group.georgappdev.Grocy`
- **iCloud Container:** `iCloud.georgappdev.Grocy`

### Widget Extension
- **Bundle ID:** `georgappdev.Grocy.Grocy-Widget`
- **App Group:** `group.georgappdev.Grocy` (shared with main app)

### Test Targets
- **UI Tests:** `georgmeissner.Grocy-MobileTests`
- **Unit Tests:** `georgmeissner.Grocy-MobileUITests`

---

## New Bundle Identifiers (COMPLETED ✅)

**Team:** Garth Coleman (Team ID: 5F87Z29RSW)

### New Structure

```
Main App:           com.roadworkstechnology.grocymobile
Widget:             com.roadworkstechnology.grocymobile.widget
App Group:          group.com.roadworkstechnology.grocymobile
iCloud Container:   iCloud.com.roadworkstechnology.grocymobile
UI Tests:           com.roadworkstechnology.grocymobile.tests
Unit Tests:         com.roadworkstechnology.grocymobile.uitests
```

**Status:** All code files have been updated with the new bundle identifiers.

---

## Files That Need Updating

### 1. Xcode Project File
**File:** `Grocy Mobile.xcodeproj/project.pbxproj`

**Lines to update:**
- Line 429: Widget bundle ID (Debug config)
- Line 475: Widget bundle ID (Profile config)
- Line 520: Widget bundle ID (Release config)
- Line 577: Main app bundle ID (Debug config)
- Line 642: Main app bundle ID (Profile config)
- Line 706: Main app bundle ID (Release config)
- Line 741: UI Tests bundle ID (Debug config)
- Line 768: UI Tests bundle ID (Profile config)
- Line 794: UI Tests bundle ID (Release config)
- Line 819: Unit Tests bundle ID (Debug config)
- Line 845: Unit Tests bundle ID (Profile config)
- Line 870: Unit Tests bundle ID (Release config)

**Current values:**
```
PRODUCT_BUNDLE_IDENTIFIER = georgappdev.Grocy;
PRODUCT_BUNDLE_IDENTIFIER = "georgappdev.Grocy.Grocy-Widget";
PRODUCT_BUNDLE_IDENTIFIER = "georgmeissner.Grocy-MobileTests";
PRODUCT_BUNDLE_IDENTIFIER = "georgmeissner.Grocy-MobileUITests";
```

**Replace with your new bundle IDs**

---

### 2. Main App Entitlements
**File:** `Grocy Mobile/Grocy Mobile/Grocy Mobile.entitlements`

**Lines to update:**
- Line 11: iCloud container identifier
- Line 19: App Group identifier

**Current:**
```xml
<string>iCloud.georgappdev.Grocy</string>
<string>group.georgappdev.Grocy</string>
```

**Replace with:**
```xml
<string>iCloud.com.yourcompany.Grocy</string>
<string>group.com.yourcompany.Grocy</string>
```

---

### 3. Widget Entitlements
**File:** `Grocy Mobile/Grocy Widget/Grocy Widget.entitlements`

**Lines to update:**
- Line 7: App Group identifier

**Current:**
```xml
<string>group.georgappdev.Grocy</string>
```

**Replace with:**
```xml
<string>group.com.yourcompany.Grocy</string>
```

---

### 4. Swift Code References

#### Grocy_MobileApp.swift
**File:** `Grocy Mobile/Grocy Mobile/Grocy_MobileApp.swift`

**Line 143:** App Group in main ModelConfiguration
```swift
// Current:
groupContainer: .identifier("group.georgappdev.Grocy"),

// Replace with:
groupContainer: .identifier("group.com.yourcompany.Grocy"),
```

**Line 150:** iCloud container in profile ModelConfiguration
```swift
// Current:
cloudKitDatabase: isRunningOnSimulator() ? .none : .private("iCloud.georgappdev.Grocy")

// Replace with:
cloudKitDatabase: isRunningOnSimulator() ? .none : .private("iCloud.com.yourcompany.Grocy")
```

**Line 306:** App Group ID in sharedModelContainerURL() function
```swift
// Current:
let appGroupID = "group.georgappdev.Grocy"

// Replace with:
let appGroupID = "group.com.yourcompany.Grocy"
```

---

### 5. Other Swift Files with App Group References

Run this search to find all references:
```bash
grep -r "group.georgappdev.Grocy" --include="*.swift" .
```

**Known files that need updating:**
- `WidgetConfiguration.swift`
- `GrocyLogger.swift`
- `GrocyViewModel.swift`
- `AppTabNavigation.swift`

Replace all occurrences of `"group.georgappdev.Grocy"` with `"group.com.yourcompany.Grocy"`

---

## Apple Developer Portal Setup

### Before Making Code Changes

1. **Create App IDs** in your Apple Developer account:
   - Main App ID: `com.yourcompany.Grocy`
   - Widget ID: `com.yourcompany.Grocy.Widget`

2. **Enable Capabilities** for Main App ID:
   - App Groups
   - iCloud (CloudKit)
   - Push Notifications

3. **Enable Capabilities** for Widget ID:
   - App Groups

4. **Create App Group:**
   - Identifier: `group.com.yourcompany.Grocy`
   - Assign to both App IDs

5. **Create iCloud Container:**
   - Identifier: `iCloud.com.yourcompany.Grocy`
   - Assign to Main App ID

6. **Create Provisioning Profiles:**
   - Development profile for Main App
   - Development profile for Widget
   - Distribution profiles (if publishing)

---

## Migration Steps

### Step 1: Update Xcode Project Settings
1. Open `Grocy Mobile.xcodeproj` in Xcode
2. Select the project in the navigator
3. For each target (Grocy Mobile, Grocy Widget, test targets):
   - Go to "Signing & Capabilities"
   - Change Team to your new team
   - Update Bundle Identifier
   - For Main App and Widget: verify App Groups and iCloud containers are correct

### Step 2: Update Entitlements Files
- Update both `.entitlements` files as documented above

### Step 3: Update Swift Code
- Update all Swift files with hardcoded App Group and iCloud container strings
- Use find-and-replace for safety:
  - Find: `group.georgappdev.Grocy`
  - Replace: `group.com.yourcompany.Grocy`
  - Find: `iCloud.georgappdev.Grocy`
  - Replace: `iCloud.com.yourcompany.Grocy`

### Step 4: Clean Build
```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/Grocy*

# Clean build folder in Xcode
# Product → Clean Build Folder (Cmd+Shift+K)
```

### Step 5: Test Build
1. Build for simulator first
2. Verify no signing errors
3. Run app and check:
   - App launches successfully
   - Widget loads correctly
   - Data persistence works (SwiftData)
   - Profile sync works (if using iCloud)

### Step 6: Test on Device
1. Connect physical device
2. Build and run
3. Verify all functionality

---

## Data Migration Considerations

### User Data Impact

⚠️ **IMPORTANT:** Changing App Group and iCloud container IDs means:

1. **Users will lose local data** stored in the old App Group container
2. **CloudKit data** in the old container will not automatically transfer
3. This is effectively a **fresh install** for existing users

### Migration Strategy Options

**Option A: Accept Data Loss (Simplest)**
- Document this as a breaking change
- Users will need to re-add their Grocy servers
- Only viable if user base is small or in beta

**Option B: Data Migration Code**
- Add migration logic to read from old App Group container
- Copy data to new container on first launch
- More complex but preserves user data

**Option C: Keep Old Bundle IDs**
- Use the old bundle IDs in your new developer account
- Requires transfer of the app from old account to new account
- Preserves all user data seamlessly

---

## Recommended Approach

Given that you're migrating developer accounts, I recommend:

1. **Choose Option C if possible:** Transfer the app between Apple Developer accounts to preserve bundle IDs and user data
2. **If transfer isn't possible:** Use Option B with migration code
3. **For development/testing:** Start with Option A to test the new bundle IDs

---

## Testing Checklist

After migration:

- [ ] App builds without errors
- [ ] App launches on simulator
- [ ] App launches on physical device
- [ ] Widget appears in widget picker
- [ ] Widget displays data correctly
- [ ] Data persists after app restart
- [ ] Profile sync works (test on two devices if using iCloud)
- [ ] Server connections work
- [ ] All existing features function correctly
- [ ] No provisioning profile errors
- [ ] Push notifications work (if used)

---

## Next Steps

## Migration Completed ✅

All bundle identifiers have been successfully updated in the codebase:

### Files Updated:

1. ✅ **Xcode project file** - 12 bundle ID references updated
2. ✅ **Main app entitlements** - App Group and iCloud container IDs updated
3. ✅ **Widget entitlements** - App Group ID updated
4. ✅ **Grocy_MobileApp.swift** - 3 references updated
5. ✅ **WidgetConfiguration.swift** - App Group reference updated
6. ✅ **GrocyLogger.swift** - Logger subsystem updated
7. ✅ **GrocyViewModel.swift** - Log filter subsystem updated
8. ✅ **AppTabNavigation.swift** - 21 customization IDs updated

### Next Steps - Apple Developer Portal Setup:

**Before you can build and run the app, you need to:**

1. **Sign in to Xcode** with your Apple Developer account (Garth Coleman)
   - Xcode → Settings → Accounts → Add (+)

2. **Create App IDs** in your Apple Developer account portal:
   - Main App ID: `com.roadworkstechnology.grocymobile`
   - Widget ID: `com.roadworkstechnology.grocymobile.widget`

3. **Enable Capabilities** for Main App ID:
   - App Groups
   - iCloud (CloudKit)
   - Push Notifications

4. **Enable Capabilities** for Widget ID:
   - App Groups

5. **Create App Group:**
   - Identifier: `group.com.roadworkstechnology.grocymobile`
   - Assign to both App IDs

6. **Create iCloud Container:**
   - Identifier: `iCloud.com.roadworkstechnology.grocymobile`
   - Assign to Main App ID

7. **Create Provisioning Profiles:**
   - Development profile for Main App
   - Development profile for Widget

8. **In Xcode Project Settings:**
   - Select "Grocy Mobile" target → Signing & Capabilities
   - Select your team from the dropdown
   - Xcode will automatically create/download provisioning profiles
   - Repeat for "Grocy Widget" target

### Data Migration Note:

**Approach:** Option A (Accept Data Loss) - You chose this option since you only have 2 users.

⚠️ **Important:** Existing users will need to re-add their Grocy server credentials after updating to this version, as the App Group container has changed. Their local data will not transfer automatically.

