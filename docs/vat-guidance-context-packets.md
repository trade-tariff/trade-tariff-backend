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
