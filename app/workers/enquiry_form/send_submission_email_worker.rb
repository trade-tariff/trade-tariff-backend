require 'notifications/client'

class EnquiryForm::SendSubmissionEmailWorker
  include Sidekiq::Worker

  sidekiq_options queue: :mailers, retry: 5

  TEMPLATE_ID = '104e74e3-8f43-4642-a594-4d4ef931b121'.freeze

  def perform(enquiry_form_data, csv_data)
    parsed_data = JSON.parse(enquiry_form_data).symbolize_keys

    personalisation = {
      name: parsed_data[:name],
      company_name: parsed_data[:company_name],
      job_title: parsed_data[:job_title],
      email: parsed_data[:email],
      enquiry_category: parsed_data[:enquiry_category],
      enquiry_description: parsed_data[:enquiry_description],
      reference_number: parsed_data[:reference_number],
      created_at: parsed_data[:created_at],
      csv_file: Notifications.prepare_upload(StringIO.new(csv_data), filename: "enquiry_form_#{parsed_data[:reference_number]}.csv"),
    }

    reference = parsed_data[:reference_number]

    client.send_email(ENV['ENQUIRY_FORM_EMAIL'], TEMPLATE_ID, personalisation, nil, reference)
  end

  private

  def client
    @client ||= GovukNotifier.new
  end
end
