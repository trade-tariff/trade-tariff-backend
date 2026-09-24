# Classifier workbook export

The UK admin API queues a Sidekiq job and returns an export ID. The admin polls
that ID, then downloads the XLSX when its status is `ready`. No admin request
runs a CloudWatch query. The export does not create PostgreSQL tables or S3
objects. The admin feature must follow deployment of these backend endpoints.

## Source and reporting window

The worker reads `evaluation_journey_recorded` terminal traces from UK backend
and worker streams in the platform log group. Only frontend requests with
`classification_evaluation_trace.v2` provide workbook rows. Each trace contains
the original query, expansion terms actually used, accumulated question history
and the displayed result descriptions, order and confidence labels. No later
commodity lookup changes those descriptions.

Dates are inclusive UTC dates. For each request ID, the export uses its latest
terminal trace within that window. Existing backend `result_selected` events
join by request ID; classic searches without a guided terminal trace do not
become rows. Distinct clicked codes appear in first-click order, with descriptions
from the terminal trace. No additional frontend capture endpoint is required.

Click collection ends at the earlier of export generation and midnight UTC one
day after the requested end date. Later clicks are not included. Linked failure
events mark a journey as omitted. Invalid rows, including more than seven
questions or an answer not offered, also contribute to the omission count.

Only available logs can be exported. Dates before v2 trace deployment, expired
logs and unrecorded journeys cannot be reconstructed and are not counted as
omissions. An empty workbook does not establish that no searches took place.
Recent exports are provisional because log ingestion and clicks can arrive later.

## Temporary job and download storage

Redis holds job metadata and workbook bytes in separate keys. Status polling
never fetches the file. Both keys expire one hour after job creation. An atomic
claim prevents duplicate execution; completion does not extend expiry or replace
a failed job. A queued or running job becomes failed after 15 minutes without a
state transition. Sidekiq does not retry failed exports automatically.

Admission is limited to three retained exports per service, including completed
and failed exports. Each workbook is limited to 10 MiB. This bounds retained
file payloads to 30 MiB per service, excluding metadata and Redis overhead. The
handoff uses the existing Sidekiq Redis connection, not `Rails.cache`; worker
caching remains disabled. Redis loss or expiry requires a new export request.

## Retrieval limits

The reader queries one UTC day at a time. It splits a window when results reach
the CloudWatch limit or query statistics show more matches than returned rows.
Half-open timestamp filters prevent overlap between split windows. A saturated
one-second window fails the export rather than returning a partial workbook.

Each export permits at most 512 queries, 100 MiB of accepted log messages,
200,000 journeys and ten minutes of query polling. A scan-budget check cancels
queries after reported cumulative scanning exceeds 10 GiB. This is not a hard
billing cap: scanning can continue between polls or during cancellation. The
reader fails on incomplete queries, malformed required data or exceeded limits;
it does not publish the rows collected before that failure.

These are per-export limits, not process-memory limits. Ruby objects, query
responses and XLSX generation require additional memory. Filtering shared
application streams still scans unrelated traffic. Confirm the worker role can
start, read and stop Logs Insights queries for the platform log group before
enabling the admin feature. No IAM changes are included.
