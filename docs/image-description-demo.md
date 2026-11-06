# Local image-description demo

This development-only journey turns a product image into an editable description.
The trader checks the description before submitting the existing guided search.
It uses real OpenAI inference. Bedrock and production deployment are not included.

## Prerequisites

- A working local backend with tariff data, PostgreSQL, Redis and OpenSearch.
- A matching frontend with image-description support.
- The existing backend OpenAI configuration, including its approved endpoint.
- Linux with bubblewrap and libvips. HEIC and AVIF need the corresponding codecs.

Keep provider credentials in the existing local secret configuration. Never put
credentials in the frontend or commit them. Use product images without personal
or sensitive information. Images leave the machine for inference.

## Run

Enable `IMAGE_DESCRIPTIONS_ENABLED=true` on the backend web process, the demo
worker and the frontend. Enable the existing `INTERACTIVE_SEARCH=true` frontend
flag. Keep all service URLs and backing services local.

Start the backend web process with the existing local database configuration:

```sh
direnv exec . env IMAGE_DESCRIPTIONS_ENABLED=true bundle exec rails server -b 127.0.0.1 -p 3000
```

Start a worker from the same checkout. With Nix, add conversion tools ephemerally:

```sh
direnv exec . nix shell nixpkgs#vips nixpkgs#bubblewrap -c env IMAGE_DESCRIPTIONS_ENABLED=true bundle exec sidekiq -C config/sidekiq_image_demo.yml
```

The worker and web process must share the same checkout, temporary directory,
Redis and local database configuration. The demo worker consumes image jobs and
the existing guided-search queue. Its tariff sync and reporting schedules are off.

Start the matching frontend on port 3001 with its UK API URL pointing to
`http://127.0.0.1:3000/uk/api`. Open `/uk/find_commodity`, select **Beta AI-assisted
search**, and drop one image onto the description field or use the file picker.
Wait for the description, correct it if necessary, then search.

`IMAGE_DESCRIPTION_MODEL` optionally selects the backend vision model. Its default
is `gpt-4.1-mini`. Provider failures do not produce a fabricated description.

## API and limits

- `POST /uk/internal/image_descriptions` accepts a multipart `image` file and
  optional `request_id`. It returns `202` with a job ID only after enqueueing.
- `GET /uk/internal/image_descriptions/:id` returns `queued`, `running`,
  `completed` or `failed`. Completion contains `description` and `uncertainties`.
- The frontend proxies uploads and verifies a session-bound polling grant.
- The backend accepts only local requests. Both apps disable this feature outside
  development/test, even when the environment flag is set.
- One image, at most 15 MB, 50 megapixels and 16,384 pixels on either side.
- Accepted formats: JPEG, PNG, WebP, GIF, HEIC/HEIF, AVIF and TIFF. Animated and
  multipage images are rejected. Codec support depends on the libvips build.
- Conversion strips metadata and produces an sRGB JPEG with a longest edge of
  at most 2,048 pixels and a maximum encoded size of 3 MB.
- Native decoding has no network, credentials or access to the user's home.
  Subprocess CPU, address space, output size and elapsed time are bounded.
- At most three images are staged per service and checkout. Redis stores small
  state records, not image bytes. Records expire after ten minutes.
- Terminal processing removes files. A new upload removes abandoned directories
  older than ten minutes. No cleanup runs while the demo is stopped.

The OpenAI operation has a twenty-second deadline. The frontend stops waiting
after a bounded interval; cancelling the browser wait does not cancel accepted
provider work. Image descriptions can enter existing search query logs after
the trader submits search. Provider retention follows the approved account's
data controls, not just the request's `store: false` setting.

This is not a production upload service. Production adoption still needs approved
storage and retention, service authentication, ingress body limits, distributed
admission control and isolated worker deployment. Do not enable it by removing
the development/test gate.
