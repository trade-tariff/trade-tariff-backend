RSpec.describe GenerateSelfText::AiBuilder do
  describe '.call' do
    subject(:result) { described_class.call(chapter) }

    let(:chapter) { create(:chapter, :with_description, description: 'Live animals') }

    let(:heading) do
      create(:heading, :with_description,
             description: 'Live horses',
             parent: chapter)
    end

    let(:other_commodity) do
      create(:commodity, :with_description,
             description: 'Other',
             parent: heading)
    end

    let(:named_sibling) do
      create(:commodity, :with_description,
             description: 'Pure-bred breeding animals',
             parent: heading)
    end

    let(:ai_client) { instance_double(OpenaiClient) }
    let(:system_prompt_text) { 'You are an expert in the UK Trade Tariff.' }
    let(:seed_self_text_context) { true }

    let(:successful_response) do
      {
        'descriptions' => [
          {
            'sid' => other_commodity.goods_nomenclature_sid,
            'contextualised_description' => 'Live horses (excl. pure-bred for breeding)',
            'excluded_siblings' => ['Pure-bred breeding animals'],
          },
        ],
      }.to_json
    end

    before do
      named_sibling
      other_commodity

      if seed_self_text_context
        create(:admin_configuration,
               name: 'self_text_context',
               config_type: 'markdown',
               description: 'System prompt for self-text generation',
               value: system_prompt_text)
      end

      create(:admin_configuration,
             name: 'self_text_model',
             config_type: 'options',
             description: 'AI model for self-text generation',
             value: { 'selected' => 'gpt-4.1-mini-2025-04-14', 'options' => [{ 'key' => 'gpt-4.1-mini-2025-04-14' }] })

      create(:admin_configuration,
             name: 'self_text_batch_size',
             config_type: 'integer',
             description: 'Batch size for AI self-text generation',
             value: '5')

      allow(TradeTariffBackend).to receive(:ai_client).and_return(ai_client)
      allow(ai_client).to receive(:call).and_return(successful_response)
    end

    it 'stores the AI-generated self-text' do
      result

      record = GoodsNomenclatureSelfText[other_commodity.goods_nomenclature_sid]
      expect(record.self_text).to eq('Live horses (excl. pure-bred for breeding)')
    end

    it 'sets generation_type to ai' do
      result

      record = GoodsNomenclatureSelfText[other_commodity.goods_nomenclature_sid]
      expect(record.generation_type).to eq('ai')
    end

    it 'returns correct stats for a successful run' do
      expect(result).to eq({ processed: 1, failed: 0, needs_review: 0 })
    end

    context 'when non-Other nodes exist' do
      it 'only sends Other nodes to AI' do
        result

        expect(ai_client).to have_received(:call).once

        # The chapter and heading are non-Other, only the Other commodity should be sent
        expect(GoodsNomenclatureSelfText[chapter.goods_nomenclature_sid]).to be_nil
        expect(GoodsNomenclatureSelfText[heading.goods_nomenclature_sid]).to be_nil
        expect(GoodsNomenclatureSelfText[other_commodity.goods_nomenclature_sid]).not_to be_nil
      end
    end

    context 'with batch sizing' do
      let(:other_commodities) do
        Array.new(6) do
          create(:commodity, :with_description,
                 description: 'Other',
                 parent: heading)
        end
      end

      before do
        allow(AdminConfiguration).to receive(:integer_value)
          .with('self_text_batch_size').and_return(3)

        other_commodities

        allow(ai_client).to receive(:call) do |messages, **_opts|
          user_content = JSON.parse(messages.last[:content])
          sids = user_content.map { |s| s['sid'] }

          {
            'descriptions' => sids.map do |sid|
              {
                'sid' => sid,
                'contextualised_description' => "Generated for #{sid}",
                'excluded_siblings' => ['Pure-bred breeding animals'],
              }
            end,
          }.to_json
        end
      end

      it 'sends 3 AI calls for 7 Other nodes with batch_size=3' do
        result

        # 7 Other nodes (6 new + 1 original), batch_size=3 => ceil(7/3) = 3 calls
        expect(ai_client).to have_received(:call).exactly(3).times
      end
    end

    context 'when AI response has correct excluded_siblings count' do
      it 'sets needs_review to false' do
        result

        record = GoodsNomenclatureSelfText[other_commodity.goods_nomenclature_sid]
        expect(record.needs_review).to be false
      end
    end

    context 'when AI response has wrong sibling count' do
      let(:successful_response) do
        {
          'descriptions' => [
            {
              'sid' => other_commodity.goods_nomenclature_sid,
              'contextualised_description' => 'Live horses (excl. pure-bred for breeding, donkeys)',
              'excluded_siblings' => ['Pure-bred breeding animals', 'Donkeys'],
            },
          ],
        }.to_json
      end

      it 'sets needs_review to true but still stores the self-text' do
        result

        record = GoodsNomenclatureSelfText[other_commodity.goods_nomenclature_sid]
        expect(record.needs_review).to be true
        expect(record.self_text).to eq('Live horses (excl. pure-bred for breeding, donkeys)')
      end

      it 'increments needs_review count' do
        expect(result[:needs_review]).to eq(1)
      end
    end

    context 'when AI returns empty response' do
      before do
        allow(ai_client).to receive(:call).and_return('')
      end

      it 'increments failed count' do
        expect(result[:failed]).to eq(1)
      end

      it 'does not create a record' do
        result

        expect(GoodsNomenclatureSelfText[other_commodity.goods_nomenclature_sid]).to be_nil
      end
    end

    context 'when AI returns malformed response (not a hash)' do
      before do
        allow(ai_client).to receive(:call).and_return('not json at all')
      end

      it 'increments failed count' do
        expect(result[:failed]).to eq(1)
      end
    end

    context 'when AI returns fewer descriptions than targets' do
      let(:other_commodity2) do
        create(:commodity, :with_description,
               description: 'Other',
               parent: heading)
      end

      let(:partial_response) do
        {
          'descriptions' => [
            {
              'sid' => other_commodity.goods_nomenclature_sid,
              'contextualised_description' => 'Live horses (excl. pure-bred for breeding)',
              'excluded_siblings' => ['Pure-bred breeding animals'],
            },
          ],
        }.to_json
      end

      before do
        other_commodity2
        allow(ai_client).to receive(:call).and_return(partial_response)
      end

      it 'counts missing targets as failed' do
        # other_commodity has 2 siblings (named_sibling + other_commodity2) but
        # response only lists 1 excluded_sibling, so needs_review is set
        expect(result).to include(processed: 1, failed: 1)
      end
    end

    context 'with idempotent runs' do
      it 'does not update records when context is unchanged' do
        described_class.call(chapter)

        record = GoodsNomenclatureSelfText[other_commodity.goods_nomenclature_sid]
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

        record = GoodsNomenclatureSelfText[other_commodity.goods_nomenclature_sid]
        record.update(manually_edited: true, self_text: 'Manually written text')

        described_class.call(chapter)

        record.refresh
        expect(record.self_text).to eq('Manually written text')
        expect(record.manually_edited).to be true
      end
    end

    context 'with a cascading Other chain' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      let(:other_heading) do
        create(:heading, :with_description,
               description: 'Other',
               parent: chapter)
      end

      let(:child_under_other) do
        create(:commodity, :with_description,
               description: 'Other',
               parent: other_heading)
      end

      let(:sibling_heading) do
        create(:heading, :with_description,
               description: 'Horses',
               parent: chapter)
      end

      let(:sibling_of_child) do
        create(:commodity, :with_description,
               description: 'Widgets',
               parent: other_heading)
      end

      before do
        sibling_heading
        other_heading
        sibling_of_child
        child_under_other

        call_count = 0
        allow(ai_client).to receive(:call) do |messages, **_opts|
          call_count += 1
          user_content = JSON.parse(messages.last[:content])

          descriptions = user_content.map do |seg|
            {
              'sid' => seg['sid'],
              'contextualised_description' => "Generated from #{seg['parent']}",
              'excluded_siblings' => seg['siblings'],
            }
          end

          { 'descriptions' => descriptions }.to_json
        end
      end

      it 'resolves parent Other before child Other' do
        result

        parent_record = GoodsNomenclatureSelfText[other_heading.goods_nomenclature_sid]
        child_record = GoodsNomenclatureSelfText[child_under_other.goods_nomenclature_sid]

        expect(parent_record).not_to be_nil
        expect(child_record).not_to be_nil
        # Child should see parent's AI-generated text in context
        expect(child_record.self_text).to include('Generated from')
      end
    end

    context 'when pre-loading existing mechanical self-texts from DB' do
      before do
        # Run mechanical builder first to populate ancestor self-texts
        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: chapter.goods_nomenclature_sid,
               goods_nomenclature_item_id: chapter.goods_nomenclature_item_id,
               self_text: 'Live animals',
               generation_type: 'mechanical')

        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: heading.goods_nomenclature_sid,
               goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
               self_text: 'Live animals > Live horses',
               generation_type: 'mechanical')
      end

      it 'populates ancestor context from pre-loaded self-texts' do
        result

        expect(ai_client).to have_received(:call) do |messages, **_opts|
          user_content = JSON.parse(messages.last[:content])
          segment = user_content.first
          expect(segment['ancestor_chain']).to include('Live animals')
        end
      end
    end

    context 'when AdminConfiguration values are used' do
      it 'uses the configured model' do
        result

        expect(ai_client).to have_received(:call).with(
          anything,
          model: 'gpt-4.1-mini-2025-04-14',
        )
      end

      it 'uses the configured system prompt' do
        result

        expect(ai_client).to have_received(:call) do |messages, **_opts|
          system_msg = messages.find { |m| m[:role] == 'system' }
          expect(system_msg[:content]).to eq(system_prompt_text)
        end
      end
    end

    context 'when self_text_context config is missing' do
      let(:seed_self_text_context) { false }

      it 'raises an error with a helpful message' do
        expect { result }.to raise_error(RuntimeError, /self_text_context admin configuration not found/)
      end
    end

    context 'when self_text_model and batch_size configs use defaults' do
      it 'falls back to default model' do
        allow(AdminConfiguration).to receive(:option_value)
          .with('self_text_model').and_return(TradeTariffBackend.ai_model)

        result

        expect(ai_client).to have_received(:call).with(
          anything,
          model: TradeTariffBackend.ai_model,
        )
      end
    end

    context 'with a qualified Other node' do
      let(:other_commodity) do
        create(:commodity, :with_description,
               description: 'Other, fresh or chilled',
               parent: heading)
      end

      let(:successful_response) do
        {
          'descriptions' => [
            {
              'sid' => other_commodity.goods_nomenclature_sid,
              'contextualised_description' => 'Live horses, fresh or chilled (excl. pure-bred for breeding)',
              'excluded_siblings' => ['Pure-bred breeding animals'],
            },
          ],
        }.to_json
      end

      it 'sends qualified Other nodes to AI' do
        result

        record = GoodsNomenclatureSelfText[other_commodity.goods_nomenclature_sid]
        expect(record.self_text).to eq('Live horses, fresh or chilled (excl. pure-bred for breeding)')
      end

      it 'includes the node description in the segment JSON' do
        result

        expect(ai_client).to have_received(:call) do |messages, **_opts|
          user_content = JSON.parse(messages.last[:content])
          segment = user_content.first
          expect(segment['description']).to eq('Other, fresh or chilled')
        end
      end
    end

    def self_text_for_sid(sid)
      GoodsNomenclatureSelfText[sid]&.self_text
    end
  end
end
