# BarcodeBuddy API Enhancement Spec
# For use with Claude Code in VS Code

## Context

This is a fork of BarcodeBuddy (https://github.com/Forceu/barcodebuddy). We are adding and enriching API endpoints so that a companion iOS app (Grocy-SwiftUI) can connect to BarcodeBuddy to review and process unresolved barcodes.

## Existing Custom Endpoint

There is already a custom endpoint at `/system/unknownbarcodes` that was added to the API route definitions. It currently looks like this:

```php
$this->addRoute(new ApiRoute("/system/unknownbarcodes", function () {
    $barcodes = DatabaseConnection::getInstance()->getStoredBarcodes();
    $unknownBarcodes = $barcodes["unknown"];
    return self::createResultArray(array(
        "count" => count($unknownBarcodes),
        "barcodes" => array_map(function($item) {
            return array(
                "barcode" => $item['barcode'],
                "amount" => $item['amount']
            );
        }, $unknownBarcodes)
    ));
}));
```

## Database Schema (relevant tables)

```sql
CREATE TABLE Barcodes(id INTEGER PRIMARY KEY, barcode TEXT NOT NULL, name TEXT NOT NULL, possibleMatch INTEGER, amount INTEGER NOT NULL, requireWeight INTEGER, bestBeforeInDays INTEGER, price TEXT, bbServerAltNames TEXT);
CREATE TABLE BarcodeLogs(id INTEGER PRIMARY KEY, log TEXT NOT NULL);
```

## Existing Data Layer

The method `DatabaseConnection::getInstance()->getStoredBarcodes()` already fetches all barcodes and categorises them into three arrays:

- `$barcodes["known"]` — barcodes where `name != "N/A"` (name was successfully looked up)
- `$barcodes["unknown"]` — barcodes where `name == "N/A"` (lookup failed)
- `$barcodes["tare"]` — barcodes where `requireWeight == "1"`

Each `$item` in these arrays already contains: `id`, `barcode`, `amount`, `name`, `match` (= possibleMatch from DB), `tare`, `bestBeforeInDays`, `price`, `bbServerAltNames`.

## Authentication

All API endpoints use the `BBUDDY-API-KEY` header for authentication. This is handled by the existing API routing framework — new routes added via `$this->addRoute()` inherit this automatically.

---

## Task 1: Enrich the existing GET /system/unknownbarcodes endpoint

**Replace** the existing `/system/unknownbarcodes` route with an enriched version.

**Requirements:**
- Combine both `$barcodes["known"]` AND `$barcodes["unknown"]` into one list (they are both "unresolved" from the iOS app's perspective — neither is linked to a Grocy product yet)
- Expose the following fields for each barcode:
  - `id` (integer) — from `$item['id']`
  - `barcode` (string) — from `$item['barcode']`
  - `amount` (integer) — from `$item['amount']`
  - `name` (string or null) — from `$item['name']`, but convert "N/A" to null
  - `possibleMatch` (integer or null) — from `$item['match']`
  - `isLookedUp` (boolean) — true if name is not "N/A"
  - `bestBeforeInDays` (integer or null) — from `$item['bestBeforeInDays']`
  - `price` (string or null) — from `$item['price']`
  - `altNames` (array or null) — from `$item['bbServerAltNames']`
- Keep the `count` field at the top level
- Ensure all integer fields are cast to int (not returned as strings)
- Use `self::createResultArray()` to wrap the response

---

## Task 2: Add DELETE /system/unknownbarcodes/{id} endpoint

**New endpoint** to delete/dismiss a single barcode from the unresolved list.

**Requirements:**
- Accept a barcode `id` as a URL path parameter
- Validate that `id` is a positive integer, return 400 if not
- Check the barcode exists in the `Barcodes` table, return 404 if not found
- Delete the row from the `Barcodes` table
- Return `{ "deleted": <id> }` wrapped in `self::createResultArray()`
- Use the existing database connection pattern (`DatabaseConnection::getInstance()` or direct SQLite access via `getDbConnection()`)
- Register as a DELETE method route

---

## Task 3: Add POST /system/unknownbarcodes/{id}/associate endpoint

**New endpoint** to associate a barcode with a Grocy product and remove it from the unresolved list.

**Requirements:**
- Accept a barcode `id` as a URL path parameter
- Accept `productId` as a POST/form parameter (required, positive integer)
- Validate both `id` and `productId`, return 400 with descriptive error if invalid
- Look up the barcode record from the `Barcodes` table, return 404 if not found
- Call the Grocy API to add this barcode to the specified product. Look at how the existing BB codebase adds barcodes to Grocy products (search for how the web UI's "Add" button works when a user selects a product from the dropdown and submits). Use the same Grocy API helper/method.
- On success, delete the barcode from the `Barcodes` table
- Return `{ "associated": true, "barcodeId": <id>, "barcode": "<value>", "productId": <productId> }` wrapped in `self::createResultArray()`
- If the Grocy API call fails, return 500 with an error message and do NOT delete the barcode

---

## Task 4: Add GET /system/barcodelogs endpoint

**New endpoint** to return processed barcodes history from the `BarcodeLogs` table.

**Requirements:**
- Accept an optional `limit` query parameter (default 50, max 200, min 1)
- Query `BarcodeLogs` ordered by `id DESC` with the limit applied
- Return each row with `id` (integer) and `log` (string)
- Wrap in `self::createResultArray()` with a `count` field and a `logs` array

---

## General Guidelines

- Follow the existing code patterns and style in the BB codebase
- Use the same database access patterns already used elsewhere in the API
- All new routes should be added in the same file/location as the existing custom route
- Test each endpoint with curl after implementation:
  ```
  curl -s -H "BBUDDY-API-KEY: <key>" http://localhost:9280/api/system/unknownbarcodes | python3 -m json.tool
  curl -s -X DELETE -H "BBUDDY-API-KEY: <key>" http://localhost:9280/api/system/unknownbarcodes/1 | python3 -m json.tool
  curl -s -X POST -H "BBUDDY-API-KEY: <key>" -d "productId=42" http://localhost:9280/api/system/unknownbarcodes/1/associate | python3 -m json.tool
  curl -s -H "BBUDDY-API-KEY: <key>" "http://localhost:9280/api/system/barcodelogs?limit=10" | python3 -m json.tool
  ```
