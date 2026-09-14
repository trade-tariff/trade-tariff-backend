# VAT guidance context packets

The context packet assembler creates one reference-expanded packet for every section of VAT Notices 701/23, 701/14, and 709/1. It also creates commodity packets for the three curated Chapter 20 prepared-food examples and the three Chapter 84 aviation-and-machinery examples in the context graph. Each packet keeps source identity and anchors, readable structured text, direct reference provenance, pulled-in referenced text, omissions, and unresolved-reference findings.

## Traversal finding

Packets follow one reference hop. A resolved section reference adds that section; a resolved whole-document reference considers every anchored section in that document. Commodity packets include their directly mapped guidance-evidence sections, including anchored descendants when a mapped parent section has no body. References found inside pulled-in text are not followed again.

Each packet has an 80,000-character content budget. The source is always retained; referenced nodes are considered in deterministic order, and anything that does not fit is recorded in `omissions` and the corresponding reference's `omitted_node_ids`. Resolved targets without captured section content are reported as unresolved findings rather than silently treated as complete. This policy bounds LLM input while keeping provenance auditable. Recursive traversal would add more context, but frequently drifts into operational, complaints, privacy, and general VAT material that is not specific to the source section.

Tables and lists are rendered as Markdown so VAT classifications and their row or item relationships survive conversion from GOV.UK HTML.

## Comparison case

The artifact retains two versions of section 1.1, “Information in this notice,” from VAT Notice 709/1:

- `local_only` contains only section 1.1;
- `reference_expanded` considers the anchored sections of VAT Notice 701/14 that section 1.1 explicitly references, subject to the recorded content budget.

This provides the local-versus-cross-notice input required by the next spike task.

## Human assessment finding

The graph knows where evidence came from, but it does not contain criteria for deciding whether the assembled evidence is sufficient, ambiguous, contradictory, or suitable for generating VAT questions. Those are review-policy decisions rather than graph relationships.

Human-assessment criteria should therefore live in a versioned review or question-set policy artifact and reference the same guide and section keys used by these packets. Keeping the criteria outside the packet assembler avoids silently turning traversal mechanics into tax-policy judgements while retaining an auditable link back to the evidence.

## Generate the artifact

After generating `data/vat_guidance/context_graph.json`, run:

```sh
bundle exec rake vat_guidance:context_packets
```

Set `VAT_GUIDANCE_GRAPH_PATH` or `VAT_GUIDANCE_PACKETS_PATH` to override the default input and output paths.

## Generate and validate question journeys

AI-1145 adds generated question-tree candidates for the three target notices and the six curated commodity packets in Chapters 20 and 84. The artifact is deliberately a spike input, not approved tax logic: every journey still requires human review of whether each located quote genuinely supports its question and outcome.

The explicit generation sweep makes one logical model call for every unique notice, commodity, and catering-comparison packet. `OpenaiClient` may make up to three HTTP attempts for each logical call when a retryable provider or transport failure occurs. The sweep requires both an AI-cost acknowledgement and a separate output path, so it cannot silently overwrite the reviewed candidates:

```sh
CONFIRM_AI_COST=true \
VAT_GUIDANCE_GENERATION_OUTPUT_PATH=/tmp/question-journey-generation.json \
bundle exec rake vat_guidance:generate_question_journey_candidates
```

`VAT_GUIDANCE_GENERATION_MODEL` and `VAT_GUIDANCE_REASONING_EFFORT` may override the defaults. The raw output uses generation mode `llm_generation_sweep` and marks each hash-bound attempt with `method: llm_generation`, distinguishing calls actually made by this task from later human review dispositions. Successful attempts also bind the normalized journey with `model_response_sha256`. Packet-specific invalid JSON or contract failures remain `generation_failed`; they must be reviewed and explicitly dispositioned before the file can pass the artifact builder. Provider, configuration, authentication, rate-limit, deadline, and transport errors abort the sweep immediately without writing a partial output file. This prevents a systemic outage from triggering calls for every remaining packet and prevents missing attempts from being presented as successful coverage.

Run the deterministic contract validator and rebuild the report with:

```sh
bundle exec rake vat_guidance:question_journeys
```

The task is database-independent. It validates every candidate before atomically replacing `data/vat_guidance/question_journeys.json` and exits unsuccessfully without overwriting the last valid artifact if any journey fails. It can be pointed at alternate files with `VAT_GUIDANCE_PACKETS_PATH`, `VAT_GUIDANCE_JOURNEY_CANDIDATES_PATH`, and `VAT_GUIDANCE_JOURNEYS_PATH`.

The contract enforces:

- only `standard`, `reduced`, `zero`, and `exempt` trader-facing outcomes;
- closed generated-data shapes, questions, transitions, reachability, cycle freedom, and bounded graph size;
- hidden internal fall-through for rules that cannot decide a case, bound to an AI-1146 composition boundary;
- standard-by-default only after every declared relief rule on the path has explicitly declined;
- verbatim quotes located in declared packet nodes for every question, outcome, and exclusion;
- notice, chapter, commodity, and catering-comparison identity bound to the source packet rather than trusted candidate labels;
- treatments rather than stored rates, with VATZ, VATR, and VATE kept distinct;
- explicit spike findings for mixed-treatment, apportionment, assessment, and ambiguous cases.

The catering comparison uses the local-only and reference-expanded versions of the same 709/1 packet. The expanded packet makes the referenced 701/14 food-exception question possible; the local packet can only decide the catering branch and must fall through internally for non-catering supplies.

The committed candidates are the result of AI-assisted human review, not the output of the paid sweep. They contain 148 hash-bound `packet_review_records`: 141 notice sections, six commodity packets, and the distinct local-only catering packet (the reference-expanded catering packet is one of the 141). Eleven records use `journey_curated`; the other 137 use `no_contract_safe_tree_identified` with a packet-specific finding. They deliberately contain no model-response hashes and do not claim that an LLM call was made for every packet.

The raw sweep writes `packet_generation_attempts`. A fully successful sweep can be passed directly to the artifact builder, which verifies each `journey_generated` record against the normalized journey's response hash. A `generation_failed` record must first be reviewed and converted into an explicit `packet_review_records` disposition; the builder rejects failures and rejects files containing both envelopes. The builder also recomputes packet hashes and rejects missing or duplicate records, invented journey IDs, and status/finding mismatches. If acceptance requires a live LLM call for every packet, the cost-confirmed sweep above must be run and its output retained; the committed reviewed artifact is not evidence that this paid run occurred.

All committed outcomes currently use explicit guidance. Individual packet rules decline through the hidden module boundary; they do not invent a standard default from an incomplete notice-wide relief set. The AI-1146 composer must resolve those boundaries and may emit an exhaustive standard default only after it proves that the full applicable relief set was traversed and every relief answer declined.

The Chapter 84 journeys separately ask the airline, passenger-or-freight use, state-institution, 8,000kg maximum-take-off-weight, and recreation-or-pleasure conditions. The Chapter 20 journeys cover potato crisps, sweetened dried cranberries, and prepared fruit/plant mixtures. These remain unapproved, human-review-required spike artifacts and are not loaded by any production route, controller, database model, or decision service.

## Build the AI-1146 HMRC proof of concept

AI-1146 turns the validated AI-1145 journeys into a browsable, offline spike artifact. It enumerates every reachable answer path rather than reviewing shared outcomes once, records standard and composition-gate dispositions, and creates provisional VATZ/VATR/VATE connection candidates only from rule journeys. Commodity journeys and the catering comparison remain evidence prototypes; they do not originate measure connections.

```sh
bundle exec rake vat_guidance:hmrc_poc
```

Then open `data/vat_guidance/hmrc_poc.html` in a browser.

Use `VAT_GUIDANCE_JOURNEYS_PATH`, `VAT_GUIDANCE_HMRC_POC_PATH`, and `VAT_GUIDANCE_HMRC_POC_HTML_PATH` to write isolated test outputs. The source journey hash is carried into every stable path subject, so upstream changes invalidate the review identity rather than silently inheriting an old decision.

The pinned tariff evidence is reproducible from the public UK Trade Tariff API. A refresh deliberately requires a fixed review timestamp, independently captures each measure-origin response and each scoped commodity response, and refuses to write when the live non-standard VAT inventory differs from the reviewed measure set:

```sh
VAT_GUIDANCE_TARIFF_RETRIEVED_AT=2026-08-20T12:00:00Z \
  bundle exec rake vat_guidance:hmrc_poc_tariff_snapshot
```

The PoC is deliberately fail-closed:

- it remains `runtime_approved: false` and is not served by a Rails route;
- real rule-connection and quote-support reviews remain pending and visible;
- a separate `synthetic_spike_fixture` records hash-bound positive decisions for all 53 paths, four exclusions and the pinned measure proposal, solely to exercise downstream contracts;
- production-mode composition rejects that synthetic fixture and requires `authorised_human_review` decisions;
- changing a reviewed path, proposal, evidence record or decision invalidates its hash and blocks composition;
- commodity exhaustion notes never permit standard-by-default while applicable measures or approvals are incomplete;
- the 6506101000 safety-headgear signpost pins one real UK tariff snapshot: VATZ measure `-1012552782`, inherited from `6506100000` by declarable commodities `6506101000` and `6506108000`;
- the pinned snapshot records complete inherited cohorts for the Chapter 20 measures rooted at headings `2005` and `2008`, the direct/inherited Chapter 84 aviation and machinery measures, protective headgear, and the reduced-rate child-seat measure;
- its closed schema validates VAT measure type `305`, effective dates, additional-code values, ten-digit declarable codes, allowlisted source URLs, response hashes, cohort uniqueness and an independently captured per-commodity VAT inventory;
- 12 exact path×measure proposals cover protective equipment, child car seats, food exceptions and the aviation rule families. Every relief route uses only proposals approved for that exact rule path; treatment-only delegation is forbidden;
- curated Chapter 20 and Chapter 84 guidance-rule extractions have new hash-bound rule identities, explicit source lineage and reviewed applicability scopes. The original per-commodity source journeys remain validation evidence and never become connection subjects;
- the synthetic simulation composes 11 scoped commodities, including every inherited Chapter 84 descendant and the child-seat case;
- fallthrough recursively enters the next rule in the declared order. A composed route reaches standard-by-exhaustion only when that same route reaches the end of the complete ordered relief set;
- each exhaustion note compares proposals against the separately captured commodity VAT inventory, rather than deriving both sides of the check from the proposal list;
- that signpost remains a pending real path-to-measure proposal with an explicit wrong-relief challenge, not an approved mapping or a claim that tariff availability proves eligibility;
- all trader-facing copy says the service guides from the trader's answers and presents candidate treatments for review; it does not determine VAT liability.

This is an incremental spike demonstrator for the graph → packet → rule → answer-path → approval → measure inventory → sequential commodity-composition workflow. It reports `end_to_end_simulation_ready: true` across the three notices, Chapter 20 prepared food, Chapter 84 aviation/machinery, child car seats, and the safety-headgear signpost. It deliberately keeps `hmrc_demo_ready: false`: all real pairing and quote-support approvals remain pending. It must not be connected to a production journey without replacing the synthetic fixture with authorised reviews and rebuilding against current pinned tariff responses.

For the cross-application browser demo, `GET /uk/api/v2/vat_guidance_demo` exposes a read-only projection of the hash-validated artifact. The frontend consumes the composed journey for the commodity already selected in the duty calculator and offers its questions from the existing VAT-rate step; it does not expose a standalone journey chooser. The endpoint associates the two complete VAT Notice 701/14 food-exception paths and the three complete paths from the reference-expanded VAT Notice 709/1 catering comparison with the three curated Chapter 20 commodities, allowing the VAT step to offer those evidence-only choices only where relevant. They remain pending domain review and cannot present an additional code or tariff-measure connection. The endpoint is available automatically in development and test, and in a deployed demo only when `VAT_GUIDANCE_DEMO_ENABLED=true`. It fails closed unless the artifact remains simulation-ready, runtime-unapproved, production-unready and contains no production-eligible commodity journey.
