# Development and Delivery

This page summarises team and platform conventions that live partly in Confluence. It is intentionally high level; verify current implementation in this repository before changing behaviour.

## Local Development

The repo README is the source of truth for this application's setup. The wider OTT onboarding guide also points new developers at:

- Xcode command-line tools and Homebrew on macOS.
- GitHub SSH setup and organisation access.
- AWS IAM access and MFA for operational work.
- Docker Desktop, docker-compose, and `trade-tariff-development-stack` for multi-service development.
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

## Backend Runtime Shape

Platform docs describe backend deployments as separate web and Sidekiq services for UK and XI. In this repo, service-specific behaviour is controlled by `SERVICE`, route mounting, synchronizer selection, and Sidekiq schedule flags.
