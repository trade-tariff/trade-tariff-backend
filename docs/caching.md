# Caching within the TradeTariff apps

This app is our backend, it is not directly routable but is accessed via 3 'frontend' apps. For the purposes of this document **frontend** refers to `trade-tariff-frontend`

HTML requests to our site hit our CDN, and are proxied on to our Frontend.

API requests to our site hit our CDN, are proxied on to our frontend, which in turn proxies on to our backend.

We utilise caching to avoid doing repeated work whilst presenting a largely read only dataset. This both lowers costs and improves resilience in the face of unexpectedly high loads.

## TL;DR

Working from 'inside' out, we cache at multiple levels

* Backend uses a Redis backed Rails cache to store **some** API responses
  * this avoids repeated and sometimes expensive database queries
  * cleared after a Tariff sync occurs
* Backend sets HTTP cache headers instructing its clients how its responses may be cached
  * by default this is set to cache for 2 minutes then revalidate for anything older.
  * A response is valid unless a backend Deployment or a Sync has happened
* Frontend uses these cache headers to control how it caches responses in it API client
* CDN ignores the cache headers and caches anything under `/api`, eg `/api/sections.json` for 30 minutes
* CDN does not cache HTML pages from the frontend

## Rails.cache

Our rails cache is backed by Redis on the AWS servers, and an in memory cache for local development.

Some high load API endpoints are manually cached by writing the API response to the rails cache prior to delivery, eg in `CachedCommodityService`. Requests will check for a cached response, and deliver this if present and if not, will render and store the response.

These cached responses, along with any other contents of Rails.cache, are cleared by the background job after we download our daily data update from CDS / Taric.

_Note: the in-memory cache used in local development is cleared automatically when the application is restarted._

Headings and Subheadings are pre-cached for the current day, ie generated ahead of time and written to the Rails.cache. This is done because the API outputs for Headings and Subheadings can be generated from the same set of loaded data meaning it only takes a couple of minutes to pre-render _every_ heading and subheading response.

These responses are pre-cached for the following day at 10pm, and then regenerated again on the day after the Tariff sync (if one occurs).

### Automatic invalidation

You can use Rails' cache versioning to invalidate cached responses for a given endpoint upon deployment, eg because you've changed the format of the response. This means as a PR is deployed to each subsequent environment the relevant cache keys get cleared automatically and avoids manually clearing the cache on servers after deployment.

```ruby
VERSION = 1 # change this to invalidate cache automatically on deploy
Rails.cache.fetch('my-cache-key', version: VERSION) do
  {
    message: 'Hello world'
  }.to_json
end
```

## HTTP caching

Where as the Rails Cache holds responses on the server, HTTP caching works by telling the HTTP client (or a proxy in the middle) what responses can be cached and it is up to the HTTP client to perform that caching.

Server controls, Client implements. It combines 2 concepts

1. Response Lifetime
2. Response Validity

### Response Lifetime

This is the easier concept, and is controlled via a `Cache-Control` HTTP header. This determines how long a stored response can be used for before needing to re-request (called re-validate) the content from the HTTP server.

This is currently set to **2 minutes** and is set via a constant in the `EtagCaching` controller concern.

### Response Validity

Determining whether a response stored by the client is still valid and can continue to be used. This is controlled via the combination of the `Last-Modified` header and more crucially the `ETag` header.

An ETag is a hashed identifier for the response contents, it is passed back to the HTTP server during the HTTP request, and the server determines whether the response is still valid.

If it determines it is still valid then the server returns an empty response with a `304 Not Modified` status code and the HTTP client continues to use its stored content until the next time it exceeds the lifetime in `Cache-Control`

If the server determines the ETag is out of date, then a regular `200` response with the full response body is returned. This will be stored by the HTTP client and continue to be used until the next time the lifetime is exceeded.

### Default behaviour

The ideal behaviour is the client caches for a short period of time, before re-validating with the server but the re-validation is very fast. This avoids using out dated data, but also avoids expensive database look ups to regenerate the data.

Our default behaviour is to use an ETag which combines

* The deployed application version (ie git sha)
* Todays date - so requests without `as_of` are always todays data
* the Last tariff sync record

When any of the above change, then the ETag changes and the HTTP client will download new copies of responses once the lifetime is reached.

### Alternative: Caching for a fixed period of time

You can force a controller to only cache its responses for a fixed period of time, after which the full response will be rendered

* if this matches what the client already had then it is determined to be valid and an empty `304` returned
* if it doesn't then a regular `200` is returned

```ruby
class MyNonOplogController
  time_based_caching # just derive ETag from full contents
end
```

### Alternative: Skip HTTP caching

To prevent HTTP caching from occurring at all, include the following in your controller

```ruby
class MyTimeCriticalController
  no_caching # sets Cache-Control: no-store
end
```

### Custom behaviour

If you require different behaviour from the default (eg `News::ItemsController` does this) you can combine the `time_based_caching` mechanism with your own logic for generating the `ETag`, eg

```
class News::ItemsController
  time_based_caching

  def index
    # Use `.latest_change` to generate ETag
    # Return 304 if that matches what the client already has
    return unless stale? News::Item.latest_change

    ## rest of regular action
  end
end
```

For further information see [HTTP Conditional GET support](https://guides.rubyonrails.org/caching_with_rails.html#conditional-get-support)

## HTTP Clients

With HTTP caching, the client is responsibly for honouring the behaviour set by the HTTP server

We have 2 http clients we control - our Frontend app and our CDN

### Frontend

Our API requests happen via Faraday and we include Faraday's HTTP caching plugin. This plugin follows the defined by our backend described above.

In practical terms, this means something like a call to `Commodity.find('1234567890')` will request all the Sections from the backend.

A subsequent call under 2 minutes later, will return the cached response. A call _after 2 minutes_ will re-request data from the backend

* If the backend has synced or deployed in between - then a new response will be sent
* If nothing has changed then the backend will return 304 and the frontend will continue using its cached response for a further 2 minutes.

### CDN

Our CDN talks to our frontend, which in turn proxies API requests through to our backend.

* Default behaviour is not to cache responses
* Paths beginning with `/api` are cached for 30 minutes

In both cases the cache headers from the apps are currently ignored.

_It is planned to change this to have the frontend proxy the backends API cache headers, and have the frontend return its own 'do not cache' headers for HTML pages - at which point we'll change the CDN to honour the cache headers._
