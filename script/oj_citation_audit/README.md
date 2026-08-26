# EUR-Lex OJ citation audit

Generates the two data files `MeasureService::CouncilRegulationUrlGenerator`
consults before emitting an OJ-citation link:

- `lib/data/eur_lex_verified_oj_citations.txt` - citations fetched and
  verified against EUR-Lex. D-prefixed ids switch ONLY when listed here,
  because a decision can be an ordinary sector-3 act whose CELEX formula
  link works, and an unverified citation must never replace a working link.
- `lib/data/eur_lex_dead_oj_citations.txt` - citations known to be missing
  from EUR-Lex. Non-D classes (I notices, agreements, joint-committee
  decisions) have no working formula link to lose, so they default to the
  citation unless listed here.

New D documents therefore wait for an audit run before switching; new
I/A/J documents switch immediately and cannot be made worse.

## Why this exists

For pre-October-2023 documents outside CELEX sector 3 (agreements, Joint
Committee decisions, C-series notices), the only working EUR-Lex link is an
Official Journal citation (`uriserv:OJ.L_.1996.035.01.0001.01.ENG`). But
EUR-Lex's citation index has gaps: a handful of documents have a working
CELEX page and no citation page (and some old C-series notices were never
digitised at all). There is no server-side way to check - EUR-Lex
bot-challenges plain HTTP clients and the Cellar API cannot address OJ
citations - so verification requires a real (headless) browser, which is
what this harness does.

## When to re-run

Whenever newly loaded TARIC data references pre-2023 documents that are not
yet on the allowlist (they will be serving CELEX-formula links, which for
non-R ids are usually dead). Quarterly is more than enough; the candidate
population is historical and changes only when old documents are newly
referenced.

## How to run

Prerequisites: node 20+, a local tariff database with `xi` schema
(defaults: db `tariff_db`, host `localhost`, user `postgres` - override
with `AUDIT_DB_USER` / `AUDIT_DB_HOST` / `AUDIT_DB_NAME`), and Playwright
(`npm install` here; first run downloads a Chromium build).

From this directory:

```
npm install
node derive-targets.mjs      # candidate set from DB + generator predicate
node audit.mjs               # fetches every URL, ~1/sec, resumable
```

`audit.mjs` writes `audit-results.json` (PASS / SUSPECT per URL, judged by
comparing the OJ reference displayed on the landing page against the
expected series, issue, year and start page). It resumes from a partial
file if interrupted. Triage SUSPECT rows by hand before concluding
anything: check whether the old CELEX link works
(`https://publications.europa.eu/resource/celex/{celex}` with
`Accept: application/rdf+xml`; 303 = exists, 404 = absent) and whether the
page is genuinely wrong or the OJ-reference regex mis-parsed a masthead.

Then refresh `lib/data/eur_lex_verified_oj_citations.txt`: all PASS ids
plus any SUSPECT ids you triage as genuinely correct, one per line, keeping
the header comments up to date (candidate/verified counts and run date).

## Provenance

Authored during HMRC-2159 (August 2026) as the adversarial verification
harness for the OJ-citation link fix; the first run fetched all 685
candidate URLs and found 4 citation-index gaps with working CELEX links
plus 4 dead-both-ways C-series notices. Evidence from that run lives with
the ticket (HMRC-2159-switched-url-audit.csv).
