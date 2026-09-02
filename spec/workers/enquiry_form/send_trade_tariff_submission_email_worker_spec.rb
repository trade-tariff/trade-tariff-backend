RSpec.describe EnquiryForm::SendTradeTariffSubmissionEmailWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:reference) { 'ABC12345' }
  let(:notification) { instance_double(GovukNotifierAudit, notification_uuid: 'notification-uuid') }
  let(:notifier_client) { instance_double(GovukNotifier, send_email: notification) }
  let(:form_data) do
    {
      name: 'John Doe',
      company_name: 'Doe & Co Inc.',
      job_title: 'CEO',
      email: 'john@example.com',
      enquiry_category: 'valuation',
      enquiry_description: 'I have a question.',
      feature_flags: %w[interactive_search],
      search_request_id: 'search-request-123',
      reference_number: reference,
      created_at: '2025-08-15 10:00',
      frontend_authenticated: true,
    }
  end

  before do
    Sidekiq.redis do |conn|
      conn.set(EnquiryForm::SendSubmissionEmailWorker.cache_key(reference), form_data.to_json, ex: 1.day.to_i)
    end
    allow(GovukNotifier).to receive(:new).and_return(notifier_client)
    allow(TradeTariffBackend).to receive(:support_email).and_return('team@example.com')
    allow(EnquiryForm::NotificationStatusCheckWorker).to receive(:perform_in)
  end

  after do
    Sidekiq.redis { |conn| conn.del(EnquiryForm::SendSubmissionEmailWorker.cache_key(reference)) }
  end

  it 'has enough retries to bridge a rolling deployment' do
    expect(described_class.sidekiq_options['retry']).to eq(10)
  end

  it 'sends an independently retryable, allowlisted team copy' do
    allow(StringIO).to receive(:new).and_call_original

    worker.perform(reference)

    expect(notifier_client).to have_received(:send_email).with(
      'team@example.com',
      NOTIFY_CONFIGURATION.dig(:templates, :enquiry_form, :submission),
      hash_including(
        name: nil,
        email: nil,
        company_name: 'Doe & Co Inc.',
        test_condition: 'Interactive search',
      ),
      nil,
      reference,
    )
    expect(StringIO).to have_received(:new).with(
      "Reference,Submission date,Full name,Company name,Job title,Email address,What do you need help with?,How can we help?\nABC12345,2025-08-15 10:00,,Doe & Co Inc.,CEO,,Valuation,I have a question.\n",
    ).twice
  end
end
