RSpec.describe Api::V2::EnquiryForm::SubmissionsController, :v2 do
  describe 'POST #create' do
    let(:params) do
      {
        name: 'John Doe',
        company_name: 'Doe & Co Inc.',
        job_title: 'CEO',
        email: 'john@example.com',
        enquiry_category: 'Quotas',
        enquiry_description: 'I have a question.',
      }
    end

    let(:headers) { { 'Content-Type' => 'application/json' } }
    let(:reference_number) { 'ABC12345' }

    let(:frozen_time) { Time.zone.parse('2025-12-08 12:00:00') }

    before do
      travel_to frozen_time

      allow(CreateReferenceNumberService).to receive(:new).and_return(
        instance_double(CreateReferenceNumberService, call: reference_number),
      )

      allow(Api::V2::EnquiryForm::SubmissionSerializer).to receive(:new).and_call_original

      allow(::EnquiryForm::SendSubmissionEmailWorker).to receive(:perform_async)
    end

    after do
      travel_back
      Sidekiq.redis { |conn| conn.del(::EnquiryForm::SendSubmissionEmailWorker.cache_key(reference_number)) }
    end

    it 'returns 201 created with reference number' do
      post api_enquiry_form_submissions_path,
           params: { data: { attributes: params } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['data']['id']).to eq(reference_number)
    end

    it 'caches the data and enqueues the email worker with the reference only' do
      post api_enquiry_form_submissions_path,
           params: { data: { attributes: params } },
           headers: headers,
           as: :json

      expected_payload = params.merge(
        reference_number: reference_number,
        created_at: frozen_time.strftime('%Y-%m-%d %H:%M'),
      )

      cached = Sidekiq.redis { |conn| conn.get("enquiry_form_#{reference_number}") }
      expect(JSON.parse(cached, symbolize_names: true)).to eq(expected_payload)

      expect(::EnquiryForm::SendSubmissionEmailWorker).to have_received(:perform_async).with(reference_number)
    end

    context 'with a classification enquiry from the revised frontend form' do
      let(:classification_params) do
        params.merge(
          enquiry_category: 'classification',
          enquiry_description: nil,
          goods_product: 'Baked beans',
          goods_made_of: 'Beans and tomato sauce',
          goods_used_for: 'Food',
          goods_function: 'Ready to eat',
          goods_processed: 'Cooked and mixed',
          goods_packaged: 'Tinned',
          has_commodity_code: 'yes',
          commodity_code: '2005590000',
        ).compact
      end

      it 'caches the structured classification answers for the worker' do
        post api_enquiry_form_submissions_path,
             params: { data: { attributes: classification_params } },
             headers: headers,
             as: :json

        cached = Sidekiq.redis { |conn| conn.get("enquiry_form_#{reference_number}") }

        expect(JSON.parse(cached, symbolize_names: true)).to include(
          enquiry_category: 'classification',
          goods_product: 'Baked beans',
          goods_made_of: 'Beans and tomato sauce',
          goods_used_for: 'Food',
          goods_function: 'Ready to eat',
          goods_processed: 'Cooked and mixed',
          goods_packaged: 'Tinned',
          has_commodity_code: 'yes',
          commodity_code: '2005590000',
          reference_number: reference_number,
          created_at: frozen_time.strftime('%Y-%m-%d %H:%M'),
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

      let(:generic_categories) do
        %w[
          import_duties_and_quota
          origin
          valuation
          developer_portal
          stop_press_and_commodity_code_watch_lists
          other
        ]
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

      it 'accepts and caches every generic category and optional contact combination with large text' do
        expect(large_text.bytesize).to be > 4.kilobytes

        test_cases = generic_categories.product(contact_variants, [large_text])
        created_references = []

        test_cases.each_with_index do |(category, contact_details, query), index|
          reference = "GEN#{index.to_s.rjust(5, '0')}"
          created_references << reference
          allow(CreateReferenceNumberService).to receive(:new).and_return(
            instance_double(CreateReferenceNumberService, call: reference),
          )

          frontend_payload = contact_details.merge(
            email: 'matrix@example.com',
            enquiry_category: category,
            enquiry_description: query,
          )
          frontend_payload[:other_category] = large_text if category == 'other'

          post api_enquiry_form_submissions_path,
               params: { data: { attributes: frontend_payload } },
               headers: headers,
               as: :json

          cached = Sidekiq.redis { |conn| conn.get("enquiry_form_#{reference}") }

          aggregate_failures("generic category #{category} contact variant #{index}") do
            expect(response).to have_http_status(:created)
            expect(JSON.parse(cached, symbolize_names: true)).to include(frontend_payload)
          end
        end
      ensure
        Array(created_references).each do |reference|
          Sidekiq.redis { |conn| conn.del("enquiry_form_#{reference}") }
        end
      end

      it 'accepts and caches every classification optional answer, commodity code and contact combination' do
        expect(large_text.bytesize).to be > 4.kilobytes

        test_cases = classification_optional_variants.product(commodity_code_variants, contact_variants)
        created_references = []

        test_cases.each_with_index do |(optional_answers, commodity_code_answer, contact_details), index|
          reference = "CLS#{index.to_s.rjust(5, '0')}"
          created_references << reference
          allow(CreateReferenceNumberService).to receive(:new).and_return(
            instance_double(CreateReferenceNumberService, call: reference),
          )

          frontend_payload = contact_details.merge(
            email: 'matrix@example.com',
            enquiry_category: 'classification',
            goods_product: large_text,
            goods_made_of: large_text,
          ).merge(optional_answers).merge(commodity_code_answer)

          post api_enquiry_form_submissions_path,
               params: { data: { attributes: frontend_payload } },
               headers: headers,
               as: :json

          cached = Sidekiq.redis { |conn| conn.get("enquiry_form_#{reference}") }

          aggregate_failures("classification variant #{index}") do
            expect(response).to have_http_status(:created)
            expect(JSON.parse(cached, symbolize_names: true)).to include(frontend_payload)
          end
        end
      ensure
        Array(created_references).each do |reference|
          Sidekiq.redis { |conn| conn.del("enquiry_form_#{reference}") }
        end
      end
    end

    context 'when required params are missing' do
      it 'returns a 422 Unprocessable Content with errors' do
        post api_enquiry_form_submissions_path,
             params: { data: nil },
             headers: headers,
             as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  def power_set(values)
    values.each_with_object([[]]) do |value, combinations|
      combinations.concat(combinations.map { |combination| combination + [value] })
    end
  end
end
