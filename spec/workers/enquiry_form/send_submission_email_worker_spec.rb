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

    context 'with revised frontend enquiry payload combinations' do
      let(:large_text) do
        [
          'Lorem Ipsum is simply dummy text of the printing and typesetting industry.',
          'It has survived not only five centuries, but also the leap into electronic typesetting.',
          'Various versions have evolved over the years, sometimes by accident, sometimes on purpose.',
        ].join("\n\n").then { |text| (text * 30).first(5_000) }
      end

      let(:contact_variants) do
        optional_values = {
          name: 'Jane Doe',
          company_name: 'Jane Ltd.',
          job_title: 'Product Manager',
        }

        power_set(optional_values.keys).map do |keys|
          optional_values.keys.index_with { |key| keys.include?(key) ? optional_values[key] : '' }
        end
      end

      let(:category_tags) do
        {
          'import_duties_and_quota' => 'import_duties',
          'origin' => 'origin',
          'valuation' => 'customs_valuation',
          'developer_portal' => 'api_dev_portal_support',
          'stop_press_and_commodity_code_watch_lists' => 'stop_press_subscriptions',
          'other' => 'other',
        }
      end

      let(:classification_optional_variants) do
        optional_values = {
          goods_used_for: large_text,
          goods_function: large_text,
          goods_processed: large_text,
          goods_packaged: large_text,
        }

        power_set(optional_values.keys).map do |keys|
          optional_values.keys.index_with { |key| keys.include?(key) ? optional_values[key] : '' }
        end
      end

      let(:commodity_code_variants) do
        [
          { has_commodity_code: 'no', commodity_code: '' },
          { has_commodity_code: 'yes', commodity_code: '2005590000' },
        ]
      end

      before do
        allow(Notifications).to receive(:prepare_upload).and_return(
          {
            confirm_email_before_download: nil,
            file: 'csv-upload',
            filename: 'enquiry_form.csv',
            retention_period: nil,
          },
        )
      end

      it 'sends every generic category and optional contact combination to Notify' do
        expect(large_text.bytesize).to be > 4.kilobytes

        category_tags.to_a.product(contact_variants).each_with_index do |((category, notify_category), contact_details), index|
          reference = "GEN#{index.to_s.rjust(5, '0')}"
          payload = contact_details.merge(
            email: 'matrix@example.com',
            enquiry_category: category,
            enquiry_description: large_text,
            reference_number: reference,
            created_at: '2025-08-15 10:00',
          )
          payload[:other_category] = large_text if category == 'other'

          Sidekiq.redis { |conn| conn.set(described_class.cache_key(reference), payload.to_json, ex: 3600) }

          aggregate_failures("generic category #{category} contact variant #{index}") do
            expect { worker.perform(reference) }.not_to raise_error
            expect(notifier_client).to have_received(:send_email).with(
              'support@example.com',
              NOTIFY_CONFIGURATION.dig(:templates, :enquiry_form, :submission),
              hash_including(
                enquiry_category: notify_category,
                enquiry_description: large_text,
              ),
              nil,
              reference,
            )
          end
        ensure
          Sidekiq.redis { |conn| conn.del(described_class.cache_key(reference)) } if reference
        end
      end

      it 'sends every classification optional answer, commodity code and contact combination to Notify' do
        expect(large_text.bytesize).to be > 4.kilobytes

        classification_optional_variants.product(commodity_code_variants, contact_variants).each_with_index do |(optional_answers, commodity_code_answer, contact_details), index|
          reference = "CLS#{index.to_s.rjust(5, '0')}"
          payload = contact_details.merge(
            email: 'matrix@example.com',
            enquiry_category: 'classification',
            goods_product: large_text,
            goods_made_of: large_text,
            reference_number: reference,
            created_at: '2025-08-15 10:00',
          ).merge(optional_answers).merge(commodity_code_answer)

          Sidekiq.redis { |conn| conn.set(described_class.cache_key(reference), payload.to_json, ex: 3600) }

          aggregate_failures("classification variant #{index}") do
            expect { worker.perform(reference) }.not_to raise_error
            expect(notifier_client).to have_received(:send_email).with(
              'support@example.com',
              NOTIFY_CONFIGURATION.dig(:templates, :enquiry_form, :submission),
              hash_including(
                enquiry_category: 'classification',
                enquiry_description: include('What is the product?', large_text, 'What is it made of?'),
              ),
              nil,
              reference,
            )
          end
        ensure
          Sidekiq.redis { |conn| conn.del(described_class.cache_key(reference)) } if reference
        end
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

  def power_set(values)
    values.each_with_object([[]]) do |value, combinations|
      combinations.concat(combinations.map { |combination| combination + [value] })
    end
  end
end
