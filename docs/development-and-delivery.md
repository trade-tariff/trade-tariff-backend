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

## Backend Runtime Shape

Platform docs describe backend deployments as separate web and Sidekiq services for UK and XI. In this repo, service-specific behaviour is controlled by `SERVICE`, route mounting, synchronizer selection, and Sidekiq schedule flags.

### Development private search access

`terraform/config_development.tfvars` enables `enable_private_search_access`.
Deploy the platform-owned `opensearch-client-development` security group before
deploying this backend configuration. Terraform looks up the group by its exact
name and VPC. A missing group stops the plan; there is no fallback.

The UK and XI API and worker services retain their shared ECS security group and
add the search-client group. The backend job module uses the same group list.
Staging and production keep the default value, `false`, and retain their existing
group list.

This change does not update `ELASTICSEARCH_URL`, SSM parameters, or Secrets Manager
configuration. Search traffic continues to use the current domain until a separate
data migration and cutover.

ECS task definitions do not store security groups. Operational `RunTask` launchers
must supply both groups explicitly when a job needs private search. The shared
tools launcher and database replication workflows supply their own network
configuration. Do not assume that updating the backend job module changes those
launchers. Database backup and backup-check schedules keep only the existing ECS
group because they do not need search access.

Before deployment, review the development plan for security-group additions
without removal of the existing ECS group. After deployment, verify the task ENIs
for both APIs and workers include the client group. Use an approved search job
with both groups to verify HTTPS connectivity to the private domain. Verify that
an unrelated task with only the shared group cannot connect.
