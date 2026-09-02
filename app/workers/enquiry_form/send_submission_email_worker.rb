require 'notifications/client'

class EnquiryForm::SendSubmissionEmailWorker
  CACHE_KEY_PREFIX = 'enquiry_form'.freeze
  TEMPLATE_ID = NOTIFY_CONFIGURATION.dig(:templates, :enquiry_form, :submission)

  def self.cache_key(reference)
    "#{CACHE_KEY_PREFIX}_#{reference}"
  end

  include Sidekiq::Worker

  # Cap retries: Notify outages must not use Sidekiq's default (25) and crowd the default queue.
  sidekiq_options retry: 3

  def perform(reference, audience = EnquiryForm::Submission::HMRC_AUDIENCE)
    perform_delivery(reference, audience)
  end

private

  def perform_delivery(reference, audience)
    form_data = enquiry_form_data(reference)

    if form_data.blank?
      Rails.logger.error(
        "#{self.class.name}: No data found in cache for reference #{reference} audience=#{audience}",
      )
      return
    end

    delivery = EnquiryForm::Submission.from_cache(form_data).delivery_for(audience)
    return if delivery.blank?

    send_email(delivery)
  end

  def send_email(delivery)
    form_data = delivery.form_data
    formatter = EnquiryForm::SubmissionFormatter.new(form_data)

    personalisation = {
      name: form_data[:name],
      company_name: form_data[:company_name],
      job_title: form_data[:job_title],
      email: form_data[:email],
      enquiry_category: formatter.notify_category,
      enquiry_description: formatter.enquiry_description,
      reference_number: form_data[:reference_number],
      search_request_id: form_data[:search_request_id],
      test_condition: delivery.test_condition,
      created_at: formatted_created_at(form_data),
      csv_file: csv_file(form_data),
    }

    reference = form_data[:reference_number]

    client.send_email(delivery.recipient, TEMPLATE_ID, personalisation, nil, reference)
  end

  def formatted_created_at(form_data)
    Time.zone.parse(form_data[:created_at]).in_time_zone('London').strftime('%Y-%m-%d %H:%M')
  end

  def csv_file(form_data)
    csv_data = ::EnquiryForm::CsvGeneratorService.new(form_data).generate

    Notifications.prepare_upload(StringIO.new(csv_data), filename: "enquiry_form_#{form_data[:reference_number]}.csv")
  end

  def enquiry_form_data(reference)
    data = Sidekiq.redis { |conn| conn.get(self.class.cache_key(reference)) }

    JSON.parse(data).symbolize_keys if data.present?
  end

  def client
    @client ||= GovukNotifier.new
  end
end
