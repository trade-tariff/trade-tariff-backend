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

The backend returns AI expansion terms separately in
`meta.interactive_search.query_expansion.ai_terms`. The frontend passes this
object back with each answer. An empty list means no AI expansion. Missing or
invalid expansion data on a supplied expanded query prevents terminal capture: the
query may already contain answers, so its expansion cannot be recovered safely.
Mechanical synonym additions come from the current retrieval. Neither field
changes retrieval or ranking.

Deploy backend support before the frontend starts carrying this field. Older
clients and in-flight journeys can lack this expansion data. Their uncaptured journeys
are not counted as export omissions. Existing logs are not repaired.

Dates are inclusive UTC dates. For each request ID, the export uses its latest
terminal trace within that window. Successful frontend commodity `show` requests
(HTTP 200 or 304) join through `params.request_id`; only `params.id` codes in the
offered results appear in the workbook. Classic searches without a guided terminal
trace do not become rows. Distinct opened codes appear in first-visit order,
with descriptions from the terminal trace. No additional frontend capture
endpoint is required.

The template retains the **Results clicked** column name, but the value is an
observed successful frontend page request, not proof of a literal click or page
view. A blank means no linked visit was observed; a visit served entirely from
browser cache may not generate a frontend request. Backend `result_selected`
events do not establish this value because frontend caching can bypass them.

A visit counts from the journey's first exported terminal response until
midnight UTC at the end of the following day, or until export generation if that
is earlier. For a one-day export, this is the export's next-day cutoff. Later
visits are not included. Linked failure
events mark a journey as omitted. Invalid rows, including more than seven
questions or an answer not offered, also contribute to the omission count.

Only available logs can be exported. Dates before v2 trace deployment, expired
logs and unrecorded journeys cannot be reconstructed and are not counted as
omissions. An empty workbook does not establish that no searches took place.
Recent exports are provisional because log ingestion and visits can arrive later.

## Temporary job and download storage

Redis holds job metadata and workbook bytes in separate keys. Status polling
never fetches the file. Both keys expire one hour after job creation. An atomic
claim prevents duplicate execution; completion does not extend expiry or replace
a failed job. Sidekiq does not retry failed exports automatically.

A SHA-256 fingerprint of the service and normalised dates identifies equivalent
export requests. An atomic Redis transaction returns the existing queued or
running job for repeated submissions. Only the request that creates a job queues
it. Completed, failed or expired exports allow a fresh submission.

The handoff uses the existing Sidekiq Redis connection, not `Rails.cache`;
worker caching remains disabled. Redis loss or expiry requires a new export request.

## Log retrieval

The reader first queries backend and worker streams one UTC day at a time. It
then queries frontend streams for the same days, for the Result journeys that
can have visits on each day. Search-linked frontend requests, mostly from classic
search, far outnumber guided journeys, so the journey query does not read them.
Visit queries filter on request ID prefixes to stay within the CloudWatch query
length limit; the reader then matches complete request IDs.

The visit pass scans each day again, so an export scans about twice as much log
data as journey retrieval alone. One visit query covers up to 900 Result journeys.
A day with more journeys from that day and the previous day needs another query,
which scans the day again. Before it reads visits, the reader projects their scan
from the journey scan of each day. It fails at once if the total would exceed
500 GiB.

Each query splits a window when results reach the CloudWatch limit or query
statistics show more matches than returned rows.
Half-open timestamp filters prevent overlap between split windows. A saturated
one-second window fails the export rather than returning a partial workbook.

Log collection stops after 40 minutes or when reported cumulative scanning
exceeds 500 GiB. Repeated polling statistics count only the increase for each
query. An unfinished query is cancelled on failure. Scanning can continue between
polls or during cancellation, so this is not a hard billing cap.

There are no application limits on retrieved bytes, query count, journey count,
date-span length, retained jobs or file size.
The reader fails on incomplete queries or malformed required data; it does not
publish rows collected before that failure. The workbook must fit the Excel
worksheet format.

Filtering shared application streams still scans unrelated traffic. The worker
role needs permission to start, read and stop Logs Insights queries for the
platform log group. No IAM changes are included.
