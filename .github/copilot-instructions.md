# Copilot Instructions

Use `docs/README.md` and `docs/architecture/README.md` before suggesting broad changes.
Use `docs/development-and-delivery.md` and `docs/confluence.md` for wider team/process context.

Project facts:

- Rails API application.
- Sequel/PostgreSQL data layer.
- Redis and Sidekiq for locks and background jobs.
- OpenSearch for search and cache indexes.
- UK/XI service mode is selected with `SERVICE`.

Guidance:

- Keep suggestions narrowly scoped to the requested change.
- Prefer existing service, query, presenter, and serializer patterns.
- Write controller coverage as request specs under `spec/requests/`. Do not add new files under `spec/controllers/`; when touching legacy controller specs, migrate the coverage into request specs and remove the controller spec.
- Request specs must use concrete paths or route helpers, not controller-style action symbols such as `get :show`.
- For public V2 endpoint changes, include swagger spec changes under `spec/swagger/api/v2/`.
- Treat swagger specs as API documentation coverage, not a replacement for request specs.
- Do not suggest manual edits to generated `swagger/v2/swagger.json`.
- Use Ruby data classes such as `Data.define` for simple value objects. Do not introduce `Struct`.
- Treat tariff measures, quota logic, duty calculation, upstream sync, auth, and production operations as high-risk.
- Verify Code Wiki or other generated documentation against source files before relying on it.
