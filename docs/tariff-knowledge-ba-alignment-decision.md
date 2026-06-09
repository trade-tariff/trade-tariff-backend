# Tariff Knowledge BA Alignment Decision Gate

The archive comparison is reproducible, but it shows the Rails spike and BA archive are not equivalent outputs. This document records the implementation decision that needs to be made before continuing stacked PR work.

## Inputs

- Spike PR: <https://github.com/trade-tariff/trade-tariff-backend/pull/3237>
- ADR: `docs/adr/2026-06-04_tariff-knowledge-graph.md`
- Archive: `~/Downloads/ai-fan-out-third-party-20260604.zip`
- Reproducible comparison: `docs/tariff-knowledge-archive-comparison.md`

## What The ADR Already Decides

The ADR chooses a Rails/Postgres knowledge graph, scoped to the active tariff schema, with typed nodes and typed edges.

It also says:

- the nested set remains the taxonomy source of truth;
- source documents and extracted fragments/rules should retain provenance;
- source-expressed ranges should be preserved and deterministically expanded where lookup needs it;
- generated or compressed output must fit the existing generated-content review model;
- the first delivery should stay narrow and prove the model before broadening source types.

That means the implementation does not need to clone the BA archive schema. The archive can be used as a behavioural reference, but Rails should still follow the ADR and existing generated-content patterns.

## What The Archive Proves

The archive contains the `kg` schema, data dump, viewer code, and retrieval endpoints. I did not find the original generator in the archive, so the restored database contents are the authoritative BA output.

The archive's KG shape is:

- `kg.kg_edges`: rule/clause-like rows;
- `kg.kg_edge_commodities`: explicit edge-to-commodity-code links;
- `kg.commodity_facets`: per-code structured facts;
- `kg.composite_search_text`: per-code contextual search text.

It does not have the same node table shape as the Rails spike. The closest node-like sets are KG edge IDs and commodity-code sets.

## Current Non-Equivalence

Latest verified comparison run:

```sh
ARCHIVE_DB=$(cat /tmp/ai868_kg_compare/archive_db_name) \
  script/tariff_knowledge_archive_compare \
  --out /tmp/ai868_kg_compare/clean-worktree-compare-20260609T090537Z
```

Headline differences:

| Area | Archive BA output | Rails spike output |
| --- | ---: | ---: |
| Comparable rule/edge rows | 600 | 433 |
| Comparable linked-code rows | 995 | 300,822 |
| Comparable scopes | 76 | 94 |
| Strict normalized rule matches | 35 | 35 |

Source coverage differs:

- Archive-only: GIR/global plus chapters `33`, `52`, `53`, `75`, `76`, `78`, `79`, `80`.
- Spike-only: 27 scopes, including chapters `02`, `04`, `11`, `12`, `15`, `20`, `22`, `27`, `28`, `29`, `38`, `39`, `40`, `48`, `59`, `61`, `62`, `71`, `72`, `84`, `85`, `90`, `95`, `96`, and sections `11`, `15`, `16`.

Link semantics differ:

- Archive links are narrow explicit `kg_edge_commodities` rows.
- Spike links each rule to every current declarable in the source scope plus every declarable resolved from parsed references.

That spike behaviour creates very large deltas, for example:

| Scope | Archive linked codes | Spike linked codes |
| --- | ---: | ---: |
| `section:17` | 27 | 5,255 |
| `section:7` | 3 | 3,753 |
| `chapter:94` | 30 | 3,551 |
| `chapter:44` | 34 | 3,460 |

## Decision Required

Choose one of these directions before continuing implementation PRs.

### Option A: Match BA Link Semantics More Closely

Use the archive as the target behaviour for rule-to-code links.

Implementation consequences:

- add explicit GIR/global source ingestion;
- preserve source-expressed target ranges as first-class graph concepts or structured provenance;
- avoid broad source-scope `applies_to` expansion for every rule;
- create narrower, source-evidenced links from parsed references and curated/source-defined scope;
- treat the comparison harness as a regression gate where comparable archive/spike deltas should shrink.

Tradeoff: closer to BA output and easier to explain per-rule links, but more work before compression/API/admin PRs can proceed.

### Option B: Accept Rails Spike Expansion As The Product Direction

Use the archive for reference only, but intentionally keep broader generated links because compressed notes need all relevant declarable contexts.

Implementation consequences:

- document that link count parity with BA is not a goal;
- keep broad `applies_to` expansion but make provenance and `resolution_reason` reviewable;
- add GIR/global ingestion separately if GIR context is required for compressed notes;
- keep the comparison harness as an observability report rather than a pass/fail regression gate.

Tradeoff: faster path through the stacked PRs and aligned with the current spike, but BA parity remains poor and must be explicitly accepted.

## Recommendation

Prefer Option A for graph edges, with one refinement: keep declarable-context generation broad only as a derived projection, not as the core rule-to-code graph truth.

That gives us:

- BA-like explicit KG relationships for explainability and future review;
- ADR-aligned range preservation and deterministic expansion;
- generated compressed notes for every impacted declarable without treating every projected context as a core source fact;
- a cleaner admin review story because reviewers can inspect narrow source facts separately from generated per-declarable projections.

In practical PR terms:

1. Keep the already-open data model PR as the base.
2. Add a focused backend PR for declarable reference loading only.
3. Add a focused backend PR for source/rule ingestion that preserves rule targets and ranges without broad source-scope `applies_to` expansion.
4. Add GIR/global source ingestion if accepted as in scope.
5. Add compressed context generation as a derived reviewable projection.
6. Add backend admin APIs.
7. Add admin UI review/edit flows.

## Open Questions

1. Should GIR/global rules be included in the Rails implementation now?
2. Should broad source-scope `applies_to` edges be removed from the core graph and moved to compressed-context projection only?
3. For archive-only and spike-only source scopes, should current Rails tariff data be the source of truth, or should BA archive coverage be treated as the expected source set?
4. Should `script/tariff_knowledge_archive_compare` become a committed regression tool, or remain a spike-analysis helper?
