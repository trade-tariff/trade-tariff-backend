import { execFileSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';

const auditDate = '2026-08-10';
const cutoffDate = '2023-10-01';
const eurLexBase = 'https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=';

const sql = `
BEGIN READ ONLY;
COPY (
  WITH regulations AS (
    SELECT
      base_regulation_id AS rid,
      base_regulation_role AS role,
      published_date,
      officialjournal_number,
      officialjournal_page,
      'base' AS kind
    FROM xi.base_regulations
    WHERE approved_flag IS TRUE

    UNION ALL

    SELECT
      modification_regulation_id AS rid,
      modification_regulation_role AS role,
      published_date,
      officialjournal_number,
      officialjournal_page,
      'modification' AS kind
    FROM xi.modification_regulations
    WHERE approved_flag IS TRUE
  )
  SELECT DISTINCT
    regulations.rid,
    regulations.role,
    regulations.kind,
    regulations.published_date,
    regulations.officialjournal_number,
    regulations.officialjournal_page
  FROM xi.measures
  JOIN regulations
    ON regulations.rid = measures.measure_generating_regulation_id
   AND regulations.role = measures.measure_generating_regulation_role
  WHERE measures.validity_start_date <= DATE '${auditDate}'
    AND (measures.validity_end_date IS NULL OR measures.validity_end_date >= DATE '${auditDate}')
  ORDER BY regulations.rid, regulations.role, regulations.kind
) TO STDOUT WITH (FORMAT csv, HEADER true);
ROLLBACK;
`;

const csv = execFileSync(
  'psql',
  ['-X', '-v', 'ON_ERROR_STOP=1', '-U', process.env.AUDIT_DB_USER ?? 'postgres', '-h', process.env.AUDIT_DB_HOST ?? 'localhost', '-d', process.env.AUDIT_DB_NAME ?? 'tariff_db', '-q', '-c', sql],
  {
    encoding: 'utf8',
    env: {
      ...process.env,
      PGOPTIONS: '-c default_transaction_read_only=on',
    },
    maxBuffer: 20 * 1024 * 1024,
  },
);

function parseCsvLine(line) {
  const fields = [];
  let field = '';
  let quoted = false;

  for (let index = 0; index < line.length; index += 1) {
    const character = line[index];
    if (character === '"') {
      if (quoted && line[index + 1] === '"') {
        field += '"';
        index += 1;
      } else {
        quoted = !quoted;
      }
    } else if (character === ',' && !quoted) {
      fields.push(field);
      field = '';
    } else {
      field += character;
    }
  }
  fields.push(field);
  return fields;
}

const lines = csv.trim().split('\n');
const headers = parseCsvLine(lines.shift());
const candidates = lines.map((line) => Object.fromEntries(
  parseCsvLine(line).map((value, index) => [headers[index], value]),
));

function ojReference(regulation) {
  if (regulation.rid.startsWith('R')) return null;

  const match = regulation.officialjournal_number.trim().match(/^([LC])\s*(\d+)$/);
  if (!match) return null;

  const page = Number.parseInt(regulation.officialjournal_page, 10) || 0;
  if (page <= 0) return null;

  const publishedDate = regulation.published_date;
  if (!publishedDate || publishedDate >= cutoffDate) return null;

  const series = match[1];
  const number = Number.parseInt(match[2], 10);
  const year = Number.parseInt(publishedDate.slice(0, 4), 10);
  const citation = `OJ.${series}_.${year}.${String(number).padStart(3, '0')}.01.${String(page).padStart(4, '0')}.01.ENG`;

  return {
    url: `${eurLexBase}uriserv%3A${citation}`,
    series,
    number,
    year,
    page,
  };
}

const switchedObjects = candidates.flatMap((candidate) => {
  const reference = ojReference(candidate);
  if (!reference) return [];
  return [{
    rid: candidate.rid,
    role: Number.parseInt(candidate.role, 10),
    kind: candidate.kind,
    published_date: candidate.published_date,
    officialjournal_number: candidate.officialjournal_number,
    officialjournal_page: Number.parseInt(candidate.officialjournal_page, 10),
    ...reference,
  }];
});

const byUrl = new Map();
for (const object of switchedObjects) {
  const existing = byUrl.get(object.url) ?? {
    url: object.url,
    rids: [],
    objects: [],
    expected: {
      series: object.series,
      number: object.number,
      year: object.year,
      page: object.page,
    },
  };
  existing.rids.push(object.rid);
  existing.objects.push({ rid: object.rid, role: object.role, kind: object.kind });
  byUrl.set(object.url, existing);
}

const targets = [...byUrl.values()]
  .map((target) => ({
    ...target,
    rids: [...new Set(target.rids)].sort(),
    objects: target.objects.sort((left, right) =>
      left.rid.localeCompare(right.rid) || left.role - right.role || left.kind.localeCompare(right.kind)),
  }))
  .sort((left, right) => left.url.localeCompare(right.url));

const output = {
  provenance: {
    branch: 'HMRC-2159-legal-base-links-sector2',
    commit: execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim(),
    database: 'tariff_db',
    schema: 'xi',
    role: process.env.AUDIT_DB_USER ?? 'postgres',
    audit_date: auditDate,
    cutoff_date: cutoffDate,
  },
  counts: {
    candidate_objects: candidates.length,
    switched_objects: switchedObjects.length,
    distinct_rids: new Set(switchedObjects.map(({ rid }) => rid)).size,
    distinct_urls: targets.length,
  },
  switched_objects: switchedObjects,
  targets,
};

writeFileSync(new URL('./derived-targets.json', import.meta.url), `${JSON.stringify(output, null, 2)}\n`);
process.stdout.write(`${JSON.stringify(output.counts)}\n`);
