# Mealie Integration Plan for Grocy-SwiftUI

> **Kitchen app, 2026-10-03:** this plan was adopted as the recipe feature of the new **Kitchen** app
> (gunhillpark `plans/2026-09-17-tablet-panel-rewrite/DECISIONS.md`, *Apps → Kitchen*, *Kitchen
> recipes — source decided*). Phases 1–5 are Kitchen v1, plus cook mode (steps, screen awake,
> scaling). Where this document and DECISIONS.md disagree, DECISIONS.md wins. Changed there:
> - the native Grocy Recipes screen is **dropped**, so there's no `hideGrocyRecipes` toggle;
> - Mealie credentials live in the **Keychain**, not on `ServerProfile`, and the file layout follows
>   Kitchen's;
> - **estate build sign-in is Mealie OIDC via Authelia** (`ALLOW_SIGNUP` off), with a per-user API
>   token exchange as the fallback. The neutral build uses URL + API token, as below.

## Overview

Add a **Recipes (Mealie)** tab to Grocy Mobile that browses recipes from a self-hosted [Mealie](https://mealie.io) instance, shows which ingredients are in Grocy stock, and pushes missing ingredients to a Grocy shopping list. Mealie stays the source of truth for recipes and the Mealie website remains one tap away; Grocy stays the source of truth for stock.

### Decisions

| Decision | Choice |
|----------|--------|
| MVP scope | Browse + **check stock for a recipe** + missing → Grocy shopping list + **"Cooked it" → consume from Grocy stock** |
| Mealie version | v2.x / v3.x (households API) only |
| Native Grocy Recipes | Kept; a settings toggle hides it (mirrors `enableBarcodeBuddy`) |
| Recipe sync into Grocy | **No.** Read Mealie live, cache locally for offline reading |
| Recipes live in | Mealie only. Nothing is copied into Grocy; the app reads Mealie and talks to Grocy stock directly |
| Out of scope for MVP | Meal plan, Mealie shopping lists, recipe editing, cost / due score |

---

## Architecture Summary

```
Mealie server ──REST──▶ MealieAPI ──▶ MealieViewModel (@Observable)
                                             │
             Grocy stock (@Query StockElement)┤
                                             ▼
            Grocy product userfield `mealie_food` (on parent products)
                                             │
                                             ▼
      Availability · "Add missing" · "Cooked it" (consume parent)
                                             │
                                             ▼
   GrocyViewModel.postMDObject(.shopping_list) / postStockObject(.consume)
```

Follows the BarcodeBuddy pattern: separate API client, separate `@Observable` view model, credentials on `ServerProfile`, own tab with enable toggle.

### Mealie API Details

| Item | Value |
|------|-------|
| Auth | `Authorization: Bearer <token>` (long-lived token from Mealie → Profile → API Tokens) |
| Response format | Plain JSON (no wrapper); lists are paginated `{ page, per_page, total, total_pages, items }` |
| Errors | 401 bad token, 422 `{ detail: [...] }` validation |

### Endpoints Used

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/app/about` | GET | Connection test, version check (reject < 2.0) |
| `/api/users/self` | GET | Validate token, show signed-in user |
| `/api/recipes?page=&perPage=&search=&orderBy=` | GET | Paginated recipe list (`RecipeSummary`) |
| `/api/recipes?foods=<uuid>&foods=<uuid>&requireAllFoods=` | GET | Server-side "recipes using these foods" filter |
| `/api/recipes/{slug}` | GET | Full recipe incl. `recipeIngredient`, `recipeInstructions` |
| `/api/foods?page=&perPage=` | GET | All Mealie foods (for the mapping screen) |
| `/api/media/recipes/{id}/images/min-original.webp` | GET | Thumbnail (`original.webp` for detail header) |
| `{server}/g/{groupSlug}/r/{slug}` | — | "Open in Mealie" web link (group slug from `/api/users/self`) |

---

## The Hard Part: Ingredient ↔ Product Matching

A Mealie ingredient looks like:

```json
{ "quantity": 2, "unit": { "name": "cup" }, "food": { "id": "…", "name": "oat milk" },
  "note": "", "display": "2 cups oat milk", "originalText": "2 cups oat milk" }
```

- `food` is only present when the recipe has been run through Mealie's ingredient parser. Unparsed ingredients only have `note`/`display`.
- Mealie foods are free-form and have no relationship to Grocy products.

### Strategy

1. **One food ↔ one Grocy product, usually a parent product.** Several brands or sizes of the same thing (3 kinds of tinned tomatoes) become children of one parent product, "Tinned Tomatoes". Grocy natively aggregates the children's stock into the parent (`amountAggregated`, converting units), and lets you consume the parent while it draws from the children. A product with only one variant can be mapped directly with no parent.
2. **The link lives in Grocy** as a product userfield `mealie_food` (single-line text) on the parent, holding the Mealie food name. It's editable in Grocy web as well as the app, shared across devices, and survives reinstalls.
   - Matching: case-insensitive against the Mealie food's `name`, `pluralName` and `aliases`.
   - Renaming a food in Mealie breaks the link. The mapping screen surfaces it as "unmapped", and the old value shows as an orphan tag to fix.
   - Two products with the same tag is a configuration error. Show it in the mapping screen and use neither until it's fixed.
   - Ignored foods (salt, water): a Grocy-side list isn't natural, so keep these in app settings (`@AppStorage` set of food names). Also ignore any food with no tagged product whose user chose "Ignore".
   - The app creates the userfield on first use if it's missing (`POST /objects/userfields`, entity `products`, admin rights needed; otherwise prompt the user to create it in Grocy).
   - Reading: verify whether `/objects/products` returns `userfields` inline on Grocy 4.5. If it doesn't, fetch `/userfields/products/{id}` for all products once, cache in SwiftData, and refresh on pull-to-refresh and after edits.
   - **Auto-suggest** when tagging: exact name → case/plural-insensitive → `AICategoryMatcher`-style Apple Intelligence. Prefer existing parent products. Suggestions are shown, never silently applied. Offer **Create parent product** (name prefilled from the food, via `MDProductFormView`) and then pick its children.
3. **"Ignored" foods** (salt, water, pepper) never count as missing.
4. **Unparsed ingredients** show as "not tracked", don't block availability, and get a hint to run Mealie's parser (deep link to the recipe's edit page).
5. **Unit mapping**: match Mealie unit `name` / `pluralName` / `abbreviation` / `aliases` against Grocy QU `name` / `name_plural`, case-insensitive. Exceptions go in a Grocy QU userfield `mealie_unit` (e.g. Grocy "Gram" ↔ Mealie "g").
6. **Converting an ingredient to Grocy stock units**: `quantity × (chosen servings / recipe servings)` in the Mealie unit → mapped Grocy QU → the **parent** product's stock QU via cached `MDQuantityUnitConversion` (product-specific first, then global). If any step is missing, the amount is **unknown** and the user enters it in the consume sheet.
7. **Availability per ingredient** (from cached Grocy `StockElement.amountAggregated` of the tagged product, so children count; refreshed on open):
   - amount known: stock ≥ needed → *in stock*; 0 < stock < needed → *partial*; 0 → *missing*
   - amount unknown: stock > 0 → *in stock (amount unchecked)*; 0 → *missing*

---

## Phase 1: Foundation: API Client & Settings

```
Grocy Mobile/
├── Mealie/
│   ├── API/
│   │   ├── MealieAPI.swift              // async/await client, Bearer auth, redirect blocking (copy BB pattern)
│   │   └── MealieError.swift
│   ├── Models/
│   │   ├── MealiePage.swift             // generic Pagination<T>
│   │   ├── MealieRecipeSummary.swift
│   │   ├── MealieRecipe.swift           // detail, ingredients, steps
│   │   ├── MealieFood.swift / MealieUnit.swift
│   │   ├── MealieAppInfo.swift / MealieUser.swift
│   │   └── ProductMealieTag.swift       // @Model cache of product → mealie_food userfield
│   ├── ViewModels/
│   │   └── MealieViewModel.swift
│   └── Views/
│       └── MealieSettingsView.swift
```

- `ServerProfile`: add `mealieURL: String?`, `mealieAPIToken: String?`; both optional so the CloudKit schema change stays lightweight.
- `MealieSettingsView`: URL + token + "Test connection" (`/api/app/about` + `/api/users/self`), modelled on `BBSettingsView`.
- `@AppStorage("enableMealie")`, `@AppStorage("hideGrocyRecipes")`.
- Decode only fields we use. Mealie mixes `updatedAt`/`update_at`, so don't decode timestamps we don't need.
- Enforce HTTPS warning the same way the Grocy login does (recent security hardening).

**Exit criteria:** can connect, test succeeds, credentials persist across launches.

## Phase 2: Browse & Read

```
Mealie/Views/
├── MealieRecipesTabView.swift     // NavigationStack + search + list/grid
├── MealieRecipeRowView.swift      // thumbnail, name, total time, tags
├── MealieRecipeDetailView.swift   // header image, servings, ingredients, steps
```

- Paginated infinite scroll, `.searchable` → `search=`; debounce 300 ms.
- Image loading via `AsyncImage` with the auth header (Mealie media is public by default, but allow token).
- Toolbar: **Open in Mealie** (`openURL`), **Share**.
- Cache: store last-fetched summaries + opened recipe details as SwiftData models so the tab renders instantly / offline (read-only, consistent with app's offline policy). Fold into the app-launch preload added in `b3c6b1d`.
- Navigation: `NavigationItem.mealie`, `TabNavigationItem.mealie` (SF Symbol `fork.knife`), sidebar entry, customizable-tab definition, `.hidden(!enableMealie)`; `.hidden(hideGrocyRecipes)` on native Recipes.

**Exit criteria:** browse, search, read any recipe; open it on the website.

## Phase 3: Stock Awareness

```
Mealie/Views/
├── MealieIngredientRowView.swift      // status dot: in stock / missing / unmapped / not tracked / ignored
├── MealieFoodMappingSheet.swift       // tag a Grocy (parent) product with this food, create parent, or Ignore
├── MealieFoodMappingListView.swift    // Settings → Mealie → Ingredient Mappings (bulk review)
```

- Detail view header: "7 of 9 ingredients in stock".
- Tapping an unmapped ingredient opens the mapping sheet with suggestions preselected.
- Bulk mapping screen lists all Mealie foods from `/api/foods`, sorted by how many recipes use them, with suggestions, so the user can tag once up front. It also lists orphan tags (Grocy values matching no Mealie food) and duplicate tags.
- **"Cook now" filter** on the list: collect food IDs whose mapped product is in stock, then client-side filter cached recipe details where all mapped, non-ignored foods are in stock. (Server-side `foods=` filter is "contains", not "only these", so it can't answer this alone.) Requires recipe details to be cached; fetch lazily in background with a progress indicator the first time.

**Exit criteria:** every parsed ingredient shows correct status against live Grocy stock; mappings persist.

## Phase 4: Missing → Grocy Shopping List

- Detail view button **Add missing to shopping list** → sheet listing missing mapped items (toggle each), shopping-list picker (default from user setting), then `postMDObject(.shopping_list, ShoppingListItem(productID:, amount:, shoppingListID:, note: "Mealie: <recipe>"))` per item.
- Amount: Mealie quantity scaled by chosen servings, **only** if the Mealie unit name matches the product's purchase/stock QU name; otherwise amount 1 with the Mealie text in `note`.
- Skip items already on that list (check cached `ShoppingListItem`s).
- Refresh `.shopping_list` afterwards; success toast.

**Exit criteria:** one tap adds the right items, no duplicates.

---

## Phase 5: Cooked It → Consume from Grocy

- Detail view button **Cooked it** → confirmation sheet, one row per mapped ingredient:
  - product name, stock on hand, amount to consume in the product's stock unit (prefilled from the conversion; empty and required where unknown), toggle to skip
  - not-tracked/ignored ingredients listed greyed out for reference
- **No scanning.** Confirm → `postStockObject(id: <tagged product>, stockMode: .consume, content: ProductConsume(amount:, transactionType: .consume, spoiled: false, stockEntryID: nil, locationID: nil, allowSubproductSubstitution: true, …))` per row, sequentially. Grocy picks the stock entries itself (its usual order, soonest due first) across the parent's children. Any failures are shown at the end with retry, and earlier successes aren't rolled back. Grocy's stock journal lets you undo individual bookings.
- Clamp to aggregated stock on hand with a warning (Grocy rejects consuming more than exists).
- Optional per-row location picker, for when you want to avoid drawing from the freezer.
- Afterwards refresh `.stock` / `.stock_log`. Optionally post a Mealie timeline "made" event (`POST /api/recipes/timeline/events`) so `lastMade` updates on the website.

**Exit criteria:** one confirmation consumes the right amounts; unknown conversions never guess silently.

## Testing

- Swift Testing (`@Test`) unit tests:
  - Decode `RecipeSummary` page, full `Recipe` (parsed + unparsed ingredients), `/api/app/about`, 422 error. Fixtures in `Model/Preview/TestData/mealie_*.json`.
  - Food→product suggestion matching (exact, plural, case).
  - Availability calculation (mapped / unmapped / ignored / unparsed).
  - Tag matching: name/plural/alias, case-insensitivity, duplicate tags, orphan tags.
  - Shopping-list amount logic (unit match vs fallback).
  - Conversion chain: Mealie unit → Grocy QU → stock QU (product-specific, global, missing → unknown), servings scaling.
  - Consume sheet: clamping to stock, skipped rows, partial failure reporting.
- Previews via `PreviewContainer` with Mealie fixtures.
- Manual: against a real Mealie v2 instance, including a recipe with unparsed ingredients and a token revoked mid-session.

## Later (post-MVP)

1. **Meal plan** (`/api/households/mealplans`) view + "shop for this week".
2. Widget: "You can cook N recipes tonight".
3. Optional: Mealie Shopping List ↔ Grocy shopping list bridge.

## Open Questions

- Multiple Grocy server profiles: Mealie creds live on `ServerProfile`, so each Grocy profile can point to its own Mealie. Mappings live in Grocy (the `mealie_food` / `mealie_unit` userfields), so they belong to each Grocy server. *(Kitchen: one server, credentials in the Keychain, so this question doesn't arise.)*
