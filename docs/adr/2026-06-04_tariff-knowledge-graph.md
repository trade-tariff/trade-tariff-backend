# Tariff knowledge graph

Date: 4 June 2026
Status: Proposed

## Context

The goods nomenclature nested set gives us fast and reliable access to the tariff taxonomy. It answers structural questions such as:

- what is this goods nomenclature's parent?
- what are its ancestors?
- what are its descendants?
- is it declarable at a given point in time?

That is necessary but not sufficient for classification knowledge.

Legal notes, guidance and other classification sources can describe relationships that do not fit cleanly into a tree. A note can classify goods into a heading, exclude goods from a chapter, constrain how a heading should be read, or reference another part of the tariff at any depth. Those relationships may point to:

- the goods nomenclature itself
- an ancestor such as a chapter or section
- a sibling heading
- a range of headings
- a goods nomenclature outside the current branch
- a non-taxonomy concept such as a legal note source or extracted fragment

The nested set should remain the source of truth for taxonomy. We need a separate structure for legal and classification knowledge that can refer to taxonomy nodes without becoming the taxonomy itself.

One immediate use case is making chapter and section note facts available against goods nomenclatures. The same structure should be general enough for later classification knowledge sources.

## Decision

Introduce a tariff knowledge graph stored in Postgres.

The knowledge graph is scoped to the active tariff schema. UK and XI data should have separate schema-local graph rows or tables, matching the existing service-separated tariff data model. Graph lookups must not traverse across UK and XI tariff datasets.

The graph will model typed nodes and typed edges:

- nodes represent things we need to reason about, such as goods nomenclature references, note sources, note fragments, ranges, and derived knowledge artefacts
- edges represent facts or relationships between those things, such as `classifies`, `excludes`, `constrains`, `references`, `applies_to`, and `derived_from`

Edges should point from the artefact making the statement to the thing the statement is about. Query code can index and traverse both ends, but inverse edges should only be stored when they represent a separate domain fact.

Goods nomenclature nodes in the knowledge graph are references to tariff identifiers. They are not the authoritative hierarchy. Hierarchy, ancestry, descendants and validity remain owned by the existing nested set.

Source documents and extracted fragments should participate in the graph as nodes when they state, qualify or derive relationships. Their provenance metadata should remain structured storage rather than opaque graph-only data.

Source-expressed ranges should also be preserved as graph concepts. For example, a note that references "headings 2843 to 2846" should retain that range as the thing the source said. The range should then be deterministically expanded to the individual goods nomenclature reference nodes it covers so lookup by goods nomenclature stays cheap.

The graph is an additional access path for facts about goods nomenclatures. It should let callers quickly ask:

- what facts are connected to this goods nomenclature?
- what facts are connected to this goods nomenclature's ancestors?
- what source material produced those facts?
- which goods nomenclatures are affected if a source note changes?
- which relationships are valid for this date or tariff update context?

The immediate compression workflow has two phases:

1. While compressing notes for a declarable goods nomenclature, find the note references relevant to that declarable. This includes note fragments applying to the declarable or its ancestors, and references from those fragments to ancestors, siblings, ranges, or other tariff nodes.
2. When serving or reviewing a declarable goods nomenclature, find the compressed notes that already exist for that declarable and retain enough provenance to explain which note fragments they summarise.

## Non-functional requirements

The graph should be:

- **Fast for goods nomenclature lookups**: retrieving facts for one declarable goods nomenclature and its ancestors should complete in under 100ms in normal application paths with appropriate indexes, and should remain cheap in batch paths.
- **Source-traceable**: every derived fact should retain enough origin information to explain which note, fragment or source update produced it.
- **Deterministic where possible**: deterministic extraction and projection should be preferred for relationships that can be parsed or directly inferred.
- **Reviewable where generated**: where AI is used to produce or summarise knowledge, the generated output must fit the existing generated content review model rather than becoming hidden infrastructure.
- **Validity-aware**: relationships need validity windows or source-version context so callers do not mix facts from incompatible tariff states.
- **Incrementally refreshable**: source changes should identify impacted nodes and relationships without rebuilding the whole graph unnecessarily.
- **Queryable with ordinary backend tooling**: application code, support scripts and migrations should be able to inspect and test the graph using the existing Ruby, Sequel and Postgres toolchain.
- **Operationally boring**: the first implementation should avoid adding a specialist database unless Postgres fails measured access patterns.

## Storage pattern

The first implementation should use normal Postgres tables.

A likely shape is:

- `knowledge_nodes`
  - stable identifier
  - node type
  - external reference fields, where applicable
  - validity/source context
  - optional structured metadata

- `knowledge_edges`
  - source node
  - target node
  - relationship type
  - validity/source context
  - confidence or extraction metadata, if needed
  - source origin reference

- source origin tables or JSON structures
  - source type
  - source identifier
  - source hash or version
  - fragment identifier
  - human-readable citation text

The exact table names are not decided by this ADR, but the storage model should make edges first-class rows rather than burying relationships in opaque JSON. JSONB can still be useful for metadata and provenance that does not need to drive core access paths.

The first relationship vocabulary should stay narrow:

- `contains`: a source document contains a note fragment
- `applies_to`: a note fragment, range, or compressed note applies to a goods nomenclature reference
- `references`: a note fragment references another goods nomenclature reference or range
- `expands_to`: a source-expressed range deterministically expands to an individual goods nomenclature reference
- `summarises`: a compressed note summarises one or more note fragments
- `for_declarable`: a compressed note was produced for a specific declarable goods nomenclature
- `derived_from`: a generated or compressed artefact was derived from a source fragment, extraction run, compression run, or previous artefact

Ranges need two representations:

- a graph node that preserves the range expression from the source
- deterministic membership edges or rows that connect the range to each goods nomenclature reference it covers

This lets us explain the source faithfully while still supporting indexed lookup by individual goods nomenclature.

Example graph facts:

- `chapter_note_source(17) --contains--> note_fragment(17.1)`
- `note_fragment(17.1) --applies_to--> chapter(17)`
- `note_fragment(17.1) --references--> heading(1704)`
- `note_fragment(28.3) --references--> range("headings 2843 to 2846")`
- `range("headings 2843 to 2846") --expands_to--> heading(2843)`
- `range("headings 2843 to 2846") --expands_to--> heading(2844)`
- `compressed_note(commodity_1704909990) --for_declarable--> commodity(1704909990)`
- `compressed_note(commodity_1704909990) --summarises--> note_fragment(17.1)`
- `compressed_note(commodity_1704909990) --derived_from--> compression_run(...)`

## Index and access patterns

The core indexes should support:

- facts by target goods nomenclature reference
- facts by source goods nomenclature reference
- facts by relationship type
- facts by source note or source fragment
- facts by expanded range membership
- facts by validity window or tariff update context
- impacted goods nomenclatures for a changed source

Expected access patterns:

1. Resolve the goods nomenclature and its structural context through nested set.
2. Map the goods nomenclature and relevant ancestors to knowledge graph reference nodes.
3. Fetch typed edges connected to those reference nodes, including relationships reached through expanded range membership.
4. Include source origins so the caller can explain why each fact exists.
5. Optionally traverse outward for relationship types that explicitly cross the taxonomy, such as exclusions or references.

The graph should avoid unbounded recursive traversal in normal application paths. Traversal depth and relationship types should be explicit in query code.

## Why not Neptune or another graph database?

A managed graph database such as Neptune would give us native graph traversal primitives, but it would also add operational and delivery cost before we have proven that Postgres cannot handle the workload.

Postgres is the better first choice because:

- the tariff data, nested set and generated content already live in Postgres
- the expected graph is likely small relative to the goods nomenclature and measures datasets
- the primary access pattern is indexed fact lookup by goods nomenclature, not arbitrary deep traversal
- Sequel and the existing backend test setup can work with Postgres tables immediately
- transactional updates across source data, graph projection and derived content are simpler in one database
- local development, review and support remain simpler without another managed service
- we can add constraints, indexes and explain plans using tooling the team already understands

We should revisit a specialist graph database only if measured evidence shows that Postgres cannot meet the access patterns without unacceptable query complexity, latency or operational burden.

## Consequences

This gives us a durable data structure for classification facts that goes beyond the nested set without weakening the nested set's role as taxonomy source of truth.

It also means:

- we need to design typed relationship vocabulary carefully
- we need migrations and tests for graph integrity
- we need clear ownership of source projection and graph refresh jobs
- we need to keep provenance and validity in the model from the start
- we should resist adding generic graph traversal APIs until concrete access patterns require them

The first delivery should prove the model with a narrow set of source types and relationship types, then expand once the storage and refresh patterns are understood.
