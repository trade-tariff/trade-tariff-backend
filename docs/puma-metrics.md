# Puma request capacity metrics

The opt-in `PumaMetrics::Plugin` reports web request thread occupancy and queue
backlog. Collector behaviour is kept aligned in the frontend and backend
repositories; the plugin's application-environment lookup is repository-specific. Backend UK and XI report separately; Sidekiq does not run the
Puma server configuration and does not start this reporter.

## Enable through the application configuration secret

Add this string value to the existing **web application's configuration
secret**, not to the Sidekiq worker secret:

```json
{
  "PUMA_METRICS_ENABLED": "true"
}
```

Apply this to frontend, backend UK API and backend XI API configuration as
required. `PUMA_METRICS_SERVICE` is optional: the Puma configuration defaults it
to `frontend` or `backend-${SERVICE}` (UK when SERVICE is absent). If explicitly
set, use `frontend`, `backend-uk` or `backend-xi` to match the dashboards.

Environment comes from existing application configuration, not a separate
telemetry setting or `RAILS_ENV`. Frontend uses `TradeTariffFrontend.environment`
(the existing `ENVIRONMENT`, default `production`). Its config module can load
in the Puma master without Rails. Backend reads the same existing `ENVIRONMENT`
source and `local` fallback as `TradeTariffBackend.environment`, without booting
Rails just to read it. Staging therefore keeps its staging label even when
`RAILS_ENV=production`. No additional environment key is required.

**Changing the secret alone does not change a running process.** Follow the
normal deployment/configuration-refresh workflow so the secret values reach
the task definition and replacement tasks. These repositories currently read
configuration secrets into task environment values during Terraform execution;
a force-new-deployment of an unchanged task definition may retain old values.
This change does not modify secrets or ECS environment wiring. To disable, set
`PUMA_METRICS_ENABLED` to `false` and use the same refresh workflow.

## How collection works

- One background thread per Puma master, sampling every 10 seconds. In single
  mode the sampler runs beside the request threads in the single process.
- Uses `launcher.stats`, not a Rails endpoint, control socket, Sidekiq job or
  per-request hook. No database, metadata endpoint or AWS SDK calls.
- In cluster mode Puma already sends worker check-ins to the master. These are
  cached snapshots, not instantaneous observations at emission time.
- Unbooted/invalid workers are counted as unready. Workers with check-ins older
  than 30 seconds (or three configured check-in intervals, whichever is larger)
  are counted as stale, not as idle. Only fresh workers retain PID/index and
  check-in age in the log record; stale workers contribute to the count only.
- Emits one raw JSON line in CloudWatch Embedded Metric Format (EMF) to stdout.
  The existing ECS log pipeline must preserve that JSON as the log message.
  EMF extraction uses CloudWatch Logs; the application does not need
  `cloudwatch:PutMetricData` permission or an additional SDK dependency.
- Uses a nonblocking write with no retry or buffer. Backpressured, closed or
  failing output drops the sample. Lines larger than 4 KiB are also dropped to
  bound logging work; this comfortably covers the observed four-worker tasks.
  Unusual worker counts or oversized labels need the event size reviewed before
  enabling. On transports allowing partial writes, the affected log event may
  be unusable; it is not retried. Missing telemetry must never imply idle capacity.
- The shutdown callback wakes and stops the loop using a signal-safe queue.
  Phased worker restarts retain the single master collector. Full master
  restarts replace the process image and create a new collector identity.

This adds a small, bounded amount of CPU and log volume, not zero overhead.
Confirm ingestion and resource overhead in development/staging before production.

## Metrics and interpretation

Namespace: `TradeTariff/Puma`. Dimensions: **Environment, Service** only.
Task/collector UUID and worker PID/index are log properties, not paid metric
dimensions. Each metric therefore has bounded cardinality across task turnover.

| Metric | Meaning | Useful statistic |
| --- | --- | --- |
| `BusyThreads` | `max_threads - pool_capacity`: occupied slots, excluding queued requests | Maximum / Average |
| `AvailableThreads` | Puma's available pool capacity | Minimum / Average |
| `MaxThreads` | Configured request slots per worker | Maximum |
| `Utilization` | Busy threads divided by maximum threads, percent | Maximum / Average |
| `Backlog` | Requests in a worker's internal thread-pool queue at check-in | Maximum |
| `BacklogMax` | Puma's recorded peak backlog since previous stats reads | Maximum |
| `ExpectedWorkers` | Workers known to the master, including startup/restart workers | Maximum per task |
| `ReportingWorkers` | Fresh workers included in this sample | Minimum per task |
| `StaleWorkers` | Workers whose last check-in is too old | Maximum per task |
| `UnreadyWorkers` | Workers not booted or without usable statistics | Maximum per task |
| `SaturatedWorkers` | Fresh workers with no available request slots | Maximum per task |

Worker metrics are EMF arrays: each worker contributes a sample. Coverage
metrics are per-master scalars. **Do not use Sum over a time range for these
gauges.** It adds repeated observations, not simultaneous capacity. An Average
is a sample average, not necessarily capacity-weighted when workers differ.

Puma 8's `busy_threads` includes backlog; `running` means spawned threads. Neither
is used as the executing-request count. Puma stats reads reset its maxima;
another stats consumer can shorten the interval represented by `BacklogMax`.

These are **not queue-wait durations**. Backlog does not include every request
waiting in kernel sockets, the load balancer or another application. A slow
backend can occupy a frontend thread while the backend is still queueing.
Therefore frontend and backend occupancy cannot be added into a single shared
capacity figure. CPU, memory and downstream connection/provider limits still
matter even when thread capacity is available.

## Dashboards

`terraform/puma_metrics.tf` creates a dedicated dashboard, without touching the
existing manually managed dashboards or ECS settings:

- `Puma-frontend-<environment>` in the frontend repository.
- `Puma-backend-<environment>` in the backend repository (UK and XI sections).

**Start here:** each service has an aligned summary row: queued requests in the
busiest worker, threads in the least-spare worker, reporting collectors, then
running/desired ECS tasks. Both backend service summaries appear before any
diagnostics. The dashboards link to each other and to this guide; there is no
new shared dashboard resource.

Summary metrics and reporting-collector bins use 60 seconds. A collector seen
at least once during that minute counts once, even if its workers are stale or
unready. This is a task-coverage proxy, not an exact simultaneous task count:
master restarts and rolling replacements can contribute multiple identities.
Compare it with ECS counts and inspect worker reporting/expected/stale/unready
coverage in the diagnostics before trusting spare capacity. Missing telemetry
is not a measured zero; charts do not fill gaps or infer health from an empty
internal queue. Extrema may come from different workers and different times,
so matching queue and spare-thread extrema do not establish a correlation.

Diagnostic charts separate thread totals from queued-request totals and use
explicit worker/service scope. Capacity totals exclude records without worker
capacity fields rather than aggregating missing capacity into a false zero.
Fleet charts use Logs Insights to take one latest snapshot per collector per
10-second bucket before summing. These are sampled totals for **reporting workers only**, not exact
instantaneous fleet measurements. Sampling boundaries, deployment overlap and
missing records can distort totals; compare reporting coverage with ECS tasks.
If all collectors disappear, there is no record to plot: a blank is not zero.

Use a short window for 10-second log charts. Seven-day/month views should use
coarser bins to avoid query/visualisation limits, with explicit treatment of
collector turnover. CloudWatch high-resolution metric detail is retained for
3 hours, 1-minute data for 15 days, 5-minute data for 63 days and 1-hour data for
455 days. Maxima remain useful after aggregation, but historical sub-minute
shape cannot be reconstructed. Retained raw log snapshots can support a
separate offline analysis at their original resolution.

Do not set arbitrary rollout alarms in this change. Establish a baseline,
check coverage, and agree service-specific thresholds alongside normal-traffic
response times before using these measurements as a go-live gate.

## Verification and rollout

1. Deploy code and dashboard through the normal approved workflow, initially
   outside production. Enable the reporter through the configuration secret.
2. Confirm valid `event = "puma.metrics"` JSON records in `platform-logs-<env>`.
   Confirm EMF extraction produces `TradeTariff/Puma` metrics with the expected
   environment and service, not merely log records. Inspect EMF processing
   errors if logs arrive but metrics do not.
3. Execute the dashboard's Logs Insights queries and check time-series rendering,
   not just their presence in the dashboard JSON. Capture staging screenshots for
   idle, sustained saturation, recovery and missing/partial telemetry. Confirm
   an operator can identify the affected service and any coverage gap without
   reading application code. This requires an approved staging rollout; local
   mock tests are structural checks, not rendered or ingestion evidence.
4. Compare reporting workers/task coverage with actual Puma startup logs and
   ECS task counts. Check that disabled applications and Sidekiq emit nothing.
5. In a safe environment, hold requests open to occupy all threads; confirm
   available capacity reaches zero and reports recover after release. Backlog
   may remain outside Puma's internal queue, so do not expect every waiting
   client to appear in `Backlog`.
6. Check restarts and log backpressure do not break serving/shutdown. Compare
   CPU/memory/log volume before and after enabling. No production load test is
   authorised by the instrumentation change.

Local checks (no AWS access or Rails/database boot required for these specs):

```sh
bundle exec rspec --options /dev/null spec/lib/puma_metrics_spec.rb spec/lib/puma_metrics_integration_spec.rb
bundle exec rubocop lib/puma_metrics.rb config/puma.rb spec/lib/puma_metrics*_spec.rb
terraform -chdir=terraform/modules/puma_capacity_dashboard init -backend=false
terraform -chdir=terraform/modules/puma_capacity_dashboard validate
terraform -chdir=terraform/modules/puma_capacity_dashboard test
```

The `puma-dashboard-test` CI job runs the Terraform tests using a mock AWS
provider, without AWS credentials or applying resources. These are structural
assertions, not evidence of deployed EMF extraction or query execution.

The RSpec integration tests launch real Puma in single and cluster modes, check
default service labels and existing application environment/defaults, hold a request
open, then wait for idle recovery. They cover full master and phased worker
restarts followed by serving and graceful shutdown. The phased scenario
explicitly disables preloading, including in backend where ordinary phased
restarts otherwise fall back to a full restart. Only the test subprocess uses
a shorter sampling interval.

## Keeping the repository copies in sync

Whoever changes this telemetry owns the paired update in frontend and backend.
Neither copy is an independent fork: submit companion changes together and run
the focused checks in both repositories. No shared package is required.

From the directory containing both checkouts, compare the shared sources:

```sh
for file in spec/lib/puma_metrics_spec.rb \
  terraform/modules/puma_capacity_dashboard/main.tf \
  terraform/modules/puma_capacity_dashboard/variables.tf \
  terraform/modules/puma_capacity_dashboard/tests/dashboard.tftest.hcl; do
  cmp "trade-tariff-frontend/$file" "trade-tariff-backend/$file" || exit 1
done
```

Review `lib/puma_metrics.rb` together: only the plugin environment lookup should
differ; collector behaviour stays aligned. The integration specs' expected
service/environment matrix is repository-specific; their lifecycle assertions
should stay aligned. Keep this guide aligned too. Puma registration, dashboard
callers and CI Terraform versions
remain repository-specific. Compare explicit source files, not generated
`.terraform` directories or module-local lockfiles.
