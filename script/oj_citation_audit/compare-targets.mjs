import { readFileSync, writeFileSync } from 'node:fs';

const suppliedPath = process.argv[2];
if (!suppliedPath) {
  console.error('usage: node compare-targets.mjs <other-targets.json>');
  process.exit(1);
}
const supplied = JSON.parse(readFileSync(suppliedPath, 'utf8'));
const derived = JSON.parse(readFileSync(new URL('./derived-targets.json', import.meta.url), 'utf8'));
const prefix = 'https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=uriserv%3A';

const suppliedByUrl = new Map(supplied.map((target) => [
  `${prefix}${target.url}`,
  {
    url: `${prefix}${target.url}`,
    rids: target.rids.split(',').sort(),
    expected: {
      series: target.series,
      number: Number.parseInt(target.number, 10),
      year: Number.parseInt(target.year, 10),
      page: Number.parseInt(target.page, 10),
    },
  },
]));
const derivedByUrl = new Map(derived.targets.map((target) => [target.url, target]));

const onlyDerived = [...derivedByUrl.keys()].filter((url) => !suppliedByUrl.has(url));
const onlySupplied = [...suppliedByUrl.keys()].filter((url) => !derivedByUrl.has(url));
const mismatched = [];

for (const [url, derivedTarget] of derivedByUrl) {
  const suppliedTarget = suppliedByUrl.get(url);
  if (!suppliedTarget) continue;

  const derivedRids = [...derivedTarget.rids].sort();
  if (JSON.stringify(derivedRids) !== JSON.stringify(suppliedTarget.rids)
      || JSON.stringify(derivedTarget.expected) !== JSON.stringify(suppliedTarget.expected)) {
    mismatched.push({ url, derived: { rids: derivedRids, expected: derivedTarget.expected }, supplied: suppliedTarget });
  }
}

const comparison = {
  counts: {
    derived_urls: derivedByUrl.size,
    supplied_urls: suppliedByUrl.size,
    only_derived: onlyDerived.length,
    only_supplied: onlySupplied.length,
    mismatched_shared_records: mismatched.length,
  },
  only_derived: onlyDerived.sort(),
  only_supplied: onlySupplied.sort(),
  mismatched_shared_records: mismatched.sort((left, right) => left.url.localeCompare(right.url)),
};

writeFileSync(new URL('./target-comparison.json', import.meta.url), `${JSON.stringify(comparison, null, 2)}\n`);
process.stdout.write(`${JSON.stringify(comparison.counts)}\n`);
