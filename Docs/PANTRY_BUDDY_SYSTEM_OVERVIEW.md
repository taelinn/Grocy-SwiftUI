# PantryBuddy System Overview

**Last Updated:** February 2026

This document provides a comprehensive technical overview of PantryBuddy for context when working on new features or integrations.

## System Purpose

PantryBuddy is a Raspberry Pi-based kitchen scanner station that integrates with Grocy (inventory management), Barcode Buddy (barcode processing), and Home Assistant. It automates food inventory tracking and prints smart labels with multiple date tracking (cooked, use by, freeze by, freezer use by) and DataMatrix barcodes for iOS app scanning.

## Hardware Components

- **Raspberry Pi 4B 2GB** (hostname: Unhygienix, IP: 192.168.10.31)
- **7" DSI Touchscreen** - 800x480 display running Home Assistant dashboard in Chromium kiosk mode
- **NETUM C750 Bluetooth 2D Barcode Scanner** - Auto-reconnecting HID scanner
- **Brother QL-600 USB Label Printer** - Prints 29x90mm die-cut labels

## Software Architecture

### Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                  Raspberry Pi (PantryBuddy)                  │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────┐        ┌──────────────────┐            │
│  │ grocy-scanner  │◄──────►│   label-api      │            │
│  │   (main.py)    │        │ (label_api.py)   │            │
│  │                │        │                  │            │
│  │ - Scanner      │        │ - Flask :9285    │            │
│  │ - Display      │        │ - Grocy webhook  │            │
│  │ - BB Client    │        │ - Label printer  │            │
│  └────────────────┘        └──────────────────┘            │
│         │                           │                       │
│         └───────────┬───────────────┘                       │
└─────────────────────┼─────────────────────────────────────┘
                      │
        ┌─────────────┼─────────────────┐
        ▼             ▼                 ▼
  ┌──────────┐  ┌──────────┐  ┌─────────────────┐
  │ Barcode  │  │  Grocy   │  │ Home Assistant  │
  │  Buddy   │◄─┤          │  │                 │
  │  :9280   │  │  :9283   │  │  - Dashboards   │
  └──────────┘  └──────────┘  └─────────────────┘
   .60/.60         .60/.60
```

### Service Architecture

**Two systemd services run on the Pi:**

1. **grocy-scanner.service** (`src/main.py`)
   - Runs the main scanner station application
   - Reads barcodes from Bluetooth scanner
   - Sends scans to Barcode Buddy
   - Auto-prints labels for Ready Meals (Product Group 1) in PURCHASE mode
   - Manages legacy ST7796 SPI display (now mostly replaced by HA kiosk)

2. **label-api.service** (`src/label_api.py`)
   - Flask HTTP server on port 9285
   - Receives Grocy webhook when user clicks "Print" button
   - Calculates dates based on product due dates settings
   - Generates and prints labels via Brother QL-600
   - Supports multiple label templates by product group
   - Handles freezer location detection for simplified labels

## Data Flow

### Barcode Scanning Flow

```
1. Scanner reads barcode
   ↓
2. BarcodeScanner (reader.py) processes HID input
   ↓
3. GrocyScannerApp (main.py) receives barcode string
   ↓
4. Sends to Barcode Buddy via BarcodeBuddyClient
   ↓
5. If Ready Meal + PURCHASE mode:
   - Parses grocycode (grcy:p:123) to extract product_id
   - Calls GrocyClient.calculate_label_dates()
   - Calls LabelPrinter.print_product_label()
   - Brother QL-600 prints label
```

### Grocy Webhook Printing Flow

```
1. User clicks "Print" in Grocy web UI
   ↓
2. Grocy sends POST to http://192.168.10.31:9285/grocy
   ↓
3. label_api.py receives JSON payload:
   {
     "data": {
       "stock_entry": {
         "product_id": 123,
         "stock_id": "abc123",
         "location_id": 3,  # 2=Fridge, 3=Freezer, 4=Chest Freezer
         "amount": 2        # Quantity for multiple labels
       }
     }
   }
   ↓
4. Fetches product details from Grocy API
   ↓
5. Calculates dates from product.due_days settings
   ↓
6. Determines label template by product_group_id:
   - Group 1: Ready Meals (Cooked, Use By, Freeze By, Freezer Use By)
   - Groups 7/10: Meat/BBQ (Purchased, Use By, Freeze By, Freezer Use By)
   - Group 5: Spices (Best Before only)
   - Product 282: Leftovers (blank name field)
   ↓
7. Detects if location is freezer (location_id in [3,4])
   - If freezer: prints simplified 2-date label (Purchased, Freezer Use By)
   - If fridge: prints full 4-date label
   ↓
8. Generates PIL image with:
   - Product name (dynamic font sizing: 52pt → 42pt → 34pt → truncate)
   - Date fields in DD/MM/YY format
   - DataMatrix 2D barcode: grcy:p:{product_id}:{stock_id}
   ↓
9. Sends to Brother QL-600 via brother_ql library
   ↓
10. Prints quantity copies (if amount > 1)
```

## Key Components Detail

### BarcodeScanner (scanner/reader.py)

**Purpose:** Reads Bluetooth HID barcode scanner input via evdev

**Key Features:**
- Auto-reconnection when scanner wakes from sleep
- Handles device path changes on reconnection (e.g., /dev/input/event5 → event6)
- Clears cached device path on disconnect to force re-search by name
- Grabs exclusive device access to prevent input leaking to X11/Chromium
- Runs in background thread with callback for scanned barcodes

**Configuration:**
```python
SCANNER_NAME = 'C barcode scanner'  # Device name to search for
SCANNER_DEVICE = None  # Auto-detect, or explicit path
```

**Auto-reconnection Logic:**
- Searches for device by name if path not explicitly set
- Caches device path on first connection
- On disconnect, clears cached path (unless user set explicit path)
- Re-searches by name on next connection attempt
- Handles Bluetooth device path changes seamlessly

### LabelPrinter (integration/printer.py)

**Purpose:** Generates label images and sends to Brother QL-600

**Label Templates:**
- Ready Meals (Group 1): 4 dates
- Meat (Group 7): 4 dates fridge, 2 dates freezer
- BBQ Meat (Group 10): 4 dates fridge, 2 dates freezer
- Spices (Group 5): Best Before only
- Leftovers (Product 282): Blank name field for handwriting

**Dynamic Font Sizing:**
```python
# Tries 3 font sizes before truncating
title_fonts = [
    font_title_large,   # 52pt
    font_title_medium,  # 42pt
    font_title_small,   # 34pt
]
```
- Measures text width with each font
- Uses largest font that fits in 811px width
- Only truncates as last resort with ellipsis

**Freezer Detection:**
```python
FREEZER_LOCATION_IDS = [3, 4]  # Freezer, Chest Freezer
is_freezer = location_id in FREEZER_LOCATION_IDS
```
- For meat/BBQ in freezer: shows only Purchased + Freezer Use By
- For meat/BBQ in fridge: shows all 4 dates

**DataMatrix Barcodes:**
- Uses pylibdmtx to encode grocycode
- Format: `grcy:p:{product_id}:{stock_id}`
- iOS Grocy app can scan to consume specific stock entry

**Brother QL-600 Integration:**
- Uses brother_ql library with QL-700 profile (QL-600 not directly supported)
- USB path: `usb://0x04f9:0x20c0`
- Requires root/sudo for USB access
- Label size: 29x90mm die-cut labels

### GrocyClient (integration/grocy.py)

**Purpose:** Interface with Grocy API for product info and date calculations

**Key Methods:**
```python
get_product(product_id) -> dict
  # Returns product details including name, group_id, due_days settings

calculate_label_dates(product_id) -> dict
  # Returns: cooked_date, use_by, freeze_by, freezer_use_by
  # Based on product.due_days and product.due_days_after_freezing
```

**Date Calculation Logic:**
```python
# Today as reference
cooked_date = today

# Fridge dates (from due_days)
use_by = today + due_days (e.g., +7 days)
freeze_by = use_by - 3 days

# Freezer dates (from due_days_after_freezing)
freezer_use_by = today + due_days_after_freezing (e.g., +180 days)
```

**Date Format:**
- Grocy API returns ISO format: YYYY-MM-DD
- Labels display: DD/MM/YY

### BarcodeBuddyClient (integration/barcodebuddy.py)

**Purpose:** Interface with Barcode Buddy for barcode processing

**Modes:**
- CONSUME: Subtracts from stock
- PURCHASE: Adds to stock
- OPEN: Opens product (tracks opened date)

**Key Methods:**
```python
scan(barcode) -> dict
  # Sends barcode to BB, returns success/error and product name

set_mode(mode) -> dict
  # Changes BB mode (CONSUME/PURCHASE/OPEN)

get_info() -> dict
  # Gets BB version and status
```

### DisplayManager (display/manager.py)

**Purpose:** Legacy ST7796 SPI display driver (mostly replaced by HA kiosk)

**Current Status:**
- Still initialized by main.py for backwards compatibility
- Physical display replaced by 7" DSI screen showing HA dashboard
- Mode/status display functions still called but not actively used
- Touch input detection code present but not used in kiosk mode

**Kiosk Mode:** `~/kiosk.sh` launches Chromium pointing to Home Assistant dashboard, started via crontab on boot.

## Configuration Files

### config/config.py

```python
# Grocy
GROCY_URL = 'http://192.168.10.60:9283'
GROCY_API_KEY = 'your_api_key'

# Barcode Buddy
BB_URL = 'http://192.168.10.60:9280'
BB_API_KEY = 'your_api_key'

# Scanner
SCANNER_NAME = 'C barcode scanner'
SCANNER_DEVICE = None  # Auto-detect

# Display (legacy)
DEFAULT_MODE = 'CONSUME'

# Printer
PRINTER_ENABLED = True
READY_MEAL_GROUP_ID = 1  # Auto-print for this group in PURCHASE mode
```

### label_api.py Constants

```python
FREEZER_LOCATION_IDS = [3, 4]  # Grocy location IDs for freezer detection

# Product group IDs for template selection
GROUP_READY_MEALS = 1
GROUP_SPICES = 5
GROUP_MEAT = 7
GROUP_BBQ_MEAT = 10
PRODUCT_LEFTOVERS = 282
```

### Grocy config.php Settings

```php
Setting('LABEL_PRINTER_WEBHOOK', 'http://192.168.10.31:9285/grocy');
Setting('LABEL_PRINTER_RUN_SERVER', true);
Setting('LABEL_PRINTER_PARAMS', ['font_family' => 'Source Sans Pro (Regular)']);
Setting('LABEL_PRINTER_HOOK_JSON', true);
```

## API Endpoints

### Label API (Port 9285)

**POST /grocy**
- Receives Grocy webhook for label printing
- Content-Type: application/json
- Payload structure:
  ```json
  {
    "data": {
      "stock_entry": {
        "product_id": 123,
        "stock_id": "abc-123-def",
        "location_id": 3,
        "amount": 2
      }
    }
  }
  ```
- Returns: `{"success": true}` or `{"success": false, "error": "..."}`

**POST /test**
- Test endpoint for manual label printing
- Payload: Same as /grocy
- Used for development/debugging

### Grocy API (External)

**GET /api/objects/products/{product_id}**
- Returns product details including name, group_id, due_days
- Requires API key in header: `GROCY-API-KEY`

### Barcode Buddy API (External)

**POST /api/action/scan**
- Sends barcode for processing
- Returns product name and action taken

**POST /api/state/setMode**
- Sets scanning mode (CONSUME/PURCHASE/OPEN)

## Grocycode Format

**Standard Grocy format:**
- Product code: `grcy:p:{product_id}` (e.g., `grcy:p:123`)
- Stock entry code: `grcy:p:{product_id}:{stock_id}` (e.g., `grcy:p:123:abc-def-123`)

**PantryBuddy usage:**
- DataMatrix on labels encodes full stock entry code
- Allows iOS app to consume specific stock entry (FIFO tracking)
- Scanner station can read either format

## Important Implementation Details

### Type Conversion for Product IDs

**Critical:** Grocy webhook JSON returns product_group_id and product_id as strings, but code uses integer constants for comparison:

```python
# Must convert to int for comparison
product_group_id = int(product_info.get('product_group_id'))
product_id = int(stock_entry.get('product_id'))

# Then compare against constants
if product_group_id == GROUP_MEAT:  # 7
if product_id == PRODUCT_LEFTOVERS:  # 282
```

### Location Detection

**Stock entry location vs Product default location:**
- `product_info.location_id` = product's default location (not useful)
- `stock_entry.location_id` = actual location of this stock entry (use this!)

```python
# Correct way to detect freezer
stock_entry = data.get('stock_entry', {})
location_id = stock_entry.get('location_id')
is_freezer = location_id in FREEZER_LOCATION_IDS
```

### Scanner Device Path Handling

**Problem:** Bluetooth devices get new paths on reconnection
**Solution:** Clear cached path on disconnect, re-search by name

```python
# Track if path was explicitly set vs auto-detected
self._explicit_path = device_path is not None

# On disconnect, clear cached path to force re-search
if not self._explicit_path:
    self.device_path = None
```

### Brother Printer USB Access

- Requires root/sudo for direct USB access
- Services run as root via systemd
- Test prints: `sudo brother_ql -b pyusb --model QL-700 -p usb://0x04f9:0x20c0 print -l 29x90 test.png`

## File Structure

```
~/grocy-scanner/
├── README.md                    # User documentation
├── CLAUDE.md                    # Claude Code instructions
├── SYSTEM_OVERVIEW.md          # This file
├── kiosk.sh                    # Chromium kiosk startup script
├── config/
│   └── config.py               # Main configuration
└── src/
    ├── main.py                 # Scanner station app (grocy-scanner service)
    ├── label_api.py            # Label API server (label-api service)
    ├── display/
    │   └── manager.py          # Legacy ST7796 display driver
    ├── scanner/
    │   └── reader.py           # Bluetooth scanner with auto-reconnect
    └── integration/
        ├── barcodebuddy.py     # Barcode Buddy API client
        ├── grocy.py            # Grocy API client
        └── printer.py          # Label printer with templates
```

## Recent Changes (Feb 2026)

1. **Freezer-aware labels**: Simplified 2-date format when `location_id in [3,4]`
2. **Dynamic font sizing**: Three-tier font sizing (52pt → 42pt → 34pt) before truncation
3. **Scanner reconnection fix**: Clears cached device path on disconnect
4. **Label text corrections**: "Purchased:" instead of "Purchase:", "Freezer Use By:" instead of "Freezer By:"
5. **Product group fix**: BBQ Meat corrected to group 10 (was incorrectly 11)

## Future Development Notes

### For iOS App Integration

- DataMatrix codes on labels encode full stock entry: `grcy:p:{product_id}:{stock_id}`
- iOS Grocy app can scan to consume specific entry
- Consider QR codes if DataMatrix has scanning issues on iOS

### For Barcode Buddy Extensions

- Current flow: Scanner → BB → Grocy
- BB handles product lookup and stock adjustments
- Mode changes via HA dashboard buttons (future) or scanner station buttons (legacy)

### For Home Assistant Integration

**Planned:**
- Meal prep buttons to auto-add stock + print labels
- Product lookup dashboard
- Voice feedback via HA Voice PE
- Integration with HA automations for stock notifications

**Current:**
- Kiosk displays HA dashboard on touchscreen
- No active automation integration yet
- Opportunity for bi-directional integration

## Testing

### Individual Module Testing

Each module has `if __name__ == '__main__'` blocks:

```bash
python3 src/display/manager.py      # Test display
python3 src/scanner/reader.py       # Test scanner
python3 src/integration/printer.py  # Test printer
python3 src/integration/grocy.py    # Test Grocy API
python3 src/integration/barcodebuddy.py [API_KEY]  # Test BB API
```

### Service Testing

```bash
# View logs
journalctl -u grocy-scanner -f
journalctl -u label-api -f

# Restart services
sudo systemctl restart grocy-scanner
sudo systemctl restart label-api

# Check status
sudo systemctl status grocy-scanner
sudo systemctl status label-api
```

### Manual Label Printing

```bash
# Via API
curl -X POST http://192.168.10.31:9285/test \
  -H "Content-Type: application/json" \
  -d '{"data": {"stock_entry": {"product_id": 123, "stock_id": "abc", "location_id": 2, "amount": 1}}}'

# Direct printer test
python3 src/integration/printer.py
```

## Common Gotchas

1. **Product group comparison fails**: Remember to `int()` convert JSON values
2. **Wrong location detected**: Use `stock_entry.location_id` not `product.location_id`
3. **Scanner won't reconnect**: Device path changed - fixed by clearing cached path
4. **Printer "device not found"**: Need sudo/root for USB access
5. **Labels truncate with space**: Adjust `max_title_width` reserved space (currently 180px)
6. **Date formats wrong**: Grocy returns ISO (YYYY-MM-DD), labels show DD/MM/YY

## Network Information

- **PantryBuddy Pi**: 192.168.10.31 (Unhygienix)
- **Grocy/BB Server**: 192.168.10.60
- **Grocy Port**: 9283
- **Barcode Buddy Port**: 9280
- **Label API Port**: 9285

---

*This document should be provided to Claude Code when starting work on iOS app integration, HA automations, or Barcode Buddy extensions to give full context of the existing system.*
