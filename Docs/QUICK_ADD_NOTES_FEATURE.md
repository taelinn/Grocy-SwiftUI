# Quick Add Notes Feature

## Overview

Enhanced the Quick Add feature to support optional notes for specific items, perfect for tracking leftovers and other items that need description at purchase time.

---

## Use Case: Leftovers Tracking

**Problem:** You have a generic "Leftovers" product in Grocy for tracking leftover food. When you put away leftovers, you need to:
1. Add the item to stock quickly
2. Specify what the leftovers actually are (e.g., "Chicken Stir Fry")
3. Print a label with the specific dish name
4. Track it to prevent eating 3-week-old rice

**Solution:** The notes field stores the specific description with the stock entry, which can be used by your label printing system to create properly labeled containers.

---

## How It Works

### 1. Adding a Favorite with Notes Required

When adding a product to Quick Add favorites:
1. Select the product from the list
2. A configuration sheet appears
3. Toggle "Requires note" ON for items like "Leftovers"
4. Tap "Add" to save

**Configuration Sheet Details:**
- **Toggle**: "Requires note"
- **Description**: "Ask for a note every time (e.g., for tracking leftovers)"
- **Footer explanation**: Explains that the note is stored with the stock entry and can be used for label printing

### 2. Visual Indicators

Items that require notes show an orange note icon (📝) next to their name in the favorites list. This makes it easy to identify which items need descriptions.

### 3. Quick Add Flow with Notes

When tapping a favorite that requires notes:
1. Quick Add sheet opens
2. **Note section automatically appears** with:
   - TextField: "What is it?"
   - Multi-line support (2-4 lines)
   - Helper text explaining the note will be stored and used for labels
3. The "Add" button is disabled until a note is entered
4. Fill in amount, location, and note
5. Tap "Add" - product added with note attached

### 4. Quick Add Flow without Notes

Items that don't require notes show the same streamlined interface as before - no notes field clutters the UI.

---

## Implementation Details

### Model Changes

**QuickAddFavorite.swift**
```swift
@Model
final class QuickAddFavorite {
    var id: UUID
    var productID: Int
    var sortOrder: Int
    var requiresNote: Bool  // NEW
    var dateAdded: Date

    init(productID: Int, sortOrder: Int = 0, requiresNote: Bool = false)
}
```

### UI Components

**New Component: QuickAddConfigSheet**
- Appears when adding a favorite
- Displays product name
- Toggle for "Requires note"
- Helpful explanations

**Updated: QuickAddTabView**
- Shows note icon for items requiring notes
- Passes `requiresNote` flag when creating favorites

**Updated: QuickAddPurchaseSheet**
- Conditionally shows note section based on `favorite.requiresNote`
- Validates that note is filled when required
- Sends note to Grocy with the purchase

---

## User Experience

### For Regular Items (e.g., Milk, Eggs)
1. Tap favorite → Quick Add sheet opens
2. Adjust amount/location if needed
3. Tap "Add" → Done!

**No extra fields, no clutter.**

### For Items Requiring Notes (e.g., Leftovers)
1. Tap "Leftovers" favorite → Quick Add sheet opens
2. Note field automatically appears
3. Type "Chicken Stir Fry" in note field
4. Adjust amount/location if needed
5. Tap "Add" → Done!

**Note is stored with the stock entry.**

---

## Integration with Label Printing

The note is sent to Grocy in the `note` field of the purchase transaction. Your label printing system can:

1. Check if the stock entry has a note
2. If present, use it for the label text
3. If not present, use the product name

**Example label printing logic:**
```python
# Pseudo-code for label printing
stock_entry = get_stock_entry(entry_id)
label_text = stock_entry.note if stock_entry.note else stock_entry.product_name
print_label(label_text, best_before_date, etc.)
```

This means:
- **Leftovers with note "Chicken Stir Fry"** → Label shows "Chicken Stir Fry"
- **Milk (no note)** → Label shows "Milk"

---

## Benefits

### 1. Clean UI
- Notes only appear when needed
- No cluttered interface for simple items
- Consistent experience

### 2. Flexible
- Any product can require notes
- Not hardcoded to specific product IDs
- Easy to add/remove note requirement

### 3. Discoverable
- Orange note icon shows which items need notes
- Helpful explanatory text guides users
- Can't forget to add note (validation prevents submission)

### 4. Workflow Optimized
- Fast for regular items (no extra steps)
- Thorough for complex items (ensures description captured)
- Note is stored exactly where it needs to be

---

## Example Workflows

### Workflow 1: Putting Away Chicken Stir Fry Leftovers

1. Put leftovers in container
2. Open app → Quick Add tab
3. Tap "Leftovers"
4. Type "Chicken Stir Fry" in note field
5. Confirm amount: 1
6. Confirm location: Fridge
7. Tap "Add"
8. Print label button → Label prints with "Chicken Stir Fry"
9. Stick label on container
10. Done!

**Time saved:** No need to navigate through multiple screens, no manual typing of product name

### Workflow 2: Adding Regular Product

1. Open app → Quick Add tab
2. Tap "Milk"
3. Adjust amount if needed
4. Tap "Add"
5. Done!

**Time saved:** Same as before, no extra fields

### Workflow 3: Setting Up Leftovers Favorite

1. Quick Add tab → Tap + button
2. Search for "Leftovers"
3. Select it
4. Configuration sheet appears
5. Toggle "Requires note" ON
6. Tap "Add"
7. Leftovers now in favorites with note icon
8. Done - ready to use!

---

## Technical Notes

### SwiftData Schema
The `requiresNote` property is stored in SwiftData and persists across app restarts.

### Validation
- Note field is required when `requiresNote` is true
- Empty notes are converted to `nil` before sending to Grocy
- "Add" button disabled until all required fields filled

### Note Storage
Notes are stored in Grocy's standard `note` field for stock entries, which means:
- Visible in Grocy web interface
- Searchable
- Available via Grocy API
- No custom database changes needed

---

## Future Enhancements

Possible future improvements:
1. **Note templates** - Pre-fill common notes (e.g., "Chicken", "Beef", "Pasta")
2. **Recent notes** - Show recently used notes for quick selection
3. **Barcode scanner** - Scan custom barcodes for specific leftover types
4. **Photo attachment** - Take photo of leftovers (would require Grocy API enhancement)
5. **Auto-suggest** - AI-powered suggestions based on recent meals

---

## Summary

This enhancement makes Quick Add even more powerful by supporting the specialized workflow for leftovers while keeping the interface clean for regular items. The key insight is that **different products need different levels of detail**, and the UI should adapt accordingly.

**Net result:** Faster, more accurate leftover tracking with proper labeling, without slowing down regular quick-add operations.
