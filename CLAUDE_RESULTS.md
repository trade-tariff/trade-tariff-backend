# API Documentation Gap Analysis

**Source**: https://docs.trade-tariff.service.gov.uk/llms-full.txt  
**Compared against**: `app/engines/v2_api.rb` routes + `spec/swagger/api/v2/` specs  
**Date**: 2026-06-12

---

## Summary

The external docs cover 52 endpoints. The V2 API implements approximately **74+ routes**. The gaps fall into three categories:

1. **Undocumented implemented endpoints** — real routes with controllers that are not mentioned in external docs at all
2. **Partially documented endpoints** — documented at collection level but show/sub-routes missing
3. **Undocumented query parameters** — documented endpoints missing accepted filter params

---

## Category 1: Entirely Undocumented Endpoints

These routes exist in `v2_api.rb` and have controllers but are absent from the external docs.

### Search

| Method | Path | Controller | Notes |
|--------|------|-----------|-------|
| GET | `/api/search` | `search#search` | Core search — returns fuzzy/exact/null presenter |
| POST | `/api/search` | `search#search` | Same action, POST variant |
| GET | `/api/search_suggestions` | `search#suggestions` | Autocomplete suggestions |

No swagger spec file exists for `search`. This is arguably the most important missing documentation given it is the primary discovery mechanism for the tariff.

### Sections (sub-routes)

| Method | Path | Notes |
|--------|------|-------|
| GET | `/api/sections/tree` | Full hierarchical tree of all sections/chapters |
| GET | `/api/sections/:id/chapters` | Chapters belonging to a specific section |

### Chapters (sub-routes)

| Method | Path | Notes |
|--------|------|-------|
| GET | `/api/chapters/:id/headings` | Headings for a chapter (routes define `member { get :headings }`) |

### Headings (sub-routes)

| Method | Path | Notes |
|--------|------|-------|
| GET | `/api/headings/:id/tree` | Tree view under a heading |

### Validity Periods

| Method | Path | Notes |
|--------|------|-------|
| GET | `/api/headings/:id/validity_periods` | All validity periods for a heading |
| GET | `/api/subheadings/:id/validity_periods` | All validity periods for a subheading |
| GET | `/api/commodities/:id/validity_periods` | All validity periods for a commodity |

A swagger spec exists (`validity_periods_spec.rb`) but the external docs do not include these routes.

### Exchange Rate Files (UK only)

| Method | Path | Notes |
|--------|------|-------|
| GET | `/api/exchange_rates/files/:id` | Exchange rate file download by ID |

### News (sub-routes)

| Method | Path | Notes |
|--------|------|-------|
| GET | `/api/news/years` | Index of years with published news items |
| GET | `/api/news/collections/:collection_id/items` | Items belonging to a specific collection |

### Green Lanes (entire namespace undocumented)

| Method | Path | Controller | Notes |
|--------|------|-----------|-------|
| GET | `/api/green_lanes/goods_nomenclatures/:id` | `green_lanes/goods_nomenclatures#show` | Green Lanes view of a nomenclature |
| GET | `/api/green_lanes/themes` | `green_lanes/themes#index` | List all Green Lane themes |
| GET | `/api/green_lanes/faq_feedback` | `green_lanes/faq_feedback#index` | List FAQ feedback entries |
| GET | `/api/green_lanes/faq_feedback/:id` | `green_lanes/faq_feedback#show` | Single FAQ feedback entry |
| POST | `/api/green_lanes/faq_feedback` | `green_lanes/faq_feedback#create` | Submit FAQ feedback |

Green Lanes is an entire product area with no external documentation.

### Other

| Method | Path | Controller | Notes |
|--------|------|-----------|-------|
| POST | `/api/notifications` | `notifications#create` | Create a push notification subscription |
| POST | `/api/enquiry_form/submissions` | `enquiry_form/submissions#create` | Submit an enquiry form |

---

## Category 2: Partially Documented Endpoints

These resources are documented at the collection/index level but individual `show` routes are implemented and undocumented.

| Documented | Implemented but missing from docs |
|-----------|----------------------------------|
| `GET /api/chemicals` (index) | `GET /api/chemicals/:id` (show) |
| `GET /api/preference_codes` (index) | `GET /api/preference_codes/:id` (show) |
| `GET /api/news/items` (index) | `GET /api/news/items/:id` (show) — *swagger spec exists* |
| `GET /api/news/collections` (index) | No show route, but collections/:id/items is missing |

---

## Category 3: Undocumented Query Parameters on Documented Endpoints

The swagger specs document these parameters but the external docs do not mention them.

### `GET /api/news/items`
| Parameter | Type | Description |
|-----------|------|-------------|
| `page` | integer | Page number |
| `per_page` | integer | Results per page (1, 10, or 20; default 20) |
| `collection_id` | integer | Filter by collection ID |
| `year` | integer | Filter by publication year |

### `GET /api/live_issues`
Has optional filter parameters per swagger spec — not described in external docs.

### `GET /api/search_references`
Has optional filter parameters per swagger spec — not described in external docs.

### `GET /api/chemical_substances`
Described as "optionally filtered" in external docs summary but no filter parameters are named.

### `GET /api/description_intercepts`
Described as "optionally filtered" in external docs summary but no filter parameters are named.

---

## Category 4: Documentation Accuracy Issues

Minor inaccuracies found in external docs:

| Endpoint | External Docs Says | Actual Behaviour |
|----------|-------------------|-----------------|
| `GET /api/sections/{id}` | Returns 400 for invalid id | Route constraint is integer; Rails returns 404 for non-matching routes |
| `GET /api/rules_of_origin_schemes/{commodity_code}` | Listed as a separate pattern from `/{heading_code}/{country_code}` | These are two distinct routes mapping to different controllers (`product_specific_rules#index` vs `schemes#index`) — docs don't make this distinction clear |
| `GET /api/exchange_rates/period_lists/{year}` | Year is required | Route definition is `period_lists(/:year)` — year is optional |

---

## Coverage Matrix: Swagger Specs vs External Docs

Both swagger specs and external docs cover the same core 52 endpoints. Neither covers:

- Search endpoints
- Green Lanes namespace
- Validity periods
- `sections/tree`, `sections/:id/chapters`, `chapters/:id/headings`, `headings/:id/tree`
- Exchange rate files
- News years / collection items
- Notifications
- Enquiry form

Swagger specs additionally cover (not in external docs):
- `GET /api/news/items/:id` — spec exists at `news_spec.rb`
- Validity period routes — spec exists at `validity_periods_spec.rb`

---

## Recommended Priorities

1. **Search** — highest priority; undocumented core feature used by every consumer
2. **Green Lanes namespace** — entire product area missing from docs
3. **Validity periods** — swagger already covers these; external docs should follow
4. **Section/chapter/heading tree/sub-routes** — useful navigation endpoints
5. **Parameter documentation** — news/items filter params especially

---

## Appendix: Full Implemented Route Inventory

Routes present in `app/engines/v2_api.rb` as of analysis date:

```
GET    /api/sections
GET    /api/sections/tree
GET    /api/sections/:id
GET    /api/sections/:id/chapters
GET    /api/chapters
GET    /api/chapters/:id
GET    /api/chapters/:id/changes
GET    /api/chapters/:id/headings
GET    /api/headings/:id
GET    /api/headings/:id/changes
GET    /api/headings/:id/commodities
GET    /api/headings/:id/tree
GET    /api/headings/:id/validity_periods
GET    /api/subheadings/:id
GET    /api/subheadings/:id/validity_periods
GET    /api/commodities/:id
GET    /api/commodities/:id/changes
GET    /api/commodities/:id/validity_periods
GET    /api/exchange_rates/:id                    (UK only)
GET    /api/exchange_rates/period_lists(/:year)   (UK only)
GET    /api/exchange_rates/files/:id              (UK only)
GET    /api/geographical_areas
GET    /api/geographical_areas/countries
GET    /api/geographical_areas/:id
GET    /api/chemical_substances
GET    /api/simplified_procedural_code_measures
GET    /api/description_intercepts
GET    /api/preference_codes
GET    /api/preference_codes/:id
GET    /api/monetary_exchange_rates
GET    /api/updates/latest
GET    /api/search_references
GET    /api/quotas/search
GET    /api/certificates
GET    /api/certificates/search
GET    /api/certificate_types
GET    /api/measure_actions
GET    /api/measure_condition_codes
GET    /api/quota_order_numbers
GET    /api/measure_types
GET    /api/measure_types/:id
GET    /api/measures/:id
GET    /api/additional_codes/search
GET    /api/additional_code_types
GET    /api/footnotes/search
GET    /api/footnote_types
GET    /api/chemicals
GET    /api/chemicals/search
GET    /api/chemicals/:id
GET    /api/rules_of_origin_schemes
GET    /api/rules_of_origin_schemes/:heading_code/:country_code
GET    /api/rules_of_origin_schemes/:commodity_code
GET    /api/news/items                            (UK or dev)
GET    /api/news/items/:id                        (UK or dev)
GET    /api/news/years                            (UK or dev)
GET    /api/news/collections                      (UK or dev)
GET    /api/news/collections/:collection_id/items (UK or dev)
GET    /api/news_items                            (alias, UK or dev)
GET    /api/news_items/:id                        (alias, UK or dev)
GET    /api/live_issues
GET    /api/changes(/:as_of)
GET    /api/search
POST   /api/search
GET    /api/search_suggestions
GET    /api/goods_nomenclatures/section/:position
GET    /api/goods_nomenclatures/chapter/:chapter_id
GET    /api/goods_nomenclatures/heading/:heading_id
GET    /api/goods_nomenclatures/:id
GET    /api/green_lanes/goods_nomenclatures/:id
GET    /api/green_lanes/themes
GET    /api/green_lanes/faq_feedback
GET    /api/green_lanes/faq_feedback/:id
POST   /api/green_lanes/faq_feedback
POST   /api/notifications
POST   /api/enquiry_form/submissions
```
