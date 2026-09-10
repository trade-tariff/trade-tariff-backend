# Queued internal search

The queued search API is an additive, backend-only interface for testing an
asynchronous guided-search journey. Existing synchronous `/internal/search`
callers and the frontend are unchanged. It reuses `Api::Internal::SearchService`
rather than introducing a second search implementation.

## API contract

Routes are mounted beneath `/uk/internal` or `/xi/internal`, according to the
backend's service mode. The examples below use UK.

### Submit

`POST /uk/internal/queued_searches` accepts the same top-level inputs and strong
parameter rules as the existing internal search endpoint:

- `q`
- `as_of`
- `request_id` (the search journey's correlation ID, not the queued payload ID)
- `expanded_query`
- `skip_question`
- `answers`, containing `question`, `answer` and `options`

As in synchronous search, `options` can be a JSON-encoded array string. This
endpoint does not expand the existing parameter contract or accept configuration
overrides. Query sanitisation and search validation happen in the worker through
the existing search service.

Example body:

```json
{
  "q": "horse",
  "as_of": "2025-01-02",
  "request_id": "journey-123",
  "skip_question": false,
  "answers": [
    { "question": "Use?", "answer": "Racing", "options": "[\"Racing\",\"Breeding\"]" }
  ]
}
```

The backend stores the permitted inputs and request context in Sidekiq Redis,
then enqueues `QueuedSearchWorker` with only the generated UUID. It returns
`202 Accepted` only after enqueueing succeeds:

```json
{ "id": "d9b7a5ad-56a0-4abf-8a9b-5c1391f1c42f", "status": "queued" }
```

A Redis failure or rejected enqueue returns `503`, not an accepted ID. A rejected
enqueue removes the payload. If a Redis connection fails during enqueueing, the
outcome can be ambiguous: an orphaned payload expires automatically, and a job
may already have been accepted before the connection failed. Submissions are not
idempotent; each new submission creates a new ID.

### Poll

`GET /uk/internal/queued_searches/:id` reads state and returns immediately. It
does not wait for a worker, run search, or enqueue more work.

Existing payloads return `200` with `id`, `status`, `created_at` and `updated_at`.
Terminal payloads also contain `response_status` and `result`:

```json
{
  "id": "d9b7a5ad-56a0-4abf-8a9b-5c1391f1c42f",
  "status": "completed",
  "created_at": "2025-01-02T10:00:00Z",
  "updated_at": "2025-01-02T10:00:04Z",
  "response_status": 200,
  "result": { "data": [], "meta": { "search_failures": [] } }
}
```

`result` preserves the existing synchronous search response body, including
interactive questions, fallback metadata or validation errors. `response_status`
is the equivalent search HTTP status, not the polling request's HTTP status:

| State | Poll HTTP status | Search response status | Poller action |
| --- | --- | --- | --- |
| `queued` | 200 | Absent | Wait, then poll again |
| `running` | 200 | Absent | Wait, then poll again |
| `completed` | 200 | 200 | Stop polling and serve `result` |
| `failed` | 200 | 422 or 500 | Stop polling and show recovery |
| Missing or expired | 404 | Absent | Stop polling; a new submission is required |
| Redis unavailable | 503 | Absent | Use bounded retry/backoff, not a tight loop |

Pending responses do not expose the submitted inputs or request context.
Recoverable search fallbacks are still completed searches, with the existing
`meta.search_failures` contract intact. Exceptions store a safe generic search
error, not the exception message, and are re-raised for Sidekiq error reporting.

## Flow

```text
  Future frontend poller          Backend web / Puma        Sidekiq worker
  ======================          ==================        ==============

  POST queued_searches ----------> Store payload in Redis
                                  Enqueue UUID ------------> Claim payload
  <--------------- 202 + UUID     Release request thread     Mark running
          |                                                       |
          |                                                       v
          |                                               Existing search service
          |                                               (slow work happens here)
          |                                                       |
          |                                                       v
          |                                               Save result + status
          |                                                       |
          |                                                       v
          |                     +---------------------------------------+
          |                     | Sidekiq Redis: inputs, context, state, |
          |                     | timestamps, result, response status    |
          |                     +---------------------------------------+
          |                                      |
          |                                      | read only
          v                                      v
  GET queued_searches/:id -------> Return current state immediately
  <------------------------------ No long-held web request
          |
          +-- queued/running --> wait, then repeat
          +-- completed -------> stop and display result
          +-- failed/404 ------> stop and show recovery
```

A future Stimulus controller should keep the existing throbber and loading
message visible continuously while polling, then replace them with the result
or recovery message. That frontend behaviour is not implemented here.

## State machine

```text
                successful Redis write + enqueue
                              |
                              v
                         +----------+
                         |  queued  |
                         +----+-----+
                              |
                              | atomic worker claim
                              v
                         +----------+
                         | running  |
                         +----+-----+
                              |
                 +------------+-------------+
                 |                          |
                 | normal result            | validation error / exception
                 v                          v
           +-----------+               +----------+
           | completed |               |  failed  |
           +-----------+               +----------+

  Any stored state -- one-hour retention expires --> missing (GET returns 404)
```

- Payloads use `queued_search:<service>:<uuid>` keys in **Sidekiq Redis**, not
  Rails cache. UK and XI payloads are separate even if Redis is shared.
- Each JSON payload has a fixed one-hour TTL from submission. Polling and worker
  transitions do not extend it. This is temporary job state, not search caching.
- A Redis compare-and-set script makes claims and terminal writes atomic. Only a
  queued payload can become running, and only a running payload can finish.
  Duplicate deliveries do not execute an already-claimed search or overwrite a
  terminal result. A late completion cannot recreate an expired key.
- The result and terminal status are written together, so `completed` never
  means a partially stored result.
- Request ID, request source, client ID, experiment and the submission's effective
  date are restored for search execution. Request-local search failure state is
  isolated and restored afterwards. Missing `as_of` defaults to the submission
  date, rather than the date a delayed worker eventually starts.
- Automatic Sidekiq retries are disabled. A failed search requires a new
  submission. If the process is killed after claiming, the payload stays running
  until expiry; this version does not reclaim abandoned work.
- Expiry bounds stored data retention, not execution time. It does not interrupt
  an already-running search. The search service's existing downstream timeouts
  still apply, and late results are discarded.

## Rollout and integration

There is no runtime feature gate. Activation is controlled by introducing a
caller: no existing frontend or other integration submits queued searches.

Deploy the backend and workers before enabling any caller, including manual test
submissions. Confirm that all workers consuming the relevant service's `default`
queue have `QueuedSearchWorker` and that old worker tasks have stopped. Check UK
and XI separately where applicable. During a mixed-version rollout, an old
worker can consume the new job class, fail to load it and discard it because
retries are disabled, leaving the accepted payload queued until expiry.

For rollback, stop all callers and let accepted work drain before replacing
workers with a release without the class. Any future integration must preserve
this deployment ordering; the endpoint itself does not check worker readiness.

## Scope and operational limits

This API uses the existing internal routing/access boundary. UUIDs are opaque
lookup handles, not authentication. There is no new browser/session ownership
check: trusted internal clients possessing an ID can retrieve its result. Before
connecting a public browser journey, the frontend must enforce the appropriate
session ownership and must not expose internal API access directly.

The worker uses the existing `default` queue. No queue topology, concurrency,
frontend, infrastructure, public V2 API or synchronous search behaviour changes
are included. Use controlled test traffic: this interface does **not** establish
worker isolation, admission control, a payload-size limit, or protection against
Redis/worker saturation. One-hour retention is not a bound on total memory at
arbitrary submission rates.

Production adoption still needs capacity/load measurements, suitable worker
isolation, polling deadlines/backoff, abandoned-job handling and the frontend
access/recovery journey. Stop test submissions and let work drain before rolling
back to a release without the worker class; otherwise queued jobs reference an
unknown class. The retained payloads expire without a data migration.

## Source and verification

- Routes: `app/engines/internal_api.rb`
- Controller: `app/controllers/api/internal/queued_searches_controller.rb`
- Payload lifecycle: `app/models/queued_search.rb`
- Worker: `app/workers/queued_search_worker.rb`
- Existing search: `app/services/api/internal/search_service.rb`
- Existing payload precedent: `app/controllers/api/v2/enquiry_form/submissions_controller.rb`

Run request, real-Redis lifecycle, worker and synchronous search regression
coverage:

```sh
bundle exec rspec spec/requests/api/internal spec/services/api/internal \
  spec/models/queued_search_spec.rb spec/workers/queued_search_worker_spec.rb
```
