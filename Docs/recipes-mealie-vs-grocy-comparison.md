# Recipes: Mealie vs Grocy — Feature Comparison

Purpose: decide where recipes should live (Mealie, Grocy, or a fork of one), before building the Mealie integration in `mealie-integration-plan.md`.

Versions considered: Grocy 4.5+, Mealie 2.x/3.x. Grocy fields are taken from this app's models (`Model/Recipes/`); Mealie fields from its OpenAPI schema and docs.

Legend: ✅ built in · 🟡 partial / workaround · ❌ not available

---

## 1. Getting recipes in

| Feature | Grocy | Mealie | Notes |
|---|---|---|---|
| Manual entry | ✅ | ✅ | |
| Import from URL (schema.org scraper) | ❌ | ✅ | Mealie's biggest single advantage. Browser bookmarklet + share-sheet friendly |
| AI import (text, photo, HTML) | ❌ | ✅ | v3.23+, needs an AI provider configured |
| AI fallback when scraper fails | ❌ | ✅ | |
| Migrate from other apps | ❌ | ✅ | Paprika, Tandoor, Nextcloud Cookbook and others |
| Bulk import via API | 🟡 | ✅ | Grocy has a generic objects API, but there's nothing to parse a recipe |

## 2. Recipe data model

| Feature | Grocy | Mealie | Notes |
|---|---|---|---|
| Name, description, picture | ✅ | ✅ | |
| Instructions | 🟡 single HTML field | ✅ structured steps | Mealie steps have titles, text, and links to the ingredients each step uses |
| Servings + scaling | ✅ base/desired servings | ✅ | |
| Prep / cook / total time | ❌ (userfield) | ✅ | |
| Source URL | ❌ (userfield) | ✅ `orgURL` | |
| Tags / categories | ❌ (userfield) | ✅ tags, categories, tools | |
| Cookbooks (saved filtered collections) | ❌ | ✅ | |
| Notes, attachments | 🟡 description only | ✅ notes + assets | |
| Nutrition | 🟡 calories only, computed from products | ✅ manual per-recipe fields | Different approach: Grocy computes, Mealie stores |
| Ingredient groups/sections | ✅ `ingredient_group` | ✅ `title` | |
| Sub-recipes | ✅ nestings with servings | ✅ `referencedRecipe` | Grocy also includes nested ingredients in stock checks |
| Custom fields | ✅ userfields | 🟡 `extras` (API only) | |

## 3. Ingredients ↔ inventory (Grocy's home ground)

| Feature | Grocy | Mealie | Notes |
|---|---|---|---|
| Ingredient linked to a real product | ✅ required | 🟡 "food" (no stock) | Mealie foods are labels only, with no quantity on hand |
| Unit conversion per product | ✅ product QU conversions | 🟡 standard units only | |
| Free-text → structured parsing | ❌ (entered structured) | ✅ NLP / brute / AI parser | |
| "Can I make this?" (stock fulfilment) | ✅ | ❌ | `need_fulfilled`, `missing_products_count` |
| Fulfilled counting shopping list | ✅ | ❌ | |
| Cost per recipe / serving | ✅ from stock prices | ❌ | |
| Due score (use expiring stock first) | ✅ | ❌ | |
| Put missing on shopping list | ✅ | 🟡 adds all ingredients to a Mealie list | Mealie can't know what's missing |
| Consume all ingredients from stock | ✅ | ❌ | |
| Recipe produces a product on cook | ✅ `product_id` | ❌ | e.g. "Bolognese sauce" goes into stock |
| Per-ingredient stock rules | ✅ | ❌ | `only_check_single_unit`, `not_check_stock_fulfillment`, `variable_amount`, `price_factor` |

## 4. Using recipes

| Feature | Grocy | Mealie | Notes |
|---|---|---|---|
| Cook mode (step-by-step, screen on) | ❌ | ✅ | |
| Ratings / favourites | ❌ | ✅ | |
| "Made it" timeline, photos, last made | ❌ | ✅ | |
| Comments | ❌ | ✅ | |
| Search / filtering | 🟡 name search | ✅ tags, categories, tools, foods, query filters | |
| Public share link | ❌ | ✅ | |
| Print / export | 🟡 | ✅ | |

## 5. Meal planning & shopping

| Feature | Grocy | Mealie | Notes |
|---|---|---|---|
| Meal plan calendar | ✅ with sections | ✅ with meal types | |
| Plan entries: recipe / product / note | ✅ all three | 🟡 recipe or note | |
| Random/rule-based planning | ❌ | ✅ rules by tag/category | |
| Plan → shopping list of *missing* items | ✅ | ❌ | Grocy subtracts stock |
| Shopping lists | ✅ stock-aware | ✅ label-grouped, no stock | |

## 6. Platform

| | Grocy | Mealie |
|---|---|---|
| Stack | PHP (Slim), SQLite, Bootstrap/jQuery UI | Python (FastAPI, SQLAlchemy), Nuxt/Vue PWA |
| Users | Users + permissions, single household | Groups → households → users |
| Web UI | Functional, data-dense | Polished, mobile-friendly, recipe-first |
| API | Full REST, generic objects + userfields | Full REST, OpenAPI documented |
| Webhooks / notifications | ❌ | ✅ (Apprise) |
| Release pace | Slow, single maintainer | Fast, active community |

---

## What the comparison says

**Mealie wins on:** getting recipes in (import), describing them (structured steps, times, tags), and enjoying them (cook mode, ratings, timeline, search, web UI).

**Grocy wins on:** anything that needs to know what's in the house: fulfilment, missing items, cost, due score, consume, producing products. Nobody else does these, and they depend on product-linked ingredients.

**The gap isn't symmetric.** Mealie's advantages are mostly *content + presentation*, which can be rebuilt or worked around (userfields, a better client UI). Grocy's advantages depend on *the inventory engine*, which can't be added to Mealie without effectively rebuilding Grocy.

**Presentation in this iOS app is ours either way.** "Mealie looks better" is about Mealie's *website*. The app's recipe screens can be as good as Mealie's whichever backend holds the data.

---

## Options

### A. Fork Mealie, swap its storage for Grocy ❌ not recommended
Mealie's recipe repository layer would call the Grocy API instead of its own DB. Problems:
- Grocy can't store most of Mealie's model (steps, times, tags, tools, ratings, timeline, comments, cookbooks). You'd need a side database for those, so you'd keep most of Mealie's DB anyway.
- Ingredients must be Grocy products. Mealie's import/parser output (free text, foods) needs a product-matching step before anything can be saved.
- Maintaining a deep fork of a fast-moving Python/Vue codebase means constant merge pain. You'd lose upstream updates, which are the reason to choose Mealie.

### B. Grocy as recipe master, better front-ends 🟡 viable if import matters less
- iOS app: rebuild the recipe screens to be Mealie-quality (cook mode, step view, photos) on Grocy data.
- Add missing fields via Grocy userfields on `recipes` (source URL, prep/cook time, tags).
- Instructions stay one HTML blob. Split it into steps client-side (`<ol>`/`<p>`).
- Import would have to be built by us, e.g. an app-side or server-side schema.org scraper that creates Grocy recipes with product matching. That's a real project.
- You lose Mealie's web UI entirely.

### C. Mealie as recipe master, app-side bridge ✅ current plan
`mealie-integration-plan.md`: read Mealie live, map Mealie foods → Grocy products in the app, compute availability and push missing items to Grocy.
- Keeps Mealie's import, web UI and upstream updates.
- Reimplements a slice of Grocy's engine (fulfilment) in the app. Cost, due score, nested recipes and consume are not covered in the MVP.
- Only the iOS app knows the mapping. Grocy web and Mealie web don't benefit.

### D. Mealie as recipe master, server-side one-way sync into Grocy ✅ worth considering
A small service (could run on the PantryBuddy Pi alongside BarcodeBuddy) mirrors Mealie recipes into Grocy recipes, using a food → product mapping.
- Mealie stays the place you import, edit and browse. The Mealie website is unchanged.
- Grocy gets real recipes, so **all** of Grocy's engine works natively: fulfilment, cost, due score, consume, produce-product, meal plan → missing list, in Grocy web *and* in this app's existing recipe screens.
- The iOS app needs little new work for stock features. It mostly needs the mapping UI, plus deep links to Mealie for the "pretty" view (or a nicer native view).
- Costs: you write and run a sync service; Grocy copies are read-only by convention, since edits in Grocy would be overwritten; unparsed Mealie ingredients can't sync until parsed and mapped.

---

## Decision (2026-10-03)

**Option C chosen**: Mealie holds the recipes; the app checks Grocy stock for a recipe and consumes from Grocy when it's cooked. No recipe copies in Grocy. See `mealie-integration-plan.md`.

## Original recommendation

Don't fork Mealie (Option A). The choice is really between **C** and **D**:
- **C** if you want something working in the app soonest, with no extra server component.
- **D** if you want Grocy's full recipe engine (cost, due score, consume, meal-plan shopping) to work with Mealie recipes, including in the Grocy web UI.

Both need the same food → product mapping, so the mapping UI is the right first build either way. **B** only makes sense if Mealie's import isn't a big part of why you like it.
