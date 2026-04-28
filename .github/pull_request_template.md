## What:
<!-- A brief description of what this PR does -->

## Why:
<!-- The reasoning or context behind this change -->

## Ticket:
<!-- Link to the relevant Jira/ticket, or 'N/A' if not applicable -->

## Risk:
**Risk level:** 🟢 / 🟠 / 🔴 <!-- delete as appropriate -->

**Reason for rating:**
<!-- One or two sentences explaining your assessment, especially for Amber or Red -->

───────────────────────────────────────────────────

Rate the overall risk of deploying this change:

🟢 Green  – Low risk. Good to go, standard review applies.

🟠 Amber  – Medium risk. Socialise with the team before merging.

🔴 Red    – High risk. Requires explicit approval from Thor or Neil before merging.

───────────────────────────────────────────────────

🟢 GREEN – things that are typically low risk:
───────────────────────────────────────────────────
- Dependency bumps with no API changes (e.g. minor/patch gems, npm packages)
- Copy or content changes in GOV.UK-style UI components
- Adding or updating CloudWatch alarms or dashboards (read-only observability)
- New tests or improved test coverage with no production code changes
- Config/env var additions that are purely additive and have safe defaults
- Refactors with full test coverage and no behaviour change
- Terraform formatting or variable renaming with no resource recreation
- S3 lifecycle rule additions (non-destructive, time-delayed effect)

🟠 AMBER – things that need a team conversation first:
───────────────────────────────────────────────────
- Changes to commodity code lookups, measure type logic, or duty calculation
- Modifications to the search indexing pipeline (OpenSearch mappings, synonyms, stop words)
- Changes to declarable goods or quota logic
- New or modified API endpoints that other services (backend, frontend, admin) consume
- Adding or changing feature flags that affect live user journeys
- Infrastructure changes that alter networking, security groups, or IAM permissions in non-production first
- Terraform changes that will cause a resource replacement (check plan output carefully)
- Changes to CI/CD pipeline steps or deployment order dependencies
- S3 bucket policy or access control changes
- Removing or deprecating an endpoint or field that may still be consumed

🔴 RED – requires explicit approval from Thor or Neil:
───────────────────────────────────────────────────
- Dangerous database migrations, especially destructive ones (dropping columns/tables, removing indexes)
- Modifications to how measures, conditions, or footnotes are processed or surfaced
- Changes to the synchronisation mechanism from CDS or HMRC upstream data feeds
- Any change to production AWS infrastructure that cannot be easily rolled back (e.g. RDS parameter groups, KMS key policy, removal of resources)
- Secrets rotation or changes to how credentials are stored, scoped, or accessed
- Changes that affect trader-facing regulatory content or legally significant data (e.g. trade remedies, licensing, prohibitions)
- Significant architectural shifts (e.g. new service boundaries, queue/event topology changes)
