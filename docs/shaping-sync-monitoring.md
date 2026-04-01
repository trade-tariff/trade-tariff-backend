---
shaping: true
---

# Daily Sync Completion Monitoring — Shaping

## Requirements (R)

| ID | Requirement | Status |
|----|-------------|--------|
| R0 | Trigger an escalatable alert when a daily tariff sync has not completed within an expected window | Core goal |
| R1 | Works for both UK (CDS) and XI (TARIC) services | Must-have |
| R2 | Alert routes via New Relic → PagerDuty (NR is the notification bridge already in use) | Must-have |
| R3 | Alert fires only when sync is genuinely overdue — no false positives on non-trading days | Out — CDS and TARIC both publish on bank holidays |
| R4 | Alert auto-resolves when sync subsequently completes | Must-have |
| R5 | "Completed" means `applied_at` is within the last N hours — not date-matched to today's issue date | Must-have |
| R6 | The staleness threshold is configurable without a code change | Must-have |
| R7 | Fits the existing worker + DB pattern; no new app infrastructure beyond NR configuration | Must-have |

---

## CURRENT: How sync health is tracked today

| Part | Mechanism |
|------|-----------|
| C1 | `sync_run_completed.tariff_sync` event emitted at end of each run — consumed only by `SyncLogger`, written to Rails logs, not persisted |
| C2 | `tariff_updates.applied_at` (DateTime) — written per-file when `mark_as_applied` is called. Most recent applied record is queryable but nothing polls it continuously |
| C3 | `SynchronizerCheckWorker` (runs 08:30 daily) — checks `QuotaBalanceEvent::Operation` recency as a proxy; fires `NewRelic::Agent.notice_error` if >4 days stale |
| C4 | `CdsUpdatesSynchronizerWorker` — Slacks `#tariffs-etl` directly if daily file is still missing at 10:00 cutoff |
| C5 | No auto-resolve path on any existing alert |

**Gaps in CURRENT:**
- `SynchronizerCheckWorker` uses a 4-day stale proxy (QuotaBalanceEvent), not actual sync completion
- `notice_error` has no resolve concept — NR cannot auto-close an incident based on it
- Running once daily means NR sees a single data point, not a time series — cannot build a threshold alert condition that auto-resolves

---

## Selected Shape: D — Custom New Relic metric + NR alert condition → PagerDuty

Record sync age as a continuous custom metric into New Relic. NR evaluates it on a rolling window — alert fires when age exceeds threshold, auto-resolves when it drops below. NR routes to PagerDuty via an existing (or new) notification channel. No PagerDuty credentials in the app.

| Part | Mechanism |
|------|-----------|
| D1 | Rewrite `SynchronizerCheckWorker` — query `TariffUpdate.where(state: 'A').max(:applied_at)` directly, replacing the 4-day QuotaBalanceEvent proxy |
| D2 | Compute `age_minutes = (Time.now.utc - last_applied_at) / 60.0`; call `NewRelic::Agent.record_metric("Custom/TariffSync/#{service}/AgeMinutes", age_minutes)` |
| D3 | Change schedule from once-daily at 08:30 → every 30 minutes — NR needs a time series to evaluate threshold conditions and auto-resolve |
| D4 | Threshold read from `ENV['SYNC_AGE_ALERT_THRESHOLD_MINUTES']` (default 480 = 8 hours); start conservative, tighten once normal completion baseline is established from the metric |
| D5 | Remove the Slack cutoff alert from `CdsUpdatesSynchronizerWorker` (line ~89, fires at 10:00 if daily file missing) — replaced by the NR metric alert |
| D6 | ⚠️ NR alert condition: `Custom/TariffSync/uk/AgeMinutes` and `Custom/TariffSync/xi/AgeMinutes` above threshold for **1 period** → trigger; below → auto-resolve |
| D7 | ⚠️ NR notification channel: create new PagerDuty channel and wire to the alert policy |

D6 and D7 are NR configuration — ops work outside the codebase. All app-side parts (D1–D5) are fully understood.

**On the threshold default:** The metric itself, recorded every 30 minutes from day one, will reveal normal completion times within a week. Start at 480 minutes (8 hours) and tighten via `ENV['SYNC_AGE_ALERT_THRESHOLD_MINUTES']` — no deploy needed.

---

## Fit Check: R × D

| Req | Requirement | Status | D |
|-----|-------------|--------|---|
| R0 | Trigger an escalatable alert when daily sync not completed within expected window | Core goal | ✅ |
| R1 | Works for both UK (CDS) and XI (TARIC) | Must-have | ✅ |
| R2 | Alert routes via New Relic → PagerDuty | Must-have | ✅ |
| R3 | No false positives on non-trading days | Out | — |
| R4 | Alert auto-resolves when sync subsequently completes | Must-have | ✅ |
| R5 | "Completed" = `applied_at` within the last N hours | Must-have | ✅ |
| R6 | Staleness threshold configurable without code change | Must-have | ✅ |
| R7 | No new app infrastructure beyond NR configuration | Must-have | ✅ |

---

## Open questions

| # | Question | Resolution |
|---|----------|------------|
| OQ1 | What is the typical CDS sync completion time? | Answered by the metric after ~1 week in production; threshold tightened via env var |
| OQ2 | Does NR already have a PagerDuty notification channel? | No — creating one (D7) |
| OQ3 | Alert on first breach or require sustained breach to avoid flapping? | First breach (1 period) |
| OQ4 | Keep, replace, or remove existing Slack cutoff alert in `CdsUpdatesSynchronizerWorker`? | Remove — replaced by NR metric alert (D5) |
