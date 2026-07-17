# Tariff knowledge notes

Tariff knowledge turns official chapter and section notes into small, source-traceable evidence that guided classification search can include in a prompt. It is evidence for classification reasoning, not a rules engine and not a replacement for the tariff hierarchy.

## Concepts

### Note sources

A note source represents the imported chapter, section, or General Interpretive Rule document for a specific customs tariff update version. The source keeps the legal text and provenance together.

### Fragments

A fragment is a small extracted piece of a source note. Fragments are the main applicability unit in the graph: a fragment can apply directly to declarable goods and can reference a chapter or heading range.

Fragments are intentionally small enough for deterministic range extraction and prompt selection. That means an individual fragment is not always a complete legal idea.

### Note blocks

A note block keeps a structured legal unit together when flat fragments would split its meaning. The current parser emits definition blocks so the defined term, thresholds, and nested conditions can reach the prompt as one piece of evidence.

A block records the fragments it contains. Blocks do **not** receive chapter-wide `applies_to` or `references` edges. Their applicability is resolved through the contained fragments, which prevents every block from multiplying across every declarable commodity in its chapter.

### Compressed notes

A compressed note is the materialised evidence context for one declarable goods nomenclature. A graph fragment or block is the canonical identity for an extracted fact, but its text is deliberately denormalised into source nodes, evidence nodes, and per-commodity compressed rows. The metadata preserves the contributing fragments, blocks, sources, ranges, versions, and relationship types.

`context_hash` is the SHA-256 hash of the compressed note content. At prompt-selection time, rows with the same hash are grouped into one context and their commodity codes are combined. This removes repeated shared content from the prompt while retaining which candidates it affects.

## Extraction and graph projection

`TariffKnowledge::SourceGraphLoader` projects current source notes into graph nodes and edges:

1. Create or update the versioned note-source node.
2. Extract note fragments and persist a `contains` edge from the source to each fragment.
3. Parse explicit chapter and heading references into range nodes.
4. Persist `references` from fragments to shared range nodes. A range node is unique by range type and code, and has one set of `expands_to` edges to matching declarable goods nomenclatures.
5. Persist `applies_to` from chapter and section fragments to declarables in the source scope, and from General Interpretive Rule fragments to every declarable.
6. Parse definition-style structured units into note-block nodes.
7. Persist `contains` from the source to each block and from each block to its member fragments.

The graph exposes two normal fragment paths to a commodity:

```text
note source --contains--> fragment --applies_to--> declarable

note source --contains--> fragment --references--> range
                                      range --expands_to--> declarable
```

The second path supplies range context; it is not independently sufficient for compressed-note eligibility. `CompressedNoteGenerator` retains range-aware evidence only when that same fragment also has an `applies_to` edge to the declarable.

A note block reaches a commodity through a contained fragment:

```text
note source --contains--> note block --contains--> fragment
                                                --applies_to--> declarable
```

## Why the graph has millions of edges

The graph stores materialised lookup relationships, not one row per piece of prose. The largest terms are:

- every fragment multiplied by the declarables in the fragment's chapter or section scope (`applies_to`)
- General Interpretive Rule fragments multiplied across all declarables (`applies_to`)
- every unique shared range multiplied by the declarables covered by that chapter or heading (`expands_to`)
- one fragment-to-range `references` edge for each unique fragment/range pair
- one source-to-fragment `contains` edge per fragment
- comparatively few source-to-block and block-to-fragment `contains` edges

Consequently, an observed production edge count around 2.39 million does not mean there are 2.39 million independently written facts. It mainly reflects deterministic materialisation that makes commodity lookups cheap. Note blocks are deliberately excluded from chapter-wide fan-out. The total changes with the tariff version, extracted sources, and declarable population.

Capture a reproducible breakdown with the environment and timestamp recorded alongside this query:

```sql
SELECT relationship_type, COUNT(*) AS edge_count
FROM tariff_knowledge_edges
GROUP BY relationship_type
ORDER BY edge_count DESC;
```

`SourceGraphLoader` currently writes `contains`, `applies_to`, `references`, and `expands_to`. The graph vocabulary also reserves `summarises`, `for_declarable`, and `derived_from` for other producers.

## Compressed-note generation

`TariffKnowledge::CompressedNoteGenerator` starts from declarable nodes and resolves:

- directly applicable fragments through `applies_to`
- range-aware fragments through `references` and `expands_to`
- note blocks through block-to-fragment `contains` plus fragment applicability
- the parent source and source version for provenance

For each requested declarable SID that has applicable evidence, it upserts one compressed-note row. If no evidence exists, it creates no row and marks any existing row stale. This is one reason prompt diagnostics can report `no_compressed_notes`. The content hash covers the generated content; provenance remains structured metadata. A content change therefore changes the hash, while identical content can be deduplicated across candidate commodities during prompt assembly.

## Prompt selection

`TariffKnowledge::RelevantNoteFragmentSelector` evaluates the evidence belonging to the retrieved commodity shortlist. It does not independently search all note text with embeddings.

The selector scores evidence using explainable signals including:

- an explicit range matching a retrieved chapter or heading
- mentions of retrieved ranges in the legal text
- meaningful query-term overlap
- BM25 lexical overlap
- a small same-chapter tie-breaker
- exact term or phrase matches and a definition-block bonus for note blocks

Evidence below the minimum score is omitted. At most two items are selected from one compressed context and at most eight are selected overall. The chosen contexts are linked back to the relevant OpenSearch candidates with prompt-local references such as `compressed_note_1`.

A synonym can still retrieve the correct commodity candidates through normal search. Once those candidates are known, their compressed-note evidence becomes eligible; lexical scoring then decides which fragments or blocks are useful for the current query. This is why an unrelated chapter can appear when the retrieved shortlist itself contains a candidate from that chapter.

## Request diagnostics

Every classifier prompt assembled by `InteractiveSearchService` emits a `note_evidence_evaluated` search event immediately before its model call. The duplicate-question validator is a separate model call and does not emit this event. The event is diagnostic-only and does not participate in selection.

The event records:

- request ID, query, effective query, search iteration, attempt number, and model-call operation
- whether note evidence was `disabled`, `no_compressed_notes`, `no_eligible_evidence`, or `selected`
- considered, selected, omitted, and truncated counts
- the active minimum score and per-note/total caps
- selected context hashes, prompt-local note references, and affected commodity codes
- the exact bounded evidence text included in the prompt
- source keys, types, IDs, versions, ranges, block membership, scores, and score reasons
- graph relationship paths that made the evidence applicable
- a bounded list of omitted evidence with reasons such as `below_minimum_score`, `per_note_limit`, `total_evidence_limit`, `duplicate_same_score`, or `duplicate_lower_score`

The admin endpoint retrieves all search events sharing a request ID:

```text
GET /uk/admin/search_diagnostics/:request_id.json
GET /xi/admin/search_diagnostics/:request_id.json
```

`SearchDiagnostics::RequestLogLookup` searches the environment's `platform-logs-*` CloudWatch log group for search events and the request-correlated vector-embedding usage event. It parses the structured JSON message, preserves the nested `details` object, and returns token and cost fields so the admin application can show the journey's AI usage. The default lookback is 72 hours; callers can request 1–168 hours and 1–500 results.

When investigating a journey, read the events in timestamp order and match `note_evidence_evaluated.iteration`, `attempt_number`, and `operation` with the retrieval, question, answer, and API-call events. This distinguishes the normal prompt, final-answer prompt, and duplicate-question retry even when they occur in the same iteration. The selected evidence is what reached that model prompt; omitted evidence explains what was considered but did not reach it.

## Key implementation paths

- `app/services/tariff_knowledge/source_graph_loader.rb`
- `app/services/tariff_knowledge/compressed_note_generator.rb`
- `app/services/tariff_knowledge/relevant_note_fragment_selector.rb`
- `app/services/interactive_search_service.rb`
- `app/lib/search/instrumentation/note_evidence_events.rb`
- `app/lib/search/logger.rb`
- `app/services/search_diagnostics/request_log_lookup.rb`
- `app/controllers/api/admin/search_diagnostics_controller.rb`
