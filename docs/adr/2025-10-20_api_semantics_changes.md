# API semantics adjustments

Date: 20th October 2025

## Context

The existing implementation supported two concepts

1. Service - a grouping of API endpoints that run against a specific database schema within a single backend ECS service behind a single database. There are currently three schemas (uk, xi and public). /xi prefixed paths route to the xi schema, /uk prefixed paths route to the uk schema and both apps have access to the public schema.
2. API Version - a versioning mechanism to allow for non-breaking changes to be made to the API. This was implemented as a versioned path prefix (e.g. /v1/, /v2/ etc).

There are a couple of issues with this implementation as it stands:

- The API Version was implemented using path-based routing at the application level but this is inconsistent with how the client (HMRC) does versioning (using headers).
- The service concept was optional in all requests so it required domain knowledge to know which service to use for a given request. This is not ideal for continuity and maximum communication to various stakeholders about which service was used.

## Decisions

- Simplify all routing by dropping support for optional service prefixes in paths (at both the documentation level and the application level)
- Move to header-based versioning to align with HMRC best practices
- Document the new expected headers and path structures clearly in the API documentation to avoid confusion
- Ultimately deprecate the optional service and path version concept in favour of explicit service routing and force all requests to specify the service and version via headers (though this will have to come later when we have some means of communicating this to clients)

## Consequences

- New clients will use the preferred method of specifying service and version via headers
- Existing clients will use the old path-based implementations until we're ready
- Cache patterns will need updating in our CDNs
- No downtime expected as both methods will be supported for a transition period
