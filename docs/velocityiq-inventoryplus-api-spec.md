# VelocityIQ — Inventory+ API Integration Specification

> **Status:** Approved for build · **Version:** 1.0 · **Last updated:** 2026-07-06
> **Owner:** VelocityIQ Platform (Principal API Architect) · **Reviewers:** Inventory+ Platform, DealerSocket CRM Integrations, VelocityIQ AI
> **Audience:** Backend engineers, API architects, EM/PM, QA
> **Scope:** How VelocityIQ consumes existing Solera Inventory+ APIs, where it must build new ones, and how the BFF stitches everything into one response for the React UI.

---

## 0. Executive Summary

VelocityIQ is **not** a greenfield platform. It is an **AI intelligence layer** that sits on top of Solera **Inventory+** and the **DealerSocket CRM**. Wherever Inventory+ already exposes data, VelocityIQ **consumes** it; it only builds new endpoints where a genuine capability gap exists. All AI enrichment and cross-service aggregation is exposed to the React UI through the **VelocityIQ BFF** (Backend-for-Frontend).

### Reuse vs. Build — the headline numbers

| Category | Count | Notes |
|---|---:|---|
| **Existing Inventory+/CRM APIs reused as-is** | 11 | Read-only consumption, no change required |
| **Existing APIs reused but extended** | 2 | `GET /inventory/list`, `PUT /inventory/{vin}/status` |
| **New APIs to build** | 13 | 9 Inventory+, 3 CRM/Notification, 1 VelocityIQ |
| **BFF aggregation endpoints** | 8 | Owned entirely by VelocityIQ |

### The three properties and their dependency profile

| Property | Reuses (existing) | New APIs needed | AI services |
|---|---|---:|---|
| **P1 · AI Recon Tracker** | `/inventory/{vin}`, `/vehicle/history/{vin}`, `/dealer/{id}` | 6 | Recon AI Engine, Delay Predictor |
| **P2 · Customer Match Alerts** | `/crm/customer/{id}`, `/crm/activity/{customerId}`, `/crm/leads` | 3 | CRM Match Service |
| **P3 · GM Daily Briefing** | `/reports/dashboard`, `/api/analytics/v2/iim/vehicle/stats`, `/bookvalues/{vin}` | 4 | Briefing LLM |

### ⚠️ Nuance the catalogue hides

`GET /crm/customerMatches/{vin}` appears in the "existing" Inventory+ catalogue, **but it does not actually exist yet** — DealerSocket exposes customer *records* and *saved searches*, not a VIN→customer match query. It is therefore treated as a **New API (CRM team)** throughout this document, not a reuse. This is the single most common misread in the integration and is called out again in the Risk Register (R-02).

### Build order (10 weeks, 5 sprints)

Property 3 (Briefing) ships first because it reuses the most existing APIs and has no write path; Property 1 write APIs and Property 2 follow; the AI layer lands last on top of stable read contracts. Full sequence in **§7**.

---

## 1. Service & Latency Reference

All simulated/target latencies below are the contract SLOs used for capacity planning and the BFF timeout budget.

| Service | Owner team | Store | p50 latency (SLO) |
|---|---|---|---:|
| Inventory+ Core | Inventory Platform | PostgreSQL `inventory-db` | 45 ms |
| Pricing Service | Pricing | PostgreSQL `inventory-db` | 38 ms |
| Book Values Service | Valuations | PostgreSQL `inventory-db` | 52 ms |
| Images / CDN | Media Platform | S3 `image-store` | 64 ms |
| Analytics Engine (IIM) | Analytics | ElasticSearch + PostgreSQL | 79 ms |
| DealerSocket CRM | CRM Integrations | Redis `crm-cache` → 3rd-party | 118 ms |
| VelocityIQ BFF | VelocityIQ Platform | — (orchestrator) | 36 ms |
| Recon AI Service | VelocityIQ AI | PostgreSQL `velocityiq-db` | 88 ms |
| CRM Intelligence | VelocityIQ AI | PostgreSQL `velocityiq-db` | 96 ms |
| Notification Engine | VelocityIQ Platform | PostgreSQL `velocityiq-db` | 40 ms |

**Standard headers on every call**

```
Authorization: Bearer <dealer-scoped JWT>
x-dealer-id:   DLR-0042
x-api-version: 1.0
```

**Auth model:** OAuth2 client-credentials for service-to-service; every request carries a dealer-scoped JWT so row-level security filters by `dealer_id`. Third-party CRM calls are proxied through the CRM Intelligence service (mTLS) so the browser never holds DealerSocket credentials.

---

## 2. API Consumption Map (Step 2)

`R` = read · `W` = write · **Gap = Yes** rows are specified in full in §3.

| # | Inventory+ / CRM API | Fields VelocityIQ Uses | VelocityIQ Feature | R/W | Gap? |
|---|---|---|---|:--:|:--:|
| 1 | `GET /inventory/{vin}` | `vin, year, make, model, trim, status, dealerId, mileage, purchaseDate` | P1 unit identity, P2 match seed | R | No |
| 2 | `GET /inventory/dashboard` | `totalUnits, inRecon, frontLine, avgAge` | P3 briefing rollup, dashboard KPIs | R | No |
| 3 | `GET /inventory/list` | `vin, status, ageDays` (needs `?status=IN_RECON` filter + pagination) | P1 active-recon set | R | **Extend** |
| 4 | `GET /pricing/{vin}` | `internetPrice, marketAvg, priceRank` | P3 pricing-gap detection | R | No |
| 5 | `GET /bookvalues/{vin}` | `blackBook, jdPower, kbb` | P3 aged-unit reprice guidance | R | No |
| 6 | `GET /api/analytics/v2/iim/vehicle/stats` | `vdpViews, leads, marketDaysSupply, demandIndex` | P2 match ranking, P3 demand signal | R | No |
| 7 | `GET /vehicle/history/{vin}` | `events[], accidents, owners, lastEvent` | P1 prediction features | R | No |
| 8 | `GET /vehicle/images/{vin}` | `count, hero, before, after` | P1 stage auto-detect input | R | No |
| 9 | `GET /reports/dashboard` | `daysSaved, floorplanSaved, matchRate` | P3 briefing, analytics | R | No |
| 10 | `GET /dealer/{id}` | `region, floorplanRate, timezone` | P1 floorplan cost, P3 boundaries | R | No |
| 11 | `GET /users/me` | `id, role, scopes, dealerId` | Auth/role gating on all pages | R | No |
| 12 | `PUT /inventory/{vin}/status` | writes `status` | P1 Ready transition | R/W | **Extend** |
| 13 | `GET /crm/customerMatches/{vin}` | — (endpoint does not exist yet) | P2 match generation | R | **Yes** |
| 14 | `GET /crm/customer/{id}` | `id, name, intentProfile, contact` | P2 match card detail | R | No |
| 15 | `GET /crm/activity/{customerId}` | `events[].type, events[].when` | P2 recency scoring | R | No |
| 16 | `GET /crm/leads` | `total, hot, thirdParty` | P2 pool size, P3 briefing | R | No |

**Gap rows requiring extension (not full new build):**

- **#3 `GET /inventory/list`** — exists but has no efficient `status=IN_RECON` server-side filter, so today the client pulls the whole list and filters in-browser (unacceptable at 120+ units). Extension: add indexed query params `?status=&stage=&page=&pageSize=&sort=`. If not delivered in time, VelocityIQ falls back to the new `GET /inventory/recon/active` (§3.3), which supersedes it for the recon use-case.
- **#12 `PUT /inventory/{vin}/status`** — too coarse. It flips a top-level status but has no concept of *recon stage* (Mechanical→Detail→Photos→Pricing→Ready) or event timestamps. VelocityIQ needs stage-granular writes → new `PUT /inventory/recon/{vin}/stage` (§3.5). The broad status PUT is still used for the final `FRONT_LINE_READY` flip that syndication listens to.

---

## 3. New API Specifications (Step 3)

Thirteen endpoints. Each lists owner, why the existing API can't cover it, request/response schema, backing table, and effort (S ≤ 2 days, M ≤ 1 week, L > 1 week).

### 3.1 `POST /inventory/recon/scan` — Recon check-in event
- **Owner:** Inventory+ Platform · **Effort:** M
- **Why new:** Inventory+ has no recon **event log**. Status is a single mutable field with no history, so "when did this VIN enter Detail and who did the work" is unanswerable today.
- **Reads/Writes:** Writes `recon_events`.

**Request**
```json
{
  "vin": "1HGBH41JXMN109186",
  "stage": "Detail",
  "vendorId": "VND-DETAILPRO",
  "workType": "FULL_RECON",
  "scannedBy": "USR-7741",
  "scannedAt": "2026-07-06T14:12:00Z",
  "notes": "Interior shampoo + paint correction"
}
```

**Response `201 Created`**
```json
{
  "eventId": "RCN-9F3A21",
  "vin": "1HGBH41JXMN109186",
  "stage": "Detail",
  "stageIndex": 2,
  "previousStage": "Mechanical",
  "enteredAt": "2026-07-06T14:12:00Z",
  "syndicationLocked": true,
  "dailyCost": 35.00
}
```
- **Table:** `recon_events` (append-only). Also upserts `recon_stage_current`.

---

### 3.2 `GET /inventory/recon/stages/{vin}` — Full stage history
- **Owner:** Inventory+ Platform · **Effort:** S
- **Why new:** `GET /inventory/{vin}` returns *current* status only. No durations, no per-stage vendor, no timeline.
- **Reads/Writes:** Reads `recon_events`.

**Response `200 OK`**
```json
{
  "vin": "1HGBH41JXMN109186",
  "totalDaysInRecon": 5,
  "currentStageIndex": 2,
  "stages": [
    { "stage": "Mechanical", "startedAt": "2026-07-01T09:00:00Z", "completedAt": "2026-07-03T16:00:00Z", "durationHours": 55, "vendorId": "VND-AUTOMECH", "vendorName": "AutoMech Services" },
    { "stage": "Detail", "startedAt": "2026-07-04T08:00:00Z", "completedAt": null, "durationHours": 48, "vendorId": "VND-DETAILPRO", "vendorName": "DetailPro" }
  ]
}
```

---

### 3.3 `GET /inventory/recon/active` — All in-recon units for a dealer
- **Owner:** Inventory+ Platform · **Effort:** M
- **Why new:** `GET /inventory/list` can't filter by recon status efficiently and returns the full merchandising payload (images, pricing) VelocityIQ doesn't need here.
- **Reads/Writes:** Reads `recon_stage_current` JOIN `vehicle`.

**Query params:** `?stage=&vendorId=&sort=daysInStage|cost&page=1&pageSize=50`

**Response `200 OK`**
```json
{
  "dealerId": "DLR-0042",
  "totalUnitsInRecon": 24,
  "page": 1, "pageSize": 50, "hasNext": false,
  "units": [
    { "vin": "1HGBH41JXMN109186", "year": 2022, "make": "Toyota", "model": "Camry", "trim": "XSE",
      "currentStage": "Detail", "stageIndex": 2, "daysInCurrentStage": 2, "totalDaysInRecon": 5,
      "vendorId": "VND-DETAILPRO", "syndicationLocked": true }
  ]
}
```

---

### 3.4 `GET /inventory/vendor/{vendorId}/performance` — Vendor turnaround
- **Owner:** Inventory+ Platform · **Effort:** M
- **Why new:** No vendor-performance surface exists. This powers both the Vendor Scorecard and the Delay Predictor's `vendorAdjustment` feature.
- **Reads/Writes:** Reads materialized `vendor_performance` (nightly job over `recon_events`).

**Response `200 OK`**
```json
{
  "vendorId": "VND-DETAILPRO",
  "vendorName": "DetailPro",
  "serviceType": "Detail",
  "windowDays": 30,
  "byStage": [
    { "stage": "Detail", "avgHours": 43.2, "targetHours": 48, "onTimeRate": 0.94, "jobs": 61, "reworkRate": 0.04 }
  ],
  "score": 9.1,
  "trend": [2.3, 2.1, 2.0, 1.9, 1.8]
}
```

---

### 3.5 `PUT /inventory/recon/{vin}/stage` — Advance/correct a stage
- **Owner:** Inventory+ Platform · **Effort:** S
- **Why new:** `PUT /inventory/{vin}/status` is too broad and has no stage/timestamp semantics or transition validation.
- **Reads/Writes:** Writes `recon_events` + `recon_stage_current`; on transition to `Ready` also calls `PUT /inventory/{vin}/status` = `FRONT_LINE_READY`.

**Request**
```json
{ "toStage": "Photos", "completedBy": "USR-7741", "completedAt": "2026-07-06T15:40:00Z" }
```

**Response `200 OK`**
```json
{ "vin": "1HGBH41JXMN109186", "fromStage": "Detail", "toStage": "Photos", "stageIndex": 3,
  "syndicationLocked": true, "readyEmitted": false }
```
- **Validation:** rejects non-adjacent forward skips unless `?force=true` (manager scope); blocks transitions on `SOLD`/`WHOLESALE` units.

---

### 3.6 `GET /inventory/recon/floorplan/{dealerId}` — Floorplan rate
- **Owner:** Inventory+ Platform · **Effort:** S
- **Why new:** The rate lives inside `GET /dealer/{id}` config blob; a dedicated, cacheable endpoint avoids pulling the whole dealer record every second for the cost ticker.
- **Reads/Writes:** Reads `dealer`.

**Response `200 OK`**
```json
{ "dealerId": "DLR-0042", "ratePerDay": 35.00, "currency": "USD", "compoundsWeekends": true, "effectiveDate": "2026-01-01" }
```

---

### 3.7 `GET /crm/customerMatches/{vin}` — VIN→customer matches *(the misread)*
- **Owner:** DealerSocket CRM Integrations · **Effort:** L
- **Why new:** CRM stores customers and saved searches but has **no VIN-based match query**. This endpoint runs the match on the CRM side (make/model/trim/year/price band) and returns ranked candidates; VelocityIQ's CRM Match Service then re-scores with recency + demand.
- **Reads/Writes:** Reads `crm.customers`, `crm.saved_searches`, `crm.activities`.

**Query params:** `?priceBand=2000&limit=10`

**Response `200 OK`**
```json
{
  "vin": "2T1BURHE0JC034985",
  "matchCount": 3,
  "matches": [
    { "customerId": "CUS-10233", "name": "Sarah Mitchell", "rawScore": 0.91,
      "source": "CRM", "savedSearch": "Toyota Camry XSE < $32k", "lastActivityAt": "2026-07-06T12:02:00Z" },
    { "customerId": "CUS-10944", "name": "James Rodriguez", "rawScore": 0.78,
      "source": "AutoTrader", "savedSearch": "Camry 2021+", "lastActivityAt": "2026-07-05T19:20:00Z" }
  ]
}
```

---

### 3.8 `POST /crm/leads/{id}/notify` — Notify salesperson of a match
- **Owner:** DealerSocket CRM Integrations (delivery) + VelocityIQ Notification Engine (trigger) · **Effort:** M
- **Why new:** Current CRM API has no outbound notification trigger.
- **Reads/Writes:** Writes `notifications`; dispatches push/SMS/email.

**Request**
```json
{ "vin": "2T1BURHE0JC034985", "salespersonId": "USR-3310", "channel": ["push", "sms"],
  "message": "Hot match: Sarah Mitchell (91%) for the Camry XSE that just went front-line ready." }
```

**Response `202 Accepted`**
```json
{ "notificationId": "NTF-55A7", "status": "QUEUED", "channels": { "push": "QUEUED", "sms": "QUEUED" } }
```

---

### 3.9 `GET /inventory/recon/ready` — Units that *just* became Front-Line Ready
- **Owner:** Inventory+ Platform · **Effort:** M
- **Why new:** There is no status-change / event query. P2 must fire matches *at the moment* a unit goes Ready, not on a poll of everything.
- **Reads/Writes:** Reads `recon_events` where `toStage='Ready'` and `emitted=false`; marks `emitted=true`.

**Query params:** `?since=2026-07-06T00:00:00Z`

**Response `200 OK`**
```json
{ "dealerId": "DLR-0042", "readyUnits": [
  { "vin": "2T1BURHE0JC034985", "year": 2021, "make": "Toyota", "model": "Camry", "trim": "SE",
    "becameReadyAt": "2026-07-06T13:05:00Z", "internetPrice": 24995 }
] }
```

---

### 3.10 `GET /inventory/recon/summary/{dealerId}` — Yesterday's recon rollup
- **Owner:** Inventory+ Platform · **Effort:** M
- **Why new:** `GET /reports/dashboard` is too broad and not recon-specific (no completions/delays/vendor issues for a single day).
- **Reads/Writes:** Reads `recon_events` aggregated for the prior dealer-local day.

**Response `200 OK`**
```json
{ "dealerId": "DLR-0042", "date": "2026-07-05",
  "completions": 3, "newIntake": 4, "stillDelayed": 2, "avgCycleDays": 14.2,
  "vendorIssues": [ { "vendorId": "VND-QUICKLUBE", "issue": "Mechanical 5.9d vs 3.5d target", "onTimeRate": 0.58 } ],
  "bottleneckStage": "Mechanical" }
```

---

### 3.11 `GET /inventory/aged/{dealerId}` — Units crossing age thresholds today
- **Owner:** Inventory+ Platform · **Effort:** S
- **Why new:** `GET /inventory/list` forces client-side age filtering; this returns only units crossing 30/45/60-day lines **today**, in the dealer's timezone.
- **Reads/Writes:** Reads `vehicle` + `dealer.timezone`.

**Response `200 OK`**
```json
{ "dealerId": "DLR-0042", "crossingToday": [
  { "vin": "3GNAXUEV0LL209871", "make": "Chevrolet", "model": "Equinox", "ageDays": 45, "threshold": 45, "internetPrice": 21990 }
], "counts": { "d30": 2, "d45": 1, "d60": 0 } }
```

---

### 3.12 `GET /pricing/gaps/{dealerId}` — Units priced above market
- **Owner:** Pricing · **Effort:** M
- **Why new:** No pricing-gap query exists; today you'd call `/pricing/{vin}` per unit and diff client-side.
- **Reads/Writes:** Reads `pricing` JOIN market feed.

**Query params:** `?thresholdPct=5`

**Response `200 OK`**
```json
{ "dealerId": "DLR-0042", "thresholdPct": 5, "gaps": [
  { "vin": "3GNAXUEV0LL209871", "internetPrice": 21990, "marketAvg": 20650, "gapPct": 6.5, "priceRank": "11 of 14" }
] }
```

---

### 3.13 `GET /velocityiq/briefing/generate` — LLM briefing trigger
- **Owner:** VelocityIQ (AI) · **Effort:** L
- **Why new:** Entirely new VelocityIQ service. Aggregates §3.10–§3.12 + CRM match counts and produces a 5-bullet plain-English brief. **Inventory data only — no customer PII enters the LLM prompt.**
- **Reads/Writes:** Writes `analytics` (brief cache); reads recon summary/aged/pricing gaps.

**Response `200 OK`**
```json
{ "dealerId": "DLR-0042", "date": "2026-07-06", "modelVersion": "brief-llm-v2",
  "bullets": [
    "7 units in inventory; 4 in recon and 2 are exceeding stage-average time and need attention today.",
    "Floorplan carrying cost is $840/day — clearing Detail saves roughly $96/day.",
    "3 front-line-ready units carry fresh CRM matches; 2 are 90%+ scores worth a same-day call.",
    "Mechanical is the current bottleneck — the Tesla Model 3 has sat 6 days versus a 4-day target.",
    "2020 Chevy Equinox is crossing 45 days in stock — plan a reprice on completion."
  ],
  "sources": { "reconSummary": true, "aged": true, "pricingGaps": true, "crmMatches": true },
  "piiIncluded": false }
```

---

## 4. BFF Endpoint Specifications (Step 4)

The BFF owns fan-out, merge, timeout budget, and DTO shaping. **Global rules:**
- **Parallel fan-out** with a **250 ms wall-clock budget**; per-source timeouts below.
- **Graceful degradation:** AI down → return Inventory+ facts with `aiConfidence: null` and `degraded: ["ai"]`. CRM slow → return partial with `crmPending: true`; never block the whole page on the 118 ms CRM hop.
- **Cache:** React Query on the client (TTL per endpoint) + short server-side edge cache keyed by `dealerId`.
- Every response carries a `meta` block with per-source latency, `cacheHit`, and `degraded[]`.

---

### 4.1 `GET /velocityiq/dashboard`
**Call tree**
```
GET /velocityiq/dashboard
 ├── GET /inventory/dashboard              (45ms)
 ├── GET /inventory/recon/active           (48ms)
 ├── GET /crm/leads                        (118ms, timeout 150ms → optional)
 ├── GET /velocityiq/briefing (cached)     (5ms)
 └── AI: Risk Scorer over active units      (88ms)
 Total ≈ 96ms (parallel; CRM off critical path)
```
**Merge:** KPIs from `inventory/dashboard`; recon count/cost from `recon/active`; hottest matches from `crm/leads` (optional); brief from cache; each unit gets `riskScore` from AI. If AI times out → `riskScore: null`, `degraded:["ai"]`. If CRM times out → `readyMatches` shows last-known + `crmPending:true`.

**DTO**
```ts
interface DashboardDTO {
  dealerId: string;
  kpis: { unitsInRecon: number; readyMatches: number; floorplanPerDay: number; daysSaved: number; };
  aging: { bucket: "0-15"|"16-30"|"31-45"|"45+"; count: number; dollarsAtRisk: number; }[];
  briefing: string[];                 // 5 bullets, possibly stale (see meta.cacheHit)
  activity: { at: string; type: string; text: string; severity: "info"|"warn"|"danger"|"success"; }[];
  meta: BffMeta;
}
interface BffMeta { generatedAt: string; latency: Record<string, number>; totalLatency: number;
  cacheHit: boolean; cacheTTL: number; degraded: string[]; crmPending?: boolean; }
```

---

### 4.2 `GET /velocityiq/recon`
**Call tree**
```
GET /velocityiq/recon
 ├── GET /inventory/recon/active           (48ms)
 ├── GET /inventory/recon/stages/{vin} ×N  (38ms, batched)
 ├── GET /inventory/vendor/performance     (52ms)
 ├── GET /inventory/recon/floorplan/{d}    (12ms, cached 60s)
 └── AI: Delay Predictor + Recon Engine    (88ms)
 Total ≈ 92ms (parallel)
```
**Merge:** base list from `recon/active`; splice `stageHistory` per VIN; `dailyCost = floorplan.ratePerDay`; `predictedReadyDate/aiConfidence/delayRisk` from AI; `delayAlerts[]` where `hoursOverAvg` exceeds vendor SLA. AI down → predictions null, cost + history still render (the page stays useful).

**DTO** — see the full worked example in §5.2. Key interface:
```ts
interface ReconUnitDTO {
  vin: string; year: number; make: string; model: string; trim: string;
  currentStage: string; stageIndex: number; daysInCurrentStage: number; totalDaysInRecon: number;
  dailyCost: number; accruedCost: number; vendor: string;
  predictedReadyDate: string | null; predictedDaysRemaining: number | null;
  aiConfidence: number | null; delayRisk: "LOW"|"MEDIUM"|"HIGH"|null; syndicationLocked: boolean;
  stageHistory: { stage: string; startedAt: string; completedAt: string|null; durationHours: number; vendor: string; }[];
  aiPrediction: { workTypeBase: number; vendorAdjustment: number; queueBuffer: number; dayOffset: number;
    totalDays: number; modelVersion: string; lastRetrained: string; } | null;
}
```

---

### 4.3 `GET /velocityiq/recon/{vin}`
**Call tree**
```
GET /velocityiq/recon/{vin}
 ├── GET /inventory/{vin}                  (45ms)
 ├── GET /inventory/recon/stages/{vin}     (38ms)
 ├── GET /vehicle/history/{vin}            (45ms)
 └── AI: full prediction breakdown          (88ms)
 Total ≈ 90ms
```
**Merge:** identity from `/inventory/{vin}`; timeline from stages; prior-owner/accident features from history feed the AI breakdown. Single-VIN, so if any *required* source (identity/stages) fails → `502` with `partial:false`; AI failure degrades to facts-only.

---

### 4.4 `GET /velocityiq/crm`
**Call tree**
```
GET /velocityiq/crm
 ├── GET /inventory/recon/ready            (48ms)
 ├── GET /crm/customerMatches/{vin} ×R     (118ms, timeout 150ms)
 ├── GET /crm/activity/{customerId} ×M     (118ms, batched)
 └── AI: CRM Match Service re-score         (96ms)
 Total ≈ 170ms (CRM dominates; see degradation)
```
**Merge:** for each newly-Ready VIN, pull candidate matches, enrich with activity recency, re-score in CRM Match Service (blends `rawScore`, recency decay, `demandIndex`). CRM slow → return the Ready units with `matches:[]` and `crmPending:true`; UI shows a "matching…" state and re-fetches. **Every customer row is labelled `source` (CRM/AutoTrader/Cars.com) and flagged internal-use-only.**

**DTO**
```ts
interface CrmMatchDTO {
  readyUnits: {
    vin: string; label: string; internetPrice: number;
    matches: { customerId: string; name: string; score: number; source: "CRM"|"AutoTrader"|"Cars.com";
      lastActivity: string; savedSearch: string; }[];
  }[];
  internalUseOnly: true;
  meta: BffMeta;
}
```

---

### 4.5 `GET /velocityiq/briefing`
**Call tree**
```
GET /velocityiq/briefing
 ├── GET /inventory/recon/summary/{d}      (52ms)
 ├── GET /inventory/aged/{d}               (40ms)
 ├── GET /pricing/gaps/{d}                 (44ms)
 ├── GET /crm/leads (counts only)          (118ms, optional)
 └── AI: Briefing LLM                       (LLM 900ms cold / 120ms cached)
 Total ≈ 120ms cached · up to ~1s on regenerate
```
**Merge:** aggregate the three recon/aged/pricing sources + CRM match *counts only* (no PII) into the LLM context; cache the 5 bullets for the dealer-day. Regenerate is explicit (button) and bypasses cache. LLM down → return last cached brief with `stale:true`; never blank.

---

### 4.6 `GET /velocityiq/analytics`
**Call tree**
```
GET /velocityiq/analytics
 ├── GET /reports/dashboard                (79ms)
 ├── GET /inventory/vendor/performance ×V  (52ms, batched)
 ├── GET /api/analytics/v2/iim/vehicle/stats (79ms)
 └── AI: Analytics Engine (scores + ROI)    (88ms)
 Total ≈ 96ms
```
**Merge:** conversion + floorplan-saved from reports; vendor scorecards from performance; demand from IIM; ROI + vendor /10 scores from AI. Fully cacheable (5 min).

---

### 4.7 `POST /velocityiq/recon/scan`
**Call tree**
```
POST /velocityiq/recon/scan
 ├── POST /inventory/recon/scan            (write, 60ms)
 └── AI: Delay Predictor + Recon Engine    (88ms)
 Total ≈ 95ms
```
**Behaviour:** write-through the scan, then synchronously return the fresh prediction so the UI can start the cost counter and show the predicted date immediately. **Idempotent** on `(vin, stage, scannedAt)` to survive double-taps/retries. AI down → `201` with `prediction:null` and `retryPredictionAfter` set; the ticker still starts.

**Response**
```json
{ "eventId": "RCN-9F3A21", "vin": "1HGBH41JXMN109186", "stage": "Detail",
  "predictedReadyDate": "2026-07-11", "predictedDaysRemaining": 5, "aiConfidence": 0.87,
  "dailyCost": 35.00, "costCounterStartedAt": "2026-07-06T14:12:00Z" }
```

---

### 4.8 `POST /velocityiq/crm/notify`
**Call tree**
```
POST /velocityiq/crm/notify
 ├── POST /crm/leads/{id}/notify           (write, 60ms)
 └── WebSocket push to salesperson UI       (Notification Engine, 40ms)
 Total ≈ 70ms
```
**Behaviour:** dispatch to CRM delivery + emit a WS event to the assigned salesperson's session. Returns per-channel delivery status. Retries on transient CRM 5xx with exponential backoff (idempotency key = `notificationId`).

**Response**
```json
{ "notificationId": "NTF-55A7", "status": "SENT",
  "channels": { "push": "DELIVERED", "sms": "QUEUED" }, "wsDelivered": true }
```

---

## 5. Full Worked Examples (Step 5)

### 5.1 `GET /velocityiq/dashboard`
**Request**
```
GET /velocityiq/dashboard
Host: api.velocityiq.solera.com
Authorization: Bearer eyJhbGciOiJIUzI1Ni...
x-dealer-id: DLR-0042
x-api-version: 1.0
```
**Response `200 OK`**
```json
{
  "dealerId": "DLR-0042",
  "kpis": { "unitsInRecon": 24, "readyMatches": 3, "floorplanPerDay": 840.00, "daysSaved": 38 },
  "aging": [
    { "bucket": "0-15",  "count": 3, "dollarsAtRisk": 834 },
    { "bucket": "16-30", "count": 2, "dollarsAtRisk": 1376 },
    { "bucket": "31-45", "count": 2, "dollarsAtRisk": 2039 },
    { "bucket": "45+",   "count": 0, "dollarsAtRisk": 0 }
  ],
  "briefing": [
    "4 units in recon are exceeding their stage average and need a nudge today.",
    "Floorplan is carrying $840/day; clearing the Detail bottleneck saves ~$96/day.",
    "3 front-line-ready units have fresh CRM customer matches worth a same-day call.",
    "Mechanical bay is today's bottleneck — the Tesla Model 3 has sat 6 days.",
    "2 units flagged DELAY are dragging your average cycle up by 1.3 days."
  ],
  "activity": [
    { "at": "2026-07-06T07:40:00Z", "type": "DELAY", "text": "DELAY flagged — 2020 Tesla Model 3 stuck in Mechanical (6d)", "severity": "danger" },
    { "at": "2026-07-06T07:22:00Z", "type": "READY", "text": "2022 BMW 328i xDrive reached Ready — 3 CRM matches fired", "severity": "success" }
  ],
  "meta": { "generatedAt": "2026-07-06T07:42:00Z",
    "latency": { "inventory": 45, "recon": 48, "crm": 121, "ai": 88 },
    "totalLatency": 96, "cacheHit": false, "cacheTTL": 30, "degraded": [], "crmPending": false }
}
```

### 5.2 `GET /velocityiq/recon`
**Request**
```
GET /velocityiq/recon
Host: api.velocityiq.solera.com
Authorization: Bearer eyJhbGc...
x-dealer-id: DLR-0042
x-api-version: 1.0
```
**Response `200 OK`**
```json
{
  "dealerId": "DLR-0042",
  "totalUnitsInRecon": 24,
  "totalDailyCost": 840.00,
  "units": [
    {
      "vin": "1HGBH41JXMN109186", "year": 2022, "make": "Toyota", "model": "Camry", "trim": "XSE",
      "currentStage": "Detail", "stageIndex": 2, "daysInCurrentStage": 2, "totalDaysInRecon": 5,
      "dailyCost": 35.00, "accruedCost": 175.00, "vendor": "DetailPro",
      "predictedReadyDate": "2026-07-11", "predictedDaysRemaining": 2, "aiConfidence": 0.87,
      "delayRisk": "LOW", "syndicationLocked": true,
      "stageHistory": [
        { "stage": "Mechanical", "startedAt": "2026-07-01T09:00:00Z", "completedAt": "2026-07-03T16:00:00Z", "durationHours": 55, "vendor": "AutoMech Services" },
        { "stage": "Detail", "startedAt": "2026-07-04T08:00:00Z", "completedAt": null, "durationHours": 48, "vendor": "DetailPro" }
      ],
      "aiPrediction": { "workTypeBase": 6.0, "vendorAdjustment": -0.5, "queueBuffer": 0.3, "dayOffset": 0.0,
        "totalDays": 5.8, "modelVersion": "recon-rf-v2.3", "lastRetrained": "2026-04-01" }
    }
  ],
  "delayAlerts": [
    { "vin": "5YJ3E1EA7KF317654", "stage": "Mechanical", "hoursOverAvg": 18.5, "riskLevel": "HIGH",
      "recommendedAction": "Contact AutoMech Services — transmission jobs averaging 3.2× normal duration this week" }
  ],
  "meta": { "generatedAt": "2026-07-06T07:42:00Z", "latency": { "inventory": 45, "ai": 36 },
    "totalLatency": 92, "cacheHit": false, "cacheTTL": 30, "degraded": [] }
}
```

### 5.3 `GET /velocityiq/recon/1HGBH41JXMN109186`
**Response `200 OK`**
```json
{
  "vin": "1HGBH41JXMN109186", "year": 2022, "make": "Toyota", "model": "Camry", "trim": "XSE",
  "status": "IN_RECON", "mileage": 41230, "purchaseDate": "2026-06-30",
  "history": { "owners": 1, "accidents": 0, "lastEvent": "PRICED" },
  "stages": [
    { "stage": "Mechanical", "startedAt": "2026-07-01T09:00:00Z", "completedAt": "2026-07-03T16:00:00Z", "durationHours": 55, "vendor": "AutoMech Services" },
    { "stage": "Detail", "startedAt": "2026-07-04T08:00:00Z", "completedAt": null, "durationHours": 48, "vendor": "DetailPro" }
  ],
  "aiPrediction": {
    "predictedReadyDate": "2026-07-11", "aiConfidence": 0.87, "delayRisk": "LOW",
    "breakdown": { "workTypeBase": 6.0, "vendorAdjustment": -0.5, "queueBuffer": 0.3, "dayOffset": 0.0, "totalDays": 5.8 },
    "weights": { "workType": 0.70, "vendorHistory": 0.15, "queueLoad": 0.08, "dayPattern": 0.07 },
    "modelVersion": "recon-rf-v2.3", "lastRetrained": "2026-04-01",
    "confidenceReason": "40+ completed DetailPro jobs feed the model; FULL_RECON is well-represented in training data."
  },
  "meta": { "generatedAt": "2026-07-06T07:42:10Z", "latency": { "inventory": 45, "history": 45, "ai": 88 }, "totalLatency": 90, "cacheHit": false, "degraded": [] }
}
```

### 5.4 `GET /velocityiq/crm`
**Response `200 OK`**
```json
{
  "readyUnits": [
    { "vin": "2T1BURHE0JC034985", "label": "2021 Toyota Camry SE", "internetPrice": 24995,
      "matches": [
        { "customerId": "CUS-10233", "name": "Sarah Mitchell", "score": 96, "source": "CRM", "lastActivity": "2h", "savedSearch": "Toyota Camry SE < $26k" },
        { "customerId": "CUS-10944", "name": "James Rodriguez", "score": 88, "source": "AutoTrader", "lastActivity": "1d", "savedSearch": "Camry 2020+" }
      ] }
  ],
  "internalUseOnly": true,
  "meta": { "generatedAt": "2026-07-06T07:43:00Z", "latency": { "recon": 48, "crm": 121, "ai": 96 },
    "totalLatency": 170, "cacheHit": false, "degraded": [], "crmPending": false }
}
```

### 5.5 `GET /velocityiq/briefing`
**Response `200 OK`** — see §3.13 payload; `meta.cacheHit:true, cacheTTL:86400, stale:false`.

### 5.6 `GET /velocityiq/analytics`
**Response `200 OK`**
```json
{
  "conversion7d": [ {"d":"Mon","matches":12},{"d":"Tue","matches":18},{"d":"Wed","matches":9},{"d":"Thu","matches":22},{"d":"Fri","matches":15},{"d":"Sat","matches":24},{"d":"Sun","matches":11} ],
  "vendors": [
    { "vendorId":"VND-DETAILPRO","name":"Precision Auto Detail","serviceType":"Detail","score":9.1,"avgDays":1.8,"targetDays":2.0,"onTimeRate":0.94 },
    { "vendorId":"VND-QUICKLUBE","name":"QuickLube Recon","serviceType":"Mechanical","score":5.2,"avgDays":5.9,"targetDays":3.5,"onTimeRate":0.58 }
  ],
  "roi": { "monthlySavings": 12250, "annualROI": 41, "netAnnual": 143412 },
  "meta": { "generatedAt": "2026-07-06T07:44:00Z", "latency": { "reports": 79, "vendor": 52, "iim": 79, "ai": 88 }, "totalLatency": 96, "cacheHit": true, "cacheTTL": 300, "degraded": [] }
}
```

### 5.7 `POST /velocityiq/recon/scan`
**Request**
```
POST /velocityiq/recon/scan
Host: api.velocityiq.solera.com
Authorization: Bearer eyJhbGc...
x-dealer-id: DLR-0042
Content-Type: application/json

{ "vin": "1HGBH41JXMN109186", "stage": "Detail", "vendorId": "VND-DETAILPRO", "workType": "FULL_RECON", "scannedBy": "USR-7741" }
```
**Response `201 Created`** — payload in §4.7.

### 5.8 `POST /velocityiq/crm/notify`
**Request**
```
POST /velocityiq/crm/notify
Host: api.velocityiq.solera.com
Authorization: Bearer eyJhbGc...
x-dealer-id: DLR-0042
Content-Type: application/json

{ "leadId": "CUS-10233", "vin": "2T1BURHE0JC034985", "salespersonId": "USR-3310", "channel": ["push","sms"] }
```
**Response `202 Accepted`** — payload in §4.8.

---

## 6. Implementation Steps per New API (Step 6)

Below, the two representative endpoints are shown end-to-end; the remaining 11 follow the same six-step shape (summarised in the table at the end of this section).

### 6.1 `POST /inventory/recon/scan`

**Step 1 — Database** (new append-only log + current-state projection)
```sql
CREATE TABLE recon_events (
  event_id        VARCHAR(16) PRIMARY KEY,          -- RCN-9F3A21
  vin             VARCHAR(17) NOT NULL,
  dealer_id       VARCHAR(12) NOT NULL,
  stage           VARCHAR(16) NOT NULL,             -- Mechanical|Detail|Photos|Pricing|Ready
  stage_index     SMALLINT    NOT NULL,
  vendor_id       VARCHAR(16),
  work_type       VARCHAR(24) NOT NULL,             -- FULL_RECON|MECHANICAL|DETAIL|PHOTO
  scanned_by      VARCHAR(16) NOT NULL,
  entered_at      TIMESTAMPTZ NOT NULL,
  emitted         BOOLEAN     NOT NULL DEFAULT FALSE,-- for /recon/ready consumers
  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_recon_events_vin       ON recon_events (vin, entered_at DESC);
CREATE INDEX idx_recon_events_dealer     ON recon_events (dealer_id, entered_at DESC);
CREATE INDEX idx_recon_events_ready      ON recon_events (dealer_id) WHERE stage = 'Ready' AND emitted = FALSE;

CREATE TABLE recon_stage_current (
  vin          VARCHAR(17) PRIMARY KEY,
  dealer_id    VARCHAR(12) NOT NULL,
  stage        VARCHAR(16) NOT NULL,
  stage_index  SMALLINT    NOT NULL,
  vendor_id    VARCHAR(16),
  entered_at   TIMESTAMPTZ NOT NULL,
  syndication_locked BOOLEAN NOT NULL DEFAULT TRUE
);
```

**Step 2 — Service layer**
```java
public interface ReconService {
  ReconEvent logScan(ScanRequest req);          // idempotent on (vin, stage, enteredAt)
  StageHistory stageHistory(String vin);
  Page<ReconUnit> activeForDealer(String dealerId, ReconQuery q);
}
```

**Step 3 — Controller**
```java
@PostMapping("/inventory/recon/scan")
@PreAuthorize("hasScope('write:recon')")
public ResponseEntity<ReconEvent> scan(@Valid @RequestBody ScanRequest req,
                                       @RequestHeader("x-dealer-id") String dealerId) {
  return ResponseEntity.status(201).body(reconService.logScan(req.withDealer(dealerId)));
}
```

**Step 4 — Validation**
```
vin        : required, 17 chars, VIN checksum valid
stage      : required, ∈ {Mechanical,Detail,Photos,Pricing,Ready}
vendorId   : required unless stage == Pricing
workType   : required, enum
scannedBy  : required, must resolve to an active user in this dealer
enteredAt  : optional, defaults to now(); reject > 5 min in the future
idempotency: (vin, stage, enteredAt) unique → 200 replay instead of duplicate 201
```

**Step 5 — Tests**
- Unit: happy path 201; duplicate scan → idempotent replay; invalid VIN checksum → 422; vendor missing for Detail → 422; future timestamp → 422; cross-dealer VIN → 403.
- Integration: scan → `recon_stage_current` upserted; scan to Ready → emits ready event + calls status PUT; concurrent double-tap → single row.

**Step 6 — Deployment**
- **Extension** to the existing Inventory+ service (not a new microservice).
- Env: `RECON_EVENTS_DB_URL`, `SYNDICATION_LOCK_DEFAULT=true`.
- Feature flag: `velocityiq.recon.ai.enabled` (rollout %), plus `inventory.recon.events.enabled` kill-switch.

---

### 6.2 `GET /crm/customerMatches/{vin}`

**Step 1 — Database** (CRM side — read model over saved searches)
```sql
-- Materialized view refreshed on saved-search / activity change (CRM cache)
CREATE MATERIALIZED VIEW crm_match_index AS
SELECT s.customer_id, s.make, s.model, s.trim, s.year_min, s.year_max,
       s.price_max, s.source, a.last_activity_at
FROM   crm.saved_searches s
JOIN   crm.activities a ON a.customer_id = s.customer_id;
CREATE INDEX idx_crm_match_mmt ON crm_match_index (make, model, trim, year_min, year_max, price_max);
```

**Step 2 — Service layer**
```typescript
interface CrmMatchService {
  matchByVin(vin: string, priceBand: number, limit: number): Promise<RawMatch[]>;
}
```

**Step 3 — Controller**
```typescript
router.get("/crm/customerMatches/:vin",
  requireScope("read:crm"),
  async (req, res) => res.json(await crmMatchService.matchByVin(
    req.params.vin, Number(req.query.priceBand ?? 2000), Number(req.query.limit ?? 10))));
```

**Step 4 — Validation**
```
vin       : required, 17 chars, resolvable to a vehicle (make/model/trim/year/price)
priceBand : optional int ≥ 0, default 2000
limit     : optional int 1..25, default 10
scope     : caller must hold read:crm; response tagged internalUseOnly=true
```

**Step 5 — Tests**
- Unit: exact make/model/trim hit; price-band boundary inclusion/exclusion; year range edges; no-match → empty array; PII scope enforced.
- Integration: match index refresh reflects a new saved search within SLA; re-score parity with CRM Match Service.

**Step 6 — Deployment**
- **New capability on the CRM Integrations service** (DealerSocket side), fronted by CRM Intelligence (mTLS).
- Env: `CRM_MATCH_INDEX_REFRESH_SEC=300`, `CRM_MATCH_MAX_LIMIT=25`.
- Feature flag: `velocityiq.crm.bridge.enabled`.

---

### 6.3 Remaining new APIs — six-step summary

| API | DB change | Service method | Controller | Key validation | Deploy | Effort |
|---|---|---|---|---|---|---|
| `GET /inventory/recon/stages/{vin}` | reads `recon_events` | `stageHistory(vin)` | `GET .../stages/{vin}` | vin valid | Inv+ ext | S |
| `GET /inventory/recon/active` | reads `recon_stage_current` | `activeForDealer(d,q)` | `GET .../active` | page/pageSize bounds | Inv+ ext | M |
| `GET /inventory/vendor/{id}/performance` | new `vendor_performance` MV (nightly) | `vendorPerf(id,window)` | `GET .../vendor/{id}/performance` | window ∈ {7,30,90} | Inv+ ext | M |
| `PUT /inventory/recon/{vin}/stage` | writes `recon_events` | `advanceStage(vin,to)` | `PUT .../{vin}/stage` | adjacency, terminal-state block | Inv+ ext | S |
| `GET /inventory/recon/floorplan/{d}` | reads `dealer` | `floorplan(d)` | `GET .../floorplan/{d}` | dealer scope | Inv+ ext | S |
| `POST /crm/leads/{id}/notify` | writes `notifications` | `notify(id,channels)` | `POST /crm/leads/{id}/notify` | channel enum, rate-limit | CRM+Notif | M |
| `GET /inventory/recon/ready` | reads/updates `recon_events.emitted` | `readySince(d,ts)` | `GET .../ready` | since ≤ now | Inv+ ext | M |
| `GET /inventory/recon/summary/{d}` | aggregates `recon_events` | `dailySummary(d,date)` | `GET .../summary/{d}` | dealer-local date | Inv+ ext | M |
| `GET /inventory/aged/{d}` | reads `vehicle`+tz | `agedCrossing(d)` | `GET .../aged/{d}` | tz resolve | Inv+ ext | S |
| `GET /pricing/gaps/{d}` | reads `pricing`+market | `pricingGaps(d,pct)` | `GET /pricing/gaps/{d}` | thresholdPct 0..50 | Pricing ext | M |
| `GET /velocityiq/briefing/generate` | writes `analytics` brief cache | `generateBrief(d)` | `GET .../briefing/generate` | no-PII guard | VIQ new svc | L |

---

## 7. Prioritised Build Sequence (Step 7)

```
Sprint 1 · Weeks 1–2 — Property 3 (GM Briefing) — reuses the most, no writes
  → GET /inventory/recon/summary/{dealerId}      (Inv+, M)
  → GET /inventory/aged/{dealerId}               (Inv+, S)
  → GET /pricing/gaps/{dealerId}                 (Pricing, M)
  → GET /velocityiq/briefing/generate            (VIQ, L)  + BFF GET /velocityiq/briefing

Sprint 2 · Weeks 3–4 — Property 1 read foundation
  → GET /inventory/recon/active                  (Inv+, M)
  → GET /inventory/recon/stages/{vin}            (Inv+, S)
  → GET /inventory/recon/floorplan/{dealerId}    (Inv+, S)
  → BFF GET /velocityiq/recon + /velocityiq/recon/{vin}

Sprint 3 · Weeks 5–6 — Property 1 write path (stage tracking)
  → POST /inventory/recon/scan                   (Inv+, M)
  → PUT  /inventory/recon/{vin}/stage            (Inv+, S)
  → GET  /inventory/vendor/{vendorId}/performance(Inv+, M)
  → BFF POST /velocityiq/recon/scan

Sprint 4 · Weeks 7–8 — Property 2 (Customer Match)
  → GET  /inventory/recon/ready                  (Inv+, M)
  → GET  /crm/customerMatches/{vin}              (CRM, L)  ← the misread; longest lead time
  → POST /crm/leads/{id}/notify                  (CRM+Notif, M)
  → BFF GET /velocityiq/crm + POST /velocityiq/crm/notify

Sprint 5 · Weeks 9–10 — AI layer + final aggregation
  → Recon AI Engine + Delay Predictor integration
  → CRM Match Service re-scoring
  → Briefing LLM productionisation (cache + cost guard)
  → BFF GET /velocityiq/dashboard (full fan-out) + /velocityiq/analytics
```

**Critical path:** `GET /crm/customerMatches/{vin}` (Sprint 4, effort L, external team) is the longest pole — kick off its design in Sprint 1 in parallel so CRM Integrations has 6 weeks of lead time.

---

## 8. Risk Register

| ID | Risk | Likelihood | Impact | Why | Mitigation |
|---|---|:--:|:--:|---|---|
| **R-01** | CRM latency blows the page budget | High | High | DealerSocket hop is 118 ms p50 and third-party; tail can hit 400 ms+ | Keep CRM off the critical path (`crmPending` partial), 150 ms timeout, cache last-known matches, async re-fetch |
| **R-02** | `/crm/customerMatches/{vin}` misread as existing | High | High | It's in the catalogue but **doesn't exist**; teams may assume reuse and under-plan | Explicit "New API (CRM, L)" everywhere; start design Sprint 1; Risk owner: CRM EM |
| **R-03** | Recon event ordering / double-scan | Med | High | Scanners retry; out-of-order events corrupt stage history | Idempotency key `(vin,stage,enteredAt)`; append-only log; server-derived `stageIndex` |
| **R-04** | Floorplan rate source-of-truth drift | Med | Med | Rate lives in dealer config *and* the new endpoint | Single source: endpoint reads `dealer`; cache 60 s; nightly reconciliation check |
| **R-05** | AI cold-start / low-confidence predictions | Med | Med | New dealers lack history; RF model returns low confidence | Degrade to work-type base estimate + `aiConfidence:null`; show "learning this dealer" copy |
| **R-06** | Briefing LLM cost & latency | Med | Med | 900 ms cold, per-generation token cost | Cache per dealer-day; explicit regenerate only; no-PII prompt keeps context small |
| **R-07** | Aged-unit timezone boundary errors | Med | Med | "Crossing 45 days today" depends on dealer-local midnight | Compute in `dealer.timezone`; test DST + non-US offsets |
| **R-08** | Vendor performance data sparsity | Low | Med | Low-volume vendors give noisy averages | Min-sample threshold (≥10 jobs) before scoring; else "insufficient data" |
| **R-09** | `PUT /inventory/{vin}/status` vs stage PUT confusion | Low | Med | Two write paths could double-flip Ready | Stage PUT is the only recon writer; it *calls* status PUT once on Ready; guard on terminal states |
| **R-10** | Syndication leak of in-recon units | Low | High | A bug could expose locked units to listing sites | `syndication_locked` default TRUE; contract test asserts no in-recon VIN ever returns `FRONT_LINE_READY` |

---

## Appendix A — Endpoint Index

**Reused (11):** `/inventory/{vin}`, `/inventory/dashboard`, `/pricing/{vin}`, `/bookvalues/{vin}`, `/api/analytics/v2/iim/vehicle/stats`, `/vehicle/history/{vin}`, `/vehicle/images/{vin}`, `/reports/dashboard`, `/dealer/{id}`, `/users/me`, `/crm/customer/{id}` · plus `/crm/activity/{customerId}`, `/crm/leads`.

**Extended (2):** `GET /inventory/list`, `PUT /inventory/{vin}/status`.

**New — Inventory+ (9):** `/inventory/recon/scan`, `/inventory/recon/stages/{vin}`, `/inventory/recon/active`, `/inventory/vendor/{vendorId}/performance`, `/inventory/recon/{vin}/stage`, `/inventory/recon/floorplan/{dealerId}`, `/inventory/recon/ready`, `/inventory/recon/summary/{dealerId}`, `/inventory/aged/{dealerId}`.

**New — CRM/Notification (3):** `/crm/customerMatches/{vin}`, `/crm/leads/{id}/notify`, (Notification Engine WS push).

**New — Pricing (1):** `/pricing/gaps/{dealerId}`.

**New — VelocityIQ (1):** `/velocityiq/briefing/generate`.

**BFF (8):** `/velocityiq/dashboard`, `/velocityiq/recon`, `/velocityiq/recon/{vin}`, `/velocityiq/crm`, `/velocityiq/briefing`, `/velocityiq/analytics`, `POST /velocityiq/recon/scan`, `POST /velocityiq/crm/notify`.

---

*VelocityIQ v1.0 · Solera Inventory+ · Hackathon 2026 · This specification describes a production integration design; the current demo serves mock responses for every endpoint above.*

