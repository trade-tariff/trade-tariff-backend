RSpec.describe GenerateSelfText::NonOtherSelfTextBuilder do
  describe '.call' do
    subject(:result) { described_class.call(chapter) }

    let(:chapter) { create(:chapter, :with_description, description: 'Live animals') }

    let(:heading) do
      create(:heading, :with_description,
             description: 'Live horses',
             parent: chapter)
    end

    let(:commodity) do
      create(:commodity, :with_description,
             description: 'Pure-bred breeding animals',
             parent: heading)
    end

    let(:other_commodity) do
      create(:commodity, :with_description,
             description: 'Other',
             parent: heading)
    end

    let(:ai_client) { instance_double(OpenaiClient) }
    let(:system_prompt_text) { 'You are an expert in the UK Trade Tariff.' }

    let(:successful_response) do
      proc { |messages, **_opts|
        user_content = JSON.parse(messages.last[:content])
        sids = user_content.map { |s| s['sid'] }

        {
          'descriptions' => sids.map do |sid|
            {
              'sid' => sid,
              'contextualised_description' => "Flattened for #{sid}",
            }
          end,
        }.to_json
      }
    end

    before do
      commodity
      other_commodity

      create(:admin_configuration,
             name: 'non_other_self_text_context',
             config_type: 'markdown',
             description: 'System prompt for non-Other self-text generation',
             value: system_prompt_text)

      create(:admin_configuration,
             name: 'non_other_self_text_model',
             config_type: 'options',
             description: 'AI model for non-Other self-text generation',
             value: { 'selected' => 'gpt-5.2', 'options' => [{ 'key' => 'gpt-5.2' }] })

      create(:admin_configuration,
             name: 'non_other_self_text_batch_size',
             config_type: 'integer',
             description: 'Batch size for non-Other AI self-text generation',
             value: '15')

      allow(TradeTariffBackend).to receive(:ai_client).and_return(ai_client)
      allow(ai_client).to receive(:call, &successful_response)
      allow(SelfTextLookupService).to receive(:lookup).and_return(nil)
    end

    it 'stores AI-generated self-texts for non-Other nodes' do
      result

      record = GoodsNomenclatureSelfText[commodity.goods_nomenclature_sid]
      expect(record.self_text).to start_with('Flattened for ')
    end

    it 'sets generation_type to ai_non_other' do
      result

      record = GoodsNomenclatureSelfText[commodity.goods_nomenclature_sid]
      expect(record.generation_type).to eq('ai_non_other')
    end

    it 'skips Other nodes' do
      result

      expect(GoodsNomenclatureSelfText[other_commodity.goods_nomenclature_sid]).to be_nil
    end

    it 'skips chapters' do
      result

      expect(GoodsNomenclatureSelfText[chapter.goods_nomenclature_sid]).to be_nil
    end

    it 'processes heading and commodity (2 non-Other, non-chapter nodes)' do
      expect(result[:processed]).to eq(2)
    end

    context 'when eu_self_text is available' do
      before do
        allow(SelfTextLookupService).to receive(:lookup)
          .with(commodity.goods_nomenclature_item_id)
          .and_return('Pure-bred breeding horses')
      end

      it 'includes eu_self_text in the segment JSON sent to AI' do
        result

        expect(ai_client).to have_received(:call) do |messages, **_opts|
          user_content = JSON.parse(messages.last[:content])
          commodity_segment = user_content.find { |s| s['sid'] == commodity.goods_nomenclature_sid }
          expect(commodity_segment['eu_self_text']).to eq('Pure-bred breeding horses')
        end
      end

      it 'includes eu_self_text in input_context for cache invalidation' do
        result

        record = GoodsNomenclatureSelfText[commodity.goods_nomenclature_sid]
        expect(record.input_context['eu_self_text']).to eq('Pure-bred breeding horses')
      end
    end

    context 'when eu_self_text is not available' do
      it 'omits eu_self_text from input_context' do
        result

        record = GoodsNomenclatureSelfText[commodity.goods_nomenclature_sid]
        expect(record.input_context).not_to have_key('eu_self_text')
      end
    end

    context 'when AI returns empty response' do
      before do
        allow(ai_client).to receive(:call).and_return('')
      end

      it 'increments failed count' do
        expect(result[:failed]).to eq(2)
      end
    end

    context 'with idempotent runs' do
      it 'does not update records when context is unchanged' do
        described_class.call(chapter)

        record = GoodsNomenclatureSelfText[commodity.goods_nomenclature_sid]
        original_updated_at = record.updated_at

        travel_to(1.hour.from_now) do
          described_class.call(chapter)
        end

        record.refresh
        expect(record.updated_at).to eq(original_updated_at)
      end
    end

    context 'with a manually edited record' do
      it 'preserves the manually edited self-text' do
        described_class.call(chapter)

        record = GoodsNomenclatureSelfText[commodity.goods_nomenclature_sid]
        record.update(manually_edited: true, self_text: 'Manually written text')

        described_class.call(chapter)

        record.refresh
        expect(record.self_text).to eq('Manually written text')
        expect(record.manually_edited).to be true
      end
    end

    context 'when records already exist with matching context' do
      it 'skips unchanged records on second run' do
        described_class.call(chapter)

        RSpec::Mocks.space.proxy_for(ai_client).reset
        allow(TradeTariffBackend).to receive(:ai_client).and_return(ai_client)
        allow(ai_client).to receive(:call)

        second_result = described_class.call(chapter)

        expect(second_result[:skipped]).to eq(2)
        expect(second_result[:processed]).to eq(0)
        expect(ai_client).not_to have_received(:call)
      end
    end

    context 'when an existing record is stale' do
      it 'reprocesses stale records' do
        described_class.call(chapter)

        record = GoodsNomenclatureSelfText[commodity.goods_nomenclature_sid]
        record.update(stale: true)

        second_result = described_class.call(chapter)
        expect(second_result[:processed]).to be >= 1
      end
    end

    context 'without siblings in segment JSON' do
      it 'omits siblings key' do
        result

        expect(ai_client).to have_received(:call) do |messages, **_opts|
          user_content = JSON.parse(messages.last[:content])
          user_content.each do |segment|
            expect(segment).not_to have_key('siblings')
          end
        end
      end
    end
  end
end
