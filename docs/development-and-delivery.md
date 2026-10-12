# Development and Delivery

This page summarises team and platform conventions that live partly in Confluence. It is intentionally high level; verify current implementation in this repository before changing behaviour.

## Local Development

The repo README is the source of truth for this application's setup. The wider OTT onboarding guide also points new developers at:

- Xcode command-line tools and Homebrew on macOS.
- GitHub SSH setup and organisation access.
- AWS IAM access and MFA for operational work.
- Docker and backing services for multi-service development. Use the [README](../README.md#run-locally) for this repository's prerequisites.
- Signon/admin access through the relevant team channels.
- The `ecsexec` helper for opening ECS Exec sessions.
- `asdf` as the wider team version-manager convention.

This repo also supports DevContainers. Use whichever local setup is already standard for your machine and team.

## Pull Requests

Confluence path-to-live guidance and this repo's PR template agree on the basics:

- `main` is expected to be deployable.
- Do not commit directly to `main`.
- Put changes through a pull request.
- Include what changed, why it changed, ticket context, risk, and relevant manual evidence.
- Call out API documentation changes and environment variable changes.
- Resolve review conversations and wait for the required checks before merging.

Start with [CONTRIBUTING.md](../CONTRIBUTING.md) for the fork and contribution workflow.
This repo's current PR template is `.github/pull_request_template.md`.

## Merge Style

The OTT onboarding guide says the team relies on merge commits rather than squash or rebase merges so merges are visible in history. Follow the repository's current GitHub settings and team convention when merging.

## Checks

The path-to-live page describes these categories of checks:

- Ruby style and formatting.
- Trailing whitespace and end-of-file formatting.
- Markdown and YAML validation.
- Secret scanning.
- RSpec.
- Brakeman and CodeQL.
- Terraform validation for infrastructure repositories.

For this repository, verify the actual current checks in `.github/workflows/` and the pre-commit configuration.

## Deployments

Deployment is handled by GitHub Actions and ECS Fargate.

Useful current workflow files:

- `.github/workflows/ci.yml`
- `.github/workflows/codeql.yml`
- `.github/workflows/deploy-to-development.yml`
- `.github/workflows/deploy-to-development-full.yml`
- `.github/workflows/deploy-to-staging.yml`
- `.github/workflows/deploy-to-production.yml`

Development deploys can be requested through the relevant GitHub workflow or PR labels such as `needs-deployment` and `needs-full-deployment`. Staging and production promotion rules should be checked in the workflow files before release work.

### Approved fork deployments

The backend-only and full-stack development workflows use the shared tools
authorization action. It reads
[the central account policy](https://github.com/trade-tariff/trade-tariff-tools/blob/main/.github/approved-fork-deployers.json)
from tools `main`. Add an external contributor's GitHub login under
`trade-tariff-backend` through a reviewed tools PR. Approval for another
repository does not grant backend approval.

A repository writer adds `needs-deployment` for the backend alone or
`needs-full-deployment` for the full stack. An approved contributor can then
deploy later updates from their own fork. Both the original triggering account
and the account that reruns a job must be approved for this repository or have
repository write access. Unlisted forks cannot deploy through these workflows.

Authorization runs trusted code with read-only GitHub access and no deployment
secrets or OIDC permission. Deployment jobs use the exact authorized commit SHA.
The backend-only CloudWatch query check uses the same commit after deployment.
Full-stack deployment uses the authorized backend commit and the normal refs
for frontend, admin, identity and dev hub. The policy approves fork-code sources;
it does not filter these supporting apps.

Approval trusts the contributor's build, migration and Terraform code with the
existing deployment credentials. Development builds write images to shared
production-account ECR. The policy does not reduce IAM permissions or sandbox
fork code. Account-policy and caller-workflow changes need high-risk review.

Repository writers retain upstream PR deployment and manual dispatch access.
Run manual workflows from `main`. The optional `sha` input resolves a commit or
ref to an exact SHA before deployment. External account approval does not grant
manual dispatch access, organisation membership or personal AWS credentials.
Staging and production workflows do not use this policy.

Backend-only deployment runs the CloudWatch query check, not end-to-end tests.
Full-stack deployment runs the existing tariff checks. Check the deployed commit
and changed API behaviour on development. To roll back, a repository writer
runs the manual development workflow with the previous deployed commit.

## Backend Runtime Shape

Platform docs describe backend deployments as separate web and Sidekiq services for UK and XI. In this repo, service-specific behaviour is controlled by `SERVICE`, route mounting, synchronizer selection, and Sidekiq schedule flags.
