# VAT guidance context packets

The context packet assembler creates one reference-expanded packet for every section of VAT Notices 701/23, 701/14, and 709/1. Each packet keeps the source document and section anchors, readable section text, direct reference provenance, pulled-in referenced text, and unresolved-reference findings.

## Traversal finding

Packets follow one reference hop. A resolved section reference adds that section; a resolved whole-document reference adds every anchored section in that document. References found inside pulled-in text are not followed again.

This policy captures everything the source section explicitly references while bounding packet size and keeping provenance understandable. Recursive traversal would add more context, but frequently drifts into operational, complaints, privacy, and general VAT material that is not specific to the source section. The artifact records the policy so a later evaluation can compare or replace it.

## Comparison case

The artifact retains two versions of section 1.1, “Information in this notice,” from VAT Notice 709/1:

- `local_only` contains only section 1.1;
- `reference_expanded` also contains all anchored sections of VAT Notice 701/14, which section 1.1 explicitly references.

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
