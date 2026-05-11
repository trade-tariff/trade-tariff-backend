# API Documentation

The public V2 API is documented as OpenAPI 3.0 generated from RSpec metadata using rswag.

## Source of Truth

- Swagger specs live under `spec/swagger/api/v2/`.
- Generated OpenAPI output lives at `swagger/v2/swagger.json`.
- The generation and coverage tasks live in `lib/tasks/swagger.rake`.
- CI generation is configured in `.github/workflows/ci.yml`.

Do not manually edit `swagger/v2/swagger.json` for endpoint changes. Update the relevant swagger spec and let CI regenerate the JSON.

## Local Preview

Run:

```sh
RAILS_ENV=test bin/generate-swagger
```

## CI Checks

CI enforces:

- `swagger:check_coverage`, which checks public V2 controller coverage.
- `swagger:generate`, which regenerates `swagger/v2/swagger.json`.
- An auto-commit step that commits generated swagger changes back to the branch after specs pass.

Internal and authenticated controllers are excluded in `lib/tasks/swagger.rake`.

## When Adding an Endpoint

1. Add or update the controller route in the relevant engine.
2. Add request/controller/service specs for behaviour.
3. Add or update a swagger spec under `spec/swagger/api/v2/` if the endpoint is public V2.
4. Run the relevant specs and `RAILS_ENV=test bin/generate-swagger` locally when practical.
5. Let CI commit the generated swagger JSON.
