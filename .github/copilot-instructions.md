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
- For public V2 endpoint changes, include swagger spec changes under `spec/swagger/api/v2/`.
- Do not suggest manual edits to generated `swagger/v2/swagger.json`.
- Treat tariff measures, quota logic, duty calculation, upstream sync, auth, and production operations as high-risk.
- Verify Code Wiki or other generated documentation against source files before relying on it.
