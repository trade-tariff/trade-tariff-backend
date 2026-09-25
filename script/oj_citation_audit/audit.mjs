import { chromium } from 'playwright';
import { createHash } from 'node:crypto';
import { existsSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

// Playwright resolves its own installed browser; set AUDIT_CHROMIUM_PATH to override.
const executablePath = process.env.AUDIT_CHROMIUM_PATH || undefined;
const defaultOutput = new URL('./audit-results.json', import.meta.url);
const targetsText = readFileSync(new URL('./derived-targets.json', import.meta.url), 'utf8');
const targetsSha256 = createHash('sha256').update(targetsText).digest('hex');
const targetsDocument = JSON.parse(targetsText);

const option = (name) => process.argv.find((argument) => argument.startsWith(`--${name}=`))?.split('=').slice(1).join('=');
const limit = Number.parseInt(option('limit') ?? '', 10) || null;
const outputUrl = option('output') ? new URL(`file://${resolve(option('output'))}`) : defaultOutput;
const baseDelayMs = Number.parseInt(option('delay-ms') ?? '1000', 10);
const retryDelayMs = Number.parseInt(option('retry-delay-ms') ?? '30000', 10);
const navigationTimeoutMs = Number.parseInt(option('navigation-timeout-ms') ?? '60000', 10);
const settleTimeoutMs = Number.parseInt(option('settle-timeout-ms') ?? '20000', 10);

function ascii(value) {
  return String(value ?? '')
    .replace(/[\u2010-\u2015\u2212]/g, '-')
    .replace(/[\u2018\u2019]/g, "'")
    .replace(/[\u201c\u201d]/g, '"')
    .replace(/\u00a0/g, ' ')
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^\x20-\x7e]/g, '?');
}

function sleep(milliseconds) {
  return new Promise((resolvePromise) => setTimeout(resolvePromise, milliseconds));
}

function saveAudit(audit) {
  const temporaryUrl = new URL(`${outputUrl.href}.tmp`);
  writeFileSync(temporaryUrl, `${JSON.stringify(audit, null, 2)}\n`);
  renameSync(temporaryUrl, outputUrl);
}

function loadAudit() {
  if (existsSync(outputUrl)) {
    const existing = JSON.parse(readFileSync(outputUrl, 'utf8'));
    if (existing.provenance?.derived_targets_sha256 !== targetsSha256) {
      throw new Error(`Existing output ${outputUrl.pathname} belongs to a different target derivation`);
    }
    existing.stopped = null;
    existing.completed_at = null;
    return existing;
  }

  return {
    provenance: {
      branch: targetsDocument.provenance.branch,
      commit: targetsDocument.provenance.commit,
      audit_date: targetsDocument.provenance.audit_date,
      derived_targets_sha256: targetsSha256,
      browser: 'Playwright 1.62.1, Chromium headless shell 149.0.7827.55 (revision 1228)',
    },
    settings: {
      base_delay_ms: baseDelayMs,
      retry_delay_ms: retryDelayMs,
      navigation_timeout_ms: navigationTimeoutMs,
      settle_timeout_ms: settleTimeoutMs,
      sequential: true,
      browser_contexts: 1,
    },
    started_at: new Date().toISOString(),
    completed_at: null,
    stopped: null,
    results: [],
  };
}

function extractLandedCelex(title, bodyCelex) {
  const titleMatch = title.match(/EUR-Lex\s*-\s*([0-9][0-9A-Z()_./-]*)\s*-\s*EN\b/i);
  return ascii(titleMatch?.[1] ?? bodyCelex ?? '');
}

function judge(target, evidence) {
  if (evidence.fetch_error && evidence.oj_references.length === 0) {
    return { outcome: 'SUSPECT', reason: 'fetch error' };
  }
  if (evidence.document_does_not_exist) {
    return { outcome: 'SUSPECT', reason: 'document-does-not-exist' };
  }
  if (evidence.challenge_or_rate_limit) {
    return { outcome: 'SUSPECT', reason: 'rate-limit-or-challenge' };
  }
  if (evidence.oj_references.length === 0) {
    return { outcome: 'SUSPECT', reason: 'no OJ ref found' };
  }

  const matchingIssue = evidence.oj_references.filter((reference) =>
    reference.series === target.expected.series
      && reference.number === target.expected.number
      && reference.year === target.expected.year);
  if (matchingIssue.length === 0) {
    return { outcome: 'SUSPECT', reason: 'wrong issue' };
  }

  const matchingReference = matchingIssue.find((reference) => reference.first_page === target.expected.page);
  if (!matchingReference) {
    return { outcome: 'SUSPECT', reason: 'wrong page' };
  }

  return { outcome: 'PASS', reason: null, matched_oj_ref: matchingReference.text };
}

async function settleRenderedPage(page, lastDocumentResponseAt) {
  const deadline = Date.now() + settleTimeoutMs;
  let previousFingerprint = null;
  let stableSamples = 0;

  while (Date.now() < deadline) {
    await page.waitForTimeout(500);
    try {
      const state = await page.evaluate(() => {
        const body = document.body?.innerText ?? '';
        const title = document.title ?? '';
        const challenge = /just a moment|checking your browser|verify you are human|captcha|access denied|too many requests|rate limit|automated quer(?:y|ies)|enable javascript.*ad blocker/i.test(`${title}\n${body}`);
        return {
          ready: document.readyState !== 'loading',
          challenge,
          fingerprint: `${location.href}|${title}|${body.length}`,
          bodyLength: body.length,
        };
      });

      const responseQuiet = Date.now() - lastDocumentResponseAt.value >= 500;
      if (state.ready && state.bodyLength > 200 && !state.challenge && responseQuiet) {
        stableSamples = state.fingerprint === previousFingerprint ? stableSamples + 1 : 0;
        previousFingerprint = state.fingerprint;
        if (stableSamples >= 1) return;
      } else {
        previousFingerprint = state.fingerprint;
        stableSamples = 0;
      }
    } catch (error) {
      if (!/Execution context was destroyed|Cannot find context|Target page, context or browser has been closed/.test(error.message)) {
        throw error;
      }
      stableSamples = 0;
      previousFingerprint = null;
    }
  }
}

async function extractEvidence(page) {
  const evidence = await page.evaluate(() => {
    const body = document.body?.innerText ?? '';
    const title = document.title ?? '';
    const referencePattern = /\bOJ\s+([LC])\s+(\d+)(?:\s+[A-Z])?,\s*(\d{1,2})\.(\d{1,2})\.(\d{4}),\s*pp?\.\s*(\d+)(?:\s*[\u2010-\u2015\-]\s*(\d+))?/giu;
    const references = [];
    const seen = new Set();

    for (const match of body.matchAll(referencePattern)) {
      if (seen.has(match[0])) continue;
      seen.add(match[0]);
      references.push({
        text: match[0],
        series: match[1].toUpperCase(),
        number: Number.parseInt(match[2], 10),
        year: Number.parseInt(match[5], 10),
        first_page: Number.parseInt(match[6], 10),
        last_page: match[7] ? Number.parseInt(match[7], 10) : null,
      });
    }

    const bodyCelexMatch = body.match(/\bCELEX\s+(?:number\s*)?:?\s*([0-9][0-9A-Z()_./-]*)/i);
    return {
      title,
      body_length: body.length,
      body_celex: bodyCelexMatch?.[1] ?? null,
      document_does_not_exist: /(?:the\s+)?requested document does not exist|the document requested does not exist/i.test(body),
      challenge_or_rate_limit: /just a moment|checking your browser|verify you are human|captcha|access denied|too many requests|rate limit|automated quer(?:y|ies)|enable javascript.*ad blocker/i.test(`${title}\n${body}`),
      oj_references: references,
    };
  });

  return {
    ...evidence,
    title: ascii(evidence.title),
    landed_celex: extractLandedCelex(evidence.title, evidence.body_celex),
    oj_references: evidence.oj_references.map((reference) => ({ ...reference, text: ascii(reference.text) })),
  };
}

async function fetchTarget(page, target, attemptNumber) {
  const documentResponses = [];
  const lastDocumentResponseAt = { value: 0 };
  let navigationError = null;
  const startedAt = Date.now();

  const onResponse = (response) => {
    try {
      const request = response.request();
      if (request.resourceType() === 'document' && request.frame() === page.mainFrame()) {
        documentResponses.push({ status: response.status(), url: ascii(response.url()) });
        lastDocumentResponseAt.value = Date.now();
      }
    } catch {
      // A detached redirect frame cannot be the final landed document.
    }
  };
  page.on('response', onResponse);

  try {
    await page.goto(target.url, { waitUntil: 'domcontentloaded', timeout: navigationTimeoutMs });
  } catch (error) {
    navigationError = ascii(error.message);
  }

  let renderedEvidence;
  try {
    await settleRenderedPage(page, lastDocumentResponseAt);
    renderedEvidence = await extractEvidence(page);
  } catch (error) {
    renderedEvidence = {
      title: '',
      landed_celex: '',
      body_length: 0,
      body_celex: null,
      document_does_not_exist: false,
      challenge_or_rate_limit: false,
      oj_references: [],
    };
    navigationError = navigationError ?? ascii(error.message);
  } finally {
    page.off('response', onResponse);
  }

  const lastStatus = documentResponses.at(-1)?.status ?? null;
  const rateStatus = [403, 429, 503].includes(lastStatus);
  const evidence = {
    attempt: attemptNumber,
    requested_url: target.url,
    final_url: ascii(page.url()),
    http_status: lastStatus,
    document_responses: documentResponses,
    fetch_error: navigationError,
    elapsed_ms: Date.now() - startedAt,
    ...renderedEvidence,
    challenge_or_rate_limit: renderedEvidence.challenge_or_rate_limit || rateStatus,
  };
  return { ...evidence, ...judge(target, evidence) };
}

const allTargets = limit ? targetsDocument.targets.slice(0, limit) : targetsDocument.targets;
const audit = loadAudit();
const completedUrls = new Set(audit.results.map((result) => result.url));
let requestDelayMs = baseDelayMs;
let stopped = false;

const browser = await chromium.launch({
  headless: true,
  executablePath,
  args: ['--single-process', '--no-zygote'],
});
const context = await browser.newContext({
  locale: 'en-GB',
  serviceWorkers: 'block',
});
await context.route('**/*', async (route) => {
  if (['image', 'media', 'font'].includes(route.request().resourceType())) {
    await route.abort();
  } else {
    await route.continue();
  }
});
const page = await context.newPage();

process.stdout.write(`Starting ${allTargets.length} targets; ${completedUrls.size} already complete; delay ${requestDelayMs} ms\n`);

try {
  for (let index = 0; index < allTargets.length; index += 1) {
    const target = allTargets[index];
    if (completedUrls.has(target.url)) continue;

    const requestStartedAt = Date.now();
    const firstAttempt = await fetchTarget(page, target, 1);
    const attempts = [firstAttempt];
    let finalAttempt = firstAttempt;

    if (firstAttempt.outcome === 'SUSPECT') {
      process.stdout.write(`[${index + 1}/${allTargets.length}] SUSPECT ${firstAttempt.reason}; waiting ${retryDelayMs} ms to retry ${target.url}\n`);
      if (firstAttempt.challenge_or_rate_limit) requestDelayMs = 3_000;
      await sleep(retryDelayMs);
      const retryAttempt = await fetchTarget(page, target, 2);
      attempts.push(retryAttempt);
      finalAttempt = retryAttempt;

      if (firstAttempt.challenge_or_rate_limit && retryAttempt.challenge_or_rate_limit) {
        audit.stopped = {
          reason: 'Persistent EUR-Lex rate limit or browser challenge after one 30-second retry',
          target_index: index + 1,
          url: target.url,
        };
        stopped = true;
      }
    }

    const result = {
      url: target.url,
      rids: target.rids,
      expected: target.expected,
      outcome: finalAttempt.outcome,
      reason: finalAttempt.reason,
      matched_oj_ref: finalAttempt.matched_oj_ref ?? null,
      final: finalAttempt,
      attempts,
    };
    audit.results.push(result);
    completedUrls.add(target.url);
    saveAudit(audit);

    if (finalAttempt.outcome === 'SUSPECT') {
      process.stdout.write(`[${index + 1}/${allTargets.length}] FINAL SUSPECT ${finalAttempt.reason}: ${target.url}\n`);
    } else if ((index + 1) % 10 === 0 || index === allTargets.length - 1) {
      process.stdout.write(`[${index + 1}/${allTargets.length}] PASS; saved ${audit.results.length}\n`);
    }

    if (stopped) break;
    const remainingDelay = requestDelayMs - (Date.now() - requestStartedAt);
    if (remainingDelay > 0) await sleep(remainingDelay);
  }
} finally {
  await context.close();
  await browser.close();
}

if (!stopped && audit.results.length >= allTargets.length) {
  audit.completed_at = new Date().toISOString();
}
saveAudit(audit);

const totals = audit.results.reduce((summary, result) => {
  summary[result.outcome] = (summary[result.outcome] ?? 0) + 1;
  return summary;
}, {});
process.stdout.write(`Finished: ${JSON.stringify({ audited: audit.results.length, targets: allTargets.length, totals, stopped: audit.stopped })}\n`);
