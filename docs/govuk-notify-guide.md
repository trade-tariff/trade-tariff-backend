# Sending email with GOV.UK Notify — quick reference

- `GovukNotifier` (`app/services/govuk_notifier.rb`) wraps the `notifications-ruby-client`
  gem — call `GovukNotifier.new.send_email(recipient, template_id, personalisation)`.
- Template IDs live in `NOTIFY_CONFIGURATION` (`config/initializers/notify.rb`), per
  environment, under `templates`.
- Template content (subject/body/placeholders) is **not** in this repo — it's managed
  in the Notify dashboard at https://www.notifications.service.gov.uk/your-services
  (pick the service for the relevant environment).
- `GovukNotifierAudit` records every send (notification UUID, rendered subject/body, template info).

## Steps

1. Design the template: pick personalisation fields, write subject/body using
   `((field))` / `((field??conditional text))`.
2. Create the template in the Notify dashboard for each environment
   (https://www.notifications.service.gov.uk/your-services) and copy each template ID.
3. Add the ID(s) to `config/initializers/notify.rb` under `templates`.
4. Call `GovukNotifier.new.send_email(email, TEMPLATE_ID, personalisation)` from your
   code; rescue `Notifications::Client::RequestError` if a failed send shouldn't blow
   up the caller.

## Testing

- **Manual (dev/staging)**: log into https://www.notifications.service.gov.uk/your-services for that environment's
  service to get an API key, set `GOVUK_NOTIFY_API_KEY` locally (and optionally `OVERRIDE_NOTIFY_EMAIL` to redirect all sends to your own inbox), then trigger the
  code (e.g. `bundle exec rails runner '...'`). Check the email arrives and cross-check the send in the dashboard's "sent messages" view.
