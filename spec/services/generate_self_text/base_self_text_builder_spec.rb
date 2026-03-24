RSpec.describe GenerateSelfText::BaseSelfTextBuilder do
  # Use OtherSelfTextBuilder as a concrete stand-in. The tests here cover only
  # the shared infrastructure defined in BaseSelfTextBuilder; behaviour specific
  # to each subclass is covered in their own spec files.
  let(:builder_class) { GenerateSelfText::OtherSelfTextBuilder }

  let(:chapter) { create(:chapter, :with_description, description: 'Live animals') }
  let(:heading) { create(:heading, :with_description, description: 'Live horses', parent: chapter) }
  let(:other_commodity) do
    create(:commodity, :with_description, description: 'Other', parent: heading)
  end
  let(:named_sibling) do
    create(:commodity, :with_description, description: 'Pure-bred breeding animals', parent: heading)
  end
  let(:ai_client) { instance_double(OpenaiClient) }

  before do
    named_sibling
    other_commodity

    create(:admin_configuration,
           name: 'other_self_text_context',
           config_type: 'markdown',
           description: 'System prompt',
           value: 'You are an expert.')

    create(:admin_configuration,
           name: 'other_self_text_model',
           config_type: 'nested_options',
           description: 'Model config',
           value: {
             'selected' => 'gpt-4.1-mini-2025-04-14',
             'sub_values' => {},
             'options' => [{ 'key' => 'gpt-4.1-mini-2025-04-14', 'sub_options' => {} }],
           })

    create(:admin_configuration,
           name: 'other_self_text_batch_size',
           config_type: 'integer',
           description: 'Batch size',
           value: '5')

    allow(TradeTariffBackend).to receive(:ai_client).and_return(ai_client)
    allow(ai_client).to receive(:call).and_return(ai_response)
  end

  let(:ai_response) do # rubocop:disable RSpec/ScatteredLet
    {
      'descriptions' => [
        {
          'sid' => other_commodity.goods_nomenclature_sid,
          'contextualised_description' => 'Live horses (excl. pure-bred for breeding)',
        },
      ],
    }.to_json
  end

  describe '#call' do
    subject(:result) { builder_class.call(chapter) }

    it 'returns a stats hash with processed/failed/skipped counts' do
      expect(result).to include(:processed, :failed, :skipped)
    end

    describe 'skip logic' do
      it 'skips records whose context hash and freshness have not changed' do
        builder_class.call(chapter)

        RSpec::Mocks.space.proxy_for(ai_client).reset
        allow(TradeTariffBackend).to receive(:ai_client).and_return(ai_client)
        allow(ai_client).to receive(:call)

        second_result = builder_class.call(chapter)

        expect(second_result[:skipped]).to be >= 1
        expect(ai_client).not_to have_received(:call)
      end

      it 'reprocesses stale records' do
        builder_class.call(chapter)
        GoodsNomenclatureSelfText[other_commodity.goods_nomenclature_sid].update(stale: true)

        allow(ai_client).to receive(:call).and_return(ai_response)
        second_result = builder_class.call(chapter)

        expect(second_result[:processed]).to be >= 1
      end

      it 'reprocesses manually_edited records when context changes' do
        builder_class.call(chapter)

        record = GoodsNomenclatureSelfText[other_commodity.goods_nomenclature_sid]
        record.update(manually_edited: true, self_text: 'Custom text')

        builder_class.call(chapter)

        record.refresh
        expect(record.self_text).to eq('Custom text')
        expect(record.manually_edited).to be true
      end
    end

    describe 'failed count' do
      context 'when the AI returns an empty response' do
        before { allow(ai_client).to receive(:call).and_return('') }

        it 'increments the failed count by the batch size' do
          expect(result[:failed]).to eq(1)
        end
      end

      context 'when the AI returns a non-hash response' do
        before { allow(ai_client).to receive(:call).and_return('not json at all') }

        it 'increments the failed count' do
          expect(result[:failed]).to eq(1)
        end
      end

      context 'when a description is missing contextualised_description' do
        let(:ai_response) do
          { 'descriptions' => [{ 'sid' => other_commodity.goods_nomenclature_sid }] }.to_json
        end

        it 'counts the missing description as failed' do
          expect(result[:failed]).to eq(1)
        end
      end
    end

    describe 'encoding artefact sanitisation' do
      let(:ai_response) do
        {
          'descriptions' => [{
            'sid' => other_commodity.goods_nomenclature_sid,
            'contextualised_description' => 'Fruit pure9e (excl. concentrate)',
          }],
        }.to_json
      end

      it 'sanitises encoding artefacts in the stored text' do
        result
        expect(GoodsNomenclatureSelfText[other_commodity.goods_nomenclature_sid].self_text)
          .to eq('Fruit puree (excl. concentrate)')
      end
    end

    describe 'batching' do
      let(:other_commodities) do
        Array.new(6) { create(:commodity, :with_description, description: 'Other', parent: heading) }
      end

      before do
        allow(AdminConfiguration).to receive(:integer_value)
          .with('other_self_text_batch_size').and_return(3)

        other_commodities

        allow(ai_client).to receive(:call) do |messages, **_opts|
          sids = JSON.parse(messages.last[:content]).map { |s| s['sid'] }
          {
            'descriptions' => sids.map do |sid|
              { 'sid' => sid, 'contextualised_description' => "Generated for #{sid}" }
            end,
          }.to_json
        end
      end

      it 'splits work into batches of the configured size' do
        result
        # 7 Other nodes (6 new + original), batch_size=3 → 3 AI calls
        expect(ai_client).to have_received(:call).exactly(3).times
      end
    end

    describe 'ancestor context propagation' do
      before do
        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: heading.goods_nomenclature_sid,
               goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
               self_text: 'Live animals > Live horses',
               generation_type: 'mechanical')
      end

      it 'includes pre-loaded ancestor self-texts in the AI payload' do
        result

        expect(ai_client).to have_received(:call) do |messages, **_opts|
          segment = JSON.parse(messages.last[:content]).first
          expect(segment['ancestor_chain']).to include('Live animals')
        end
      end
    end
  end
end
