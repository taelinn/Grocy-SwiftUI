# Bundle ID Migration - Completion Summary

**Date:** 2026-02-07
**Status:** ✅ COMPLETED

---

## Migration Details

### Old Bundle Identifiers (georgappdev)
- Main App: `georgappdev.Grocy`
- Widget: `georgappdev.Grocy.Grocy-Widget`
- App Group: `group.georgappdev.Grocy`
- iCloud Container: `iCloud.georgappdev.Grocy`

### New Bundle Identifiers (roadworkstechnology)
- Main App: `com.roadworkstechnology.grocymobile`
- Widget: `com.roadworkstechnology.grocymobile.widget`
- App Group: `group.com.roadworkstechnology.grocymobile`
- iCloud Container: `iCloud.com.roadworkstechnology.grocymobile`
- UI Tests: `com.roadworkstechnology.grocymobile.tests`
- Unit Tests: `com.roadworkstechnology.grocymobile.uitests`

**Team:** Garth Coleman (Team ID: 5F87Z29RSW)

---

## Files Updated (8 files total)

### 1. Xcode Project File ✅
**File:** `Grocy Mobile.xcodeproj/project.pbxproj`
**Changes:** 12 bundle identifier references updated across all build configurations

### 2. Main App Entitlements ✅
**File:** `Grocy Mobile/Grocy Mobile/Grocy Mobile.entitlements`
**Changes:**
- iCloud container: `iCloud.georgappdev.Grocy` → `iCloud.com.roadworkstechnology.grocymobile`
- App Group: `group.georgappdev.Grocy` → `group.com.roadworkstechnology.grocymobile`

### 3. Widget Entitlements ✅
**File:** `Grocy Mobile/Grocy Widget/Grocy Widget.entitlements`
**Changes:**
- App Group: `group.georgappdev.Grocy` → `group.com.roadworkstechnology.grocymobile`

### 4. App Entry Point ✅
**File:** `Grocy Mobile/Grocy Mobile/Grocy_MobileApp.swift`
**Changes:** 3 references updated
- Line 143: Main ModelConfiguration App Group
- Line 150: Profile ModelConfiguration iCloud container
- Line 306: sharedModelContainerURL() App Group

### 5. Widget Configuration ✅
**File:** `Grocy Mobile/Grocy Widget/WidgetConfiguration.swift`
**Changes:** 1 reference updated
- Line 14: ModelConfiguration App Group

### 6. Logger ✅
**File:** `Grocy Mobile/Grocy Mobile/Helper/GrocyLogger.swift`
**Changes:** 1 reference updated
- Line 11: Logger subsystem identifier

### 7. View Model ✅
**File:** `Grocy Mobile/Grocy Mobile/Model/GrocyViewModel.swift`
**Changes:** 1 reference updated
- Line 564: Log filter subsystem identifier

### 8. Navigation ✅
**File:** `Grocy Mobile/Grocy Mobile/Views/Navigation/AppTabNavigation.swift`
**Changes:** 21 customization IDs updated
- All tab and section customization IDs updated to new bundle ID format

---

## Verification

### Code Verification ✅
- ✅ No remaining references to `georgappdev` in Swift code
- ✅ No remaining references to `georgmeissner` in Swift code
- ✅ All entitlements files updated
- ✅ Xcode project file updated

### Build Status ⚠️
- Build attempted but failed due to missing provisioning profiles (expected)
- Error: "No profiles for 'com.roadworkstechnology.grocymobile' were found"
- **Resolution Required:** Apple Developer Portal setup (see below)

---

## Next Steps for You

### 1. Apple Developer Account Setup

You need to configure the new bundle IDs in your Apple Developer account:

1. **Sign in to Xcode** (if not already done)
   - Xcode → Settings → Accounts → Add your Apple ID

2. **Create App IDs** at [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list)
   - Main App: `com.roadworkstechnology.grocymobile`
   - Widget: `com.roadworkstechnology.grocymobile.widget`

3. **Configure Capabilities** for Main App ID:
   - ✓ App Groups
   - ✓ iCloud (CloudKit)
   - ✓ Push Notifications

4. **Configure Capabilities** for Widget ID:
   - ✓ App Groups

5. **Create App Group:**
   - Go to App Groups in Certificates, Identifiers & Profiles
   - Create new: `group.com.roadworkstechnology.grocymobile`
   - Assign to both App IDs

6. **Create iCloud Container:**
   - Go to iCloud Containers
   - Create new: `iCloud.com.roadworkstechnology.grocymobile`
   - Assign to Main App ID

7. **Provisioning Profiles** (can be automatic)
   - Xcode can create these automatically when you select your team
   - Or create manually in the Developer Portal if needed

### 2. Xcode Configuration

1. Open `Grocy Mobile.xcodeproj` in Xcode
2. Select the project in the navigator
3. For **Grocy Mobile** target:
   - Go to "Signing & Capabilities" tab
   - Select Team: "Garth Coleman"
   - Bundle Identifier should show: `com.roadworkstechnology.grocymobile`
   - Ensure App Groups and iCloud capabilities are present
4. For **Grocy Widget** target:
   - Go to "Signing & Capabilities" tab
   - Select Team: "Garth Coleman"
   - Bundle Identifier should show: `com.roadworkstechnology.grocymobile.widget`
   - Ensure App Groups capability is present
5. For test targets (optional if you don't run tests):
   - Select Team: "Garth Coleman"

### 3. Build and Test

Once provisioning is set up:

1. Clean build folder: Product → Clean Build Folder (⇧⌘K)
2. Build: Product → Build (⌘B)
3. Run on simulator to verify everything works
4. Test on physical device

---

## Data Migration Impact

**Approach Used:** Option A (Accept Data Loss)

### What This Means:

- ⚠️ **Existing users will lose their local data** when they update to this version
- ⚠️ **Users will need to re-configure their Grocy server settings**
- ⚠️ **CloudKit synced profiles will not automatically transfer**

### For Your 2 Users:

Since you only have 2 users, this is acceptable. Just inform them that after updating:
1. They'll need to re-enter their Grocy server URL and API key
2. Any locally cached data (products, stock, etc.) will need to sync from the server again
3. This is a one-time migration

---

## Rollback Plan

If you need to revert these changes, the complete git diff shows all changes made. You can:

```bash
git diff HEAD
```

To rollback:
```bash
git checkout HEAD -- "Grocy Mobile.xcodeproj/project.pbxproj"
git checkout HEAD -- "Grocy Mobile/Grocy Mobile/Grocy Mobile.entitlements"
git checkout HEAD -- "Grocy Mobile/Grocy Widget/Grocy Widget.entitlements"
git checkout HEAD -- "Grocy Mobile/Grocy Mobile/Grocy_MobileApp.swift"
git checkout HEAD -- "Grocy Mobile/Grocy Widget/WidgetConfiguration.swift"
git checkout HEAD -- "Grocy Mobile/Grocy Mobile/Helper/GrocyLogger.swift"
git checkout HEAD -- "Grocy Mobile/Grocy Mobile/Model/GrocyViewModel.swift"
git checkout HEAD -- "Grocy Mobile/Grocy Mobile/Views/Navigation/AppTabNavigation.swift"
```

---

## Questions?

If you encounter any issues during the Apple Developer Portal setup or Xcode configuration, refer to the detailed guide in `BUNDLE_ID_MIGRATION.md`.
