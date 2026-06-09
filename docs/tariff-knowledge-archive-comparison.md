# Tariff Knowledge Archive Comparison

Use `script/tariff_knowledge_archive_compare` to compare the Rails spike output with the archived third-party KG dump.

See `docs/tariff-knowledge-ba-alignment-decision.md` for the implementation decision that follows from this comparison.

The script uses Ruby standard libraries, `psql`, `createdb`, `unzip`, and `gzip`. It does not require the Rails bundle unless you need to regenerate spike tables with the rake task.

The archive contains more than the tariff-note spike output: ATAR rationales, HS explanatory note material, fact-store rows, and tariff note rows. The reproducible comparison therefore separates archive totals from the comparable subset:

- `UK Tariff Chapter % Notes`
- `UK Tariff Section % Notes`
- `Combined Nomenclature / Tariff of the United Kingdom Part Two%`

## Restore The Archive

If the archive has not already been restored, the script can restore it into a temporary PostgreSQL database:

```sh
ARCHIVE_ZIP=~/Downloads/ai-fan-out-third-party-20260604.zip \
  script/tariff_knowledge_archive_compare
```

To reuse an existing restored archive database:

```sh
ARCHIVE_DB=ai868_kg_archive_20260609094134 \
  script/tariff_knowledge_archive_compare
```

The spike/backend side defaults to `SPIKE_DB=tariff_development` and `SERVICE=uk`. Override them if needed:

```sh
ARCHIVE_DB=ai868_kg_archive_20260609094134 \
SPIKE_DB=tariff_development \
SERVICE=uk \
OUT_DIR=/tmp/ai868_kg_compare/reproducible-compare \
  script/tariff_knowledge_archive_compare
```

If the spike tables are empty, generate them first from the spike branch:

```sh
bundle exec rake tariff_knowledge:refresh
```

## Outputs

Each run writes a timestamped directory under `/tmp/ai868_kg_compare/` unless `OUT_DIR` or `--out` is supplied.

- `summary.md`: counts, filters, type counts, and normalized signature match summary
- `archive_totals.csv`: total restored archive table counts
- `archive_node_like_counts.csv`: archive edge IDs and commodity-code sets that behave like graph nodes
- `archive_comparable_edges.csv`: normalized archive tariff-note/GIR edge rows
- `archive_comparable_links.csv`: archive comparable edge-to-commodity links
- `spike_node_counts.csv`: Rails spike node counts by `node_type`
- `spike_rules.csv`: Rails spike note rule rows
- `spike_applies_to_links.csv`: Rails spike rule-to-declarable links
- `scope_code_coverage.csv`: scope-level archive/spike linked-code overlap
- `source_scope_coverage.csv`: source/scope presence, row deltas, and linked-code deltas
- `signature_gaps.csv`: strict normalized body/type/scope gaps

## Current Run

Latest verified run:

```sh
ARCHIVE_DB=$(cat /tmp/ai868_kg_compare/archive_db_name) \
  script/tariff_knowledge_archive_compare \
  --out /tmp/ai868_kg_compare/clean-worktree-compare-20260609T090537Z
```

Observed counts:

| Dataset | Rule/edge rows | Linked commodity-code rows | Distinct scopes |
| --- | ---: | ---: | ---: |
| Archive comparable subset | 600 | 995 | 76 |
| Spike generated graph | 433 | 300822 | 94 |

Node-like coverage:

The archive does not contain a Rails-style graph node table. The closest equivalents are KG edge IDs plus commodity codes linked through KG/facet/search tables.

| Archive node-like set | Rows |
| --- | ---: |
| `commodity_facet_codes` | 5,222 |
| `comparable_edge_linked_commodity_codes` | 611 |
| `comparable_kg_edge_ids` | 600 |
| `composite_search_text_codes` | 22,099 |
| `total_edge_linked_commodity_codes` | 22,072 |
| `total_kg_edge_ids` | 2,080 |

| Spike node set | Rows | Distinct goods nomenclature codes |
| --- | ---: | ---: |
| `goods_nomenclature` | 16,608 | 16,608 |
| `note_source` | 94 | 0 |
| `rule` | 433 | 0 |
| `applies_to_linked_goods_nomenclature_codes` | 16,498 | 16,498 |

Strict normalized signature comparison:

| Metric | Count |
| --- | ---: |
| Matching signatures | 35 |
| Archive-only signatures | 547 |
| Spike-only signatures | 398 |

Source/scope coverage:

| Metric | Count |
| --- | ---: |
| Scopes present in both | 67 |
| Archive-only scopes | 9 |
| Spike-only scopes | 27 |

Important differences from the current run:

- Archive has `global` GIR edges; the Rails spike currently only ingests chapter and section notes.
- Archive has tariff-note edges for chapters `33`, `52`, `53`, `75`, `76`, `78`, `79`, and `80` where the local spike output has no corresponding source rules.
- Spike has current approved notes for 27 scopes where the archive comparable subset has no tariff-note edges, including chapters `02`, `04`, `11`, `12`, `15`, `20`, `22`, `27`, `28`, `29`, `38`, `39`, `40`, `48`, `59`, `61`, `62`, `71`, `72`, `84`, `85`, `90`, `95`, `96`, and sections `11`, `15`, `16`.
- The large linked-code difference is from the current spike approach: it expands rules to all declarables in the source scope and referenced ranges, while the archive links are much narrower curated KG edge commodities. The largest current deltas are section `17` (`27` archive linked codes vs `5255` spike linked codes), section `7` (`3` vs `3753`), chapter `94` (`30` vs `3551`), and chapter `44` (`34` vs `3460`).
- The archive zip ships the `kg` schema, data dump, viewer, and retrieval endpoints. I did not find the original KG generation code in the archive, so the restored DB contents are the authoritative BA output for this comparison.
