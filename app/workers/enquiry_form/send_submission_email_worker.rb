require 'notifications/client'

class EnquiryForm::SendSubmissionEmailWorker
  CACHE_KEY_PREFIX = 'enquiry_form'.freeze
  TEMPLATE_ID = NOTIFY_CONFIGURATION.dig(:templates, :enquiry_form, :submission)

  def self.cache_key(reference)
    "#{CACHE_KEY_PREFIX}_#{reference}"
  end

  include Sidekiq::Worker

  def perform(reference)
    form_data = enquiry_form_data(reference)

    if form_data.blank?
      Rails.logger.error("EnquiryForm::SendSubmissionEmailWorker: No data found in cache for reference #{reference}")
      return
    end

    created_at = Time.zone.parse(form_data[:created_at]).in_time_zone('London').strftime('%Y-%m-%d %H:%M')
    csv_data = ::EnquiryForm::CsvGeneratorService.new(form_data).generate
    csv_file = Notifications.prepare_upload(StringIO.new(csv_data), filename: "enquiry_form_#{form_data[:reference_number]}.csv")

    personalisation = {
      name: form_data[:name],
      company_name: form_data[:company_name],
      job_title: form_data[:job_title],
      email: form_data[:email],
      enquiry_category: form_data[:enquiry_category],
      enquiry_description: form_data[:enquiry_description],
      reference_number: form_data[:reference_number],
      created_at: created_at,
      csv_file: csv_file,
    }

    reference = form_data[:reference_number]

    client.send_email(ENV['ENQUIRY_FORM_EMAIL'], TEMPLATE_ID, personalisation, nil, reference)
  end

  private

  def enquiry_form_data(reference)
    data = Rails.cache.read(self.class.cache_key(reference))

    JSON.parse(data).symbolize_keys if data.present?
  end

  def client
    @client ||= GovukNotifier.new
  end
end
