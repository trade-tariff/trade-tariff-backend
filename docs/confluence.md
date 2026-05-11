# Confluence References

These internal Confluence pages informed the local documentation. They are useful for wider OTT context, but source code, tests, ADRs, Terraform, and GitHub Actions remain authoritative for implementation details.

## Relevant Pages

- [Get started developing on the OTT](https://transformuk.atlassian.net/wiki/spaces/HO/pages/22447161366/Get+started+developing+on+the+OTT): onboarding, local admin access, Xcode/Homebrew, GitHub SSH, AWS IAM, Docker development stack, Signon access, merge commits, dependency tooling, and development deployments.
- [Backend: Technical Reference & User Guide](https://transformuk.atlassian.net/wiki/spaces/HO/pages/22719463434/Backend+Technical+Reference+User+Guide): backend purpose, API surfaces, UK/XI service split, search, sync, caching, jobs, integrations, configuration, and deployment context.
- [3.2 OTT Platform Architecture](https://transformuk.atlassian.net/wiki/spaces/HO/pages/22421536784/3.2+OTT+Platform+Architecture): business drivers, user groups, service capabilities, and platform-level architecture context.
- [3.1.1 Unified OTT Service Catalogue](https://transformuk.atlassian.net/wiki/spaces/HO/pages/22756163587/3.1.1+Unified+OTT+Service+Catalogue): business capability map across classification, measures, origin, MyOTT, APIs, news, support, and Northern Ireland services.
- [Path To Live](https://transformuk.atlassian.net/wiki/spaces/HO/pages/22768386053/Path+To+Live): PR expectations, checks, GitHub Actions deployment flow, environments, ECS deployment model, and promotion to production.
- [Caching](https://transformuk.atlassian.net/wiki/spaces/HO/pages/22681518101/Caching): backend/frontend cache layers, Redis, CloudFront, ETags, OpenSearch indexes, Rack::Attack rate-limit state, and invalidation paths.
- [OTT AWS Architecture](https://transformuk.atlassian.net/wiki/spaces/HO/pages/22688071689/OTT+AWS+Architecture): AWS account, networking, ECS, database, cache, and service layout context. This page is marked work in progress.
- [OTT AWS Operations Guide](https://transformuk.atlassian.net/wiki/spaces/HO/pages/22687809549/OTT+AWS+Operations+Guide): operational AWS tasks and environment context. This page is marked work in progress.

## How To Use These

- Use Confluence for platform context, onboarding, and team process.
- Use local docs for repo-specific navigation.
- Use source code for current implementation behaviour.
- Use GitHub Actions and Terraform for deployment and infrastructure behaviour.
- If Confluence and code disagree, update whichever source is stale before relying on the information.
