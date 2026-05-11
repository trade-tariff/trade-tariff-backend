# Request Routing

The top-level router mounts several Rails engines depending on service mode. See `config/routes.rb`.

## Top-Level Routes

- `/healthcheckz` maps to `HealthcheckController`.
- Sidekiq routes are drawn from `config/routes/sidekiq.rb`.
- Error routes are drawn from `config/routes/errors.rb`.
- Admin, internal, user, V1, and V2 APIs are mounted as engines.

## Service Prefixes

Routes are explicitly mounted under `/uk` and `/xi` where the service mode allows it:

- `/uk/admin` and `/xi/admin` mount `AdminApi`.
- `/uk/internal` and `/xi/internal` mount `InternalApi`.
- `/uk/user` mounts `UserApi`.
- `/uk/api` and `/xi/api` mount `V1Api` or `V2Api` depending on the request version constraint.

`VersionedForwarder` supports legacy path-version requests matching `/:service/api/v:version/*path`.

## V2 Public API

`app/engines/v2_api.rb` defines the public V2 API surface. It includes tariff hierarchy endpoints, measures, quotas, certificates, search, rules of origin, news, exchange rates, Green Lanes, changes, and error responses.

Most V2 routes map to controllers under `app/controllers/api/v2/`. Serialisation usually flows through `app/serializers/api/v2/` and presenter classes under `app/presenters/api/v2/`.

## Admin, Internal, and User APIs

- `app/engines/admin_api.rb` exposes admin workflows such as updates, rollbacks, reports, content management, Green Lanes admin data, generated labels, generated self-texts, and search references.
- `app/engines/internal_api.rb` exposes internal search endpoints.
- `app/engines/user_api.rb` exposes MyOTT/user subscription and tariff changes endpoints.

Treat these surfaces separately when changing behaviour. Public V2 API changes usually need swagger coverage under `spec/swagger/api/v2/`; internal and admin changes usually need request/controller specs but are not always public OpenAPI endpoints.

## Routing Compatibility

`docs/adr/2025-10-20_api_semantics_changes.md` records the intended API semantics direction. New work should prefer explicit service routing and header-based versioning, while keeping legacy path forwarding in mind for existing consumers.
