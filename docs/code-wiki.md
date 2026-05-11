# Google Code Wiki

[Google Code Wiki](https://codewiki.google/) is a hosted public-preview tool that generates structured documentation for public repositories. Google describes it as scanning public repositories, generating linked documentation, providing Gemini-backed chat, and creating diagrams for architecture, classes, and sequences.

Use it as an exploration aid for this repository:

- Open `https://codewiki.google/`.
- Search for or import `trade-tariff/trade-tariff-backend`.
- Use generated pages and chat answers to find candidate files and concepts.
- Verify important claims against this repository before making changes.

## What To Trust

Good Code Wiki use cases:

- Getting a first-pass map of unfamiliar code.
- Finding likely entrypoints for a feature area.
- Asking high-level questions before reading source files.
- Comparing generated diagrams with local architecture docs.

Do not treat generated output as authoritative for:

- Legal or regulatory tariff behaviour.
- CDS/TARIC import semantics.
- Measure, duty, quota, certificate, or rules of origin logic.
- Security, auth, and secret-handling behaviour.
- Production operations or rollback instructions.

For those areas, verify against source code, tests, ADRs, and existing docs.

## Local Verification Anchors

Start with:

- [Documentation index](README.md)
- [Architecture index](architecture/README.md)
- [API documentation flow](architecture/api-documentation.md)
- [Goods Nomenclature Nested Set](goods-nomenclature-nested-set.md)
- [Generated classification content lifecycle](generated-classification-content-lifecycle.md)
- [Caching within the Trade Tariff apps](caching.md)
- [Windsor Framework - Green Lanes](green-lanes.md)
- [Rules of Origin](rules_of_origin.md)

Useful source anchors:

- `config/routes.rb`
- `app/engines/`
- `app/controllers/api/`
- `app/models/`
- `app/services/`
- `app/lib/`
- `app/workers/`
- `lib/tasks/`
- `spec/swagger/api/v2/`

## Keeping Local Docs Useful

When changing a subsystem, update the smallest relevant doc page. Prefer linking to existing docs over copying long explanations. If Code Wiki gives a useful generated explanation, convert only the verified, stable parts into local docs.
