require 'notifications/client'

class GovukNotifier
  class NoTemplateFoundError < StandardError; end

  def initialize(client: nil)
    @client = client || Notifications::Client.new(api_key)
  end

  def send_email(email, template_id, personalisation = {})
    # TODO: one_click_unsubscribe_url https://docs.notifications.service.gov.uk/ruby.html#one-click-unsubscribe-url-recommended
    email_response = @client.send_email(
      email_address: email,
      template_id: template_id,
      personalisation: personalisation,
    )
    audit(email_response)
  rescue Notifications::Client::RequestError => e
    raise e
  end

  private

  def api_key
    @api_key ||= ENV['GOVUK_NOTIFY_API_KEY']
  end

  def email(email)
    return email if Rails.env.production?

    ENV.fetch('OVERRIDE_NOTIFY_EMAIL', email)
  end

  def audit(email_response)
    GovukNotifierAudit.create(
      notification_uuid: email_response['id'],
      subject: email_response['content']['subject'],
      body: email_response['content']['body'],
      from_email: email_response['content']['from_email'],
      template_id: email_response['template']['id'],
      template_version: email_response['template']['version'],
      template_uri: email_response['template']['uri'],
      notification_uri: email_response['uri'],
      created_at: Time.zone.now,
    )
  end
end
