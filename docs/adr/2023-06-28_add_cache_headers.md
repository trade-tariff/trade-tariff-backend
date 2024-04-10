# Adding cache headers

Date: 28 June 2023

## Context

We currently have a CDN which has its cache support disabled and always just passes requests straight through to first the frontend end and then onward to the backend.

Our frontend requires various changes to support cacheability from the CDN but would benefit from that work occurring at some point.

Our backend has no state so its responses to GET and HEAD requests are easily cacheable.

## Decision

Caching of backend responses will be enabled in two phases - first internally only, then for broader downstream use.

## Consequences

### Phase 1

The backend will start setting headers to control caching. These will have a very short TTL to allow for quick updating will utilise ETags to allow for very quick (~2ms) HEAD 304 responses from the backend for the majority of requests which have already been seen by the caching client.

Any non-GET or HEAD requests will not set cache headers

Some endpoints (eg News) will require custom ETags based on the the relevant data lifecycle.

The backends Cache-Control header is overwritten by the frontend, then ignored
by the CDN anyway so this should not have any downstream impact.

The Frontend will have a http cache added to its api client, which means it will
in turn cache the api responses it is receiving from the backend (where the
backends response headers direct it to).

### Phase 2

The frontend will be changed to pass the cache headers through from the backend rather then overwriting them - placing the backend in control of the cachability of its responses

The frontend will mark its own responses as no-store to prevent caching

After the above has been deployed the CDN will be updated to follow the caching headers from its upstream -;

* In the case of web access this should always be 'no-store'
* In the case of proxied API access from the backend, this should be the ETagged behaviour dictated by the backend
