RSpec.describe EnquiryForm::SendSubmissionEmailWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:reference) { 'ABC12345' }

  let(:cached_data) do
    {
      name: 'John Doe',
      company_name: 'Doe & Co Inc.',
      job_title: 'CEO',
      email: 'john@example.com',
      enquiry_category: 'Quotas',
      enquiry_description: 'I have a question about quotas',
      reference_number: reference,
      created_at: '2025-08-15 10:00',
    }.to_json
  end

  let(:csv_content) { "name,email\nJohn,john@example.com" }
  let(:notifier_client) { instance_double(GovukNotifier, send_email: true) }

  let(:redis_mock) { instance_double(Redis, get: cached_data) }

  before do
    allow(Sidekiq).to receive(:redis).and_yield(redis_mock)
    allow(EnquiryForm::CsvGeneratorService).to receive(:new).and_call_original
    allow(Notifications).to receive(:prepare_upload).and_call_original
    allow(GovukNotifier).to receive(:new).and_return(notifier_client)
    allow(StringIO).to receive(:new).and_call_original
  end

  describe '#perform' do
    it 'fetches data from cache, generates CSV, and sends email' do
      worker.perform(reference)

      expect(notifier_client).to have_received(:send_email).with(
        'support@example.com',
        NOTIFY_CONFIGURATION.dig(:templates, :enquiry_form, :submission),
        {
          company_name: 'Doe & Co Inc.',
          created_at: '2025-08-15 11:00',
          csv_file: {
            confirm_email_before_download: nil,
            file: be_a(String),
            filename: 'enquiry_form_ABC12345.csv',
            retention_period: nil,
          },
          email: 'john@example.com',
          enquiry_category: 'Quotas',
          enquiry_description: 'I have a question about quotas',
          job_title: 'CEO',
          name: 'John Doe',
          reference_number: 'ABC12345',
        },
        nil,
        'ABC12345',
      )
    end

    it 'generates the correct CSV content' do
      worker.perform(reference)

      expect(StringIO).to have_received(:new).with("Reference,Submission date,Full name,Company name,Job title,Email address,What do you need help with?,How can we help?\nABC12345,2025-08-15 10:00,John Doe,Doe & Co Inc.,CEO,john@example.com,Quotas,I have a question about quotas\n").twice
    end

    context 'when the cache key has expired or is missing' do
      let(:redis_mock) { instance_double(Redis, get: nil) }

      before do
        allow(Rails.logger).to receive(:error).and_call_original
      end

      it 'triggers an error message' do
        worker.perform(reference)

        expect(Rails.logger).to have_received(:error).with("EnquiryForm::SendSubmissionEmailWorker: No data found in cache for reference #{reference}")
        expect(notifier_client).not_to have_received(:send_email)
      end
    end
  end
end
