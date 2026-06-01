RSpec.describe EnquiryForm::SendSubmissionEmailWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:reference) { 'ABC12345' }

  let(:form_data) do
    {
      name: 'John Doe',
      company_name: 'Doe & Co Inc.',
      job_title: 'CEO',
      email: 'john@example.com',
      enquiry_category: 'import_duties_and_quota',
      enquiry_description: 'I have a question about quotas',
      reference_number: reference,
      created_at: '2025-08-15 10:00',
    }
  end

  let(:notifier_client) { instance_double(GovukNotifier, send_email: true) }

  before do
    Sidekiq.redis { |conn| conn.set(described_class.cache_key(reference), form_data.to_json, ex: 3600) }

    allow(GovukNotifier).to receive(:new).and_return(notifier_client)
  end

  after do
    Sidekiq.redis { |conn| conn.del(described_class.cache_key(reference)) }
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
          enquiry_category: 'import_duties',
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
      allow(StringIO).to receive(:new).and_call_original

      worker.perform(reference)

      expect(StringIO).to have_received(:new).with("Reference,Submission date,Full name,Company name,Job title,Email address,What do you need help with?,How can we help?\nABC12345,2025-08-15 10:00,John Doe,Doe & Co Inc.,CEO,john@example.com,Import duties and quotas,I have a question about quotas\n").twice
    end

    context 'with a classification enquiry' do
      let(:form_data) do
        {
          name: 'John Doe',
          company_name: 'Doe & Co Inc.',
          job_title: 'CEO',
          email: 'john@example.com',
          enquiry_category: 'classification',
          goods_product: 'Baked beans',
          goods_made_of: 'Beans and tomato sauce',
          goods_used_for: 'Food',
          goods_function: 'Ready to eat',
          goods_processed: 'Cooked and mixed',
          goods_packaged: 'Tinned',
          has_commodity_code: 'yes',
          commodity_code: '2005590000',
          reference_number: reference,
          created_at: '2025-08-15 10:00',
        }
      end

      it 'sends the structured answers as the enquiry description personalisation' do
        worker.perform(reference)

        expect(notifier_client).to have_received(:send_email).with(
          'support@example.com',
          NOTIFY_CONFIGURATION.dig(:templates, :enquiry_form, :submission),
          hash_including(
            enquiry_category: 'classification',
            enquiry_description: "What is the product?\nBaked beans\n\nWhat is it made of?\nBeans and tomato sauce\n\nWhat is it used for?\nFood\n\nHow does it work or function?\nReady to eat\n\nHas it been processed, prepared or treated in any way?\nCooked and mixed\n\nHow is it presented or packaged?\nTinned\n\nDo you already have a possible commodity code?\nYes\n\nPossible commodity code\n2005590000",
          ),
          nil,
          'ABC12345',
        )
      end
    end

    context 'with an unexpected enquiry category' do
      let(:form_data) { super().merge(enquiry_category: 'unknown_category') }

      it 'defaults the Notify category tag to other' do
        worker.perform(reference)

        expect(notifier_client).to have_received(:send_email).with(
          'support@example.com',
          NOTIFY_CONFIGURATION.dig(:templates, :enquiry_form, :submission),
          hash_including(enquiry_category: 'other'),
          nil,
          'ABC12345',
        )
      end
    end

    context 'when the cache key has expired or is missing' do
      before do
        Sidekiq.redis { |conn| conn.del(described_class.cache_key(reference)) }
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
