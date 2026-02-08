# Alternate App Icons Setup Guide

## Overview

The code infrastructure for alternate app icons is complete. You now need to:
1. Create the icon assets
2. Add them to the Xcode project
3. Configure the Info.plist

## Current Implementation

### Code Files Created
1. **AppIconManager.swift** - Manages icon switching logic
2. **AppIconSettingsView.swift** - UI for selecting icons
3. **SettingsView.swift** - Updated with "App icon" navigation link

### Icons Configured
The system is set up for 4 icon variations:
- **Default** (AppIcon) - The primary app icon
- **Dark** (AppIcon-Dark) - Dark theme variant
- **Minimal** (AppIcon-Minimal) - Minimalist design
- **Classic** (AppIcon-Classic) - Classic/retro style

## Step-by-Step Setup

### Step 1: Create Icon Assets

You need to create icon image files for each alternate icon. Each icon needs these sizes for iOS:

**Required sizes per icon:**
- 60x60 @2x (120x120 pixels)
- 60x60 @3x (180x180 pixels)

**File naming convention:**
```
AppIcon-Dark@2x.png (120x120)
AppIcon-Dark@3x.png (180x180)
AppIcon-Minimal@2x.png (120x120)
AppIcon-Minimal@3x.png (180x180)
AppIcon-Classic@2x.png (120x120)
AppIcon-Classic@3x.png (180x180)
```

**Design tips:**
- Use your existing default icon as a starting point
- Dark: Darker color scheme, good for dark mode users
- Minimal: Simplified, fewer details
- Classic: Maybe use the original Grocy icon style

### Step 2: Add Icons to Xcode Project

**IMPORTANT**: Alternate icons must be added as **regular image files**, NOT in an Assets.xcassets catalog.

1. In Xcode, create a new group: `Grocy Mobile/Grocy Mobile/AlternateIcons`
2. Drag your icon PNG files into this group
3. When prompted, ensure:
   - ✅ "Copy items if needed" is checked
   - ✅ Target: "Grocy Mobile" is selected
   - ❌ DO NOT add to Assets.xcassets

Your project structure should look like:
```
Grocy Mobile/
├── Grocy Mobile/
│   ├── AlternateIcons/
│   │   ├── AppIcon-Dark@2x.png
│   │   ├── AppIcon-Dark@3x.png
│   │   ├── AppIcon-Minimal@2x.png
│   │   ├── AppIcon-Minimal@3x.png
│   │   ├── AppIcon-Classic@2x.png
│   │   └── AppIcon-Classic@3x.png
```

### Step 3: Configure Info.plist

You need to declare the alternate icons in the app's Info.plist. In modern Xcode, this is done in the project settings.

**Option A: Using Xcode Project Settings (Recommended)**

1. Select the project in Xcode
2. Select "Grocy Mobile" target
3. Go to the "Info" tab
4. Right-click in the list → "Add Row"
5. Add key: `CFBundleIcons`
6. Under `CFBundleIcons`, add:
   - `CFBundleAlternateIcons` (Dictionary)
     - `AppIcon-Dark` (Dictionary)
       - `CFBundleIconFiles` (Array)
         - Item 0: "AppIcon-Dark"
       - `UIPrerenderedIcon`: NO
     - `AppIcon-Minimal` (Dictionary)
       - `CFBundleIconFiles` (Array)
         - Item 0: "AppIcon-Minimal"
       - `UIPrerenderedIcon`: NO
     - `AppIcon-Classic` (Dictionary)
       - `CFBundleIconFiles` (Array)
         - Item 0: "AppIcon-Classic"
       - `UIPrerenderedIcon`: NO

**Option B: Using a Custom Info.plist File**

If you prefer to use an Info.plist file, create one with this content:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIcons</key>
    <dict>
        <key>CFBundleAlternateIcons</key>
        <dict>
            <key>AppIcon-Dark</key>
            <dict>
                <key>CFBundleIconFiles</key>
                <array>
                    <string>AppIcon-Dark</string>
                </array>
                <key>UIPrerenderedIcon</key>
                <false/>
            </dict>
            <key>AppIcon-Minimal</key>
            <dict>
                <key>CFBundleIconFiles</key>
                <array>
                    <string>AppIcon-Minimal</string>
                </array>
                <key>UIPrerenderedIcon</key>
                <false/>
            </dict>
            <key>AppIcon-Classic</key>
            <dict>
                <key>CFBundleIconFiles</key>
                <array>
                    <string>AppIcon-Classic</string>
                </array>
                <key>UIPrerenderedIcon</key>
                <false/>
            </dict>
        </dict>
    </dict>
</dict>
</plist>
```

Then in Xcode project settings:
1. Select "Grocy Mobile" target
2. Build Settings tab
3. Search for "Info.plist File"
4. Set the path to your Info.plist file

### Step 4: (Optional) Add Preview Images

To show actual icon previews in the settings view instead of placeholders:

1. Export smaller preview versions of your icons (e.g., 120x120)
2. Add them to `Assets.xcassets` with these names:
   - `AppIcon-Dark-Preview`
   - `AppIcon-Minimal-Preview`
   - `AppIcon-Classic-Preview`
3. Update `AppIconSettingsView.swift` to use actual images:

Replace the placeholder RoundedRectangle with:
```swift
Image(icon.previewImageName)
    .resizable()
    .frame(width: 60, height: 60)
    .cornerRadius(12)
```

## Testing

1. Build and run the app
2. Go to Settings → App Icon
3. Tap on an alternate icon
4. iOS will show a confirmation dialog
5. The icon should change on your home screen

**Note**: Icon changes only work on physical devices and simulators running iOS 10.3+. The icon will NOT change in Xcode's app list.

## Troubleshooting

### Icon doesn't change
- Verify icon files are in the project (not just Assets.xcassets)
- Check Info.plist configuration
- Ensure file names match exactly (case-sensitive)
- Check that files are included in the target's "Copy Bundle Resources" build phase

### "Alternate icons not supported" error
- This feature requires iOS 10.3+
- Won't work in certain enterprise/managed environments

### Icon appears blurry
- Ensure you've included both @2x and @3x versions
- Check that image dimensions are correct (120x120 for @2x, 180x180 for @3x)

## Customization

### Adding More Icons

To add more icon options:

1. Update `AppIconManager.swift`:
```swift
enum AppIcon: String, CaseIterable, Identifiable {
    case primary = "AppIcon"
    case dark = "AppIcon-Dark"
    case minimal = "AppIcon-Minimal"
    case classic = "AppIcon-Classic"
    case newIcon = "AppIcon-NewIcon"  // Add here

    // Update displayName switch
    case .newIcon:
        return "New Icon Name"
}
```

2. Add the icon files to the project
3. Add the entry to Info.plist
4. The settings view will automatically show the new option

## References

- [Apple Documentation: Changing Your App's Icon](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)
- [UIApplication.setAlternateIconName](https://developer.apple.com/documentation/uikit/uiapplication/2806818-setalternateiconname)
