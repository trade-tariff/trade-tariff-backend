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
