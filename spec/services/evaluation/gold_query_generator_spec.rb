# spec/services/evaluation/gold_query_generator_spec.rb
require 'rails_helper'

RSpec.describe Evaluation::GoldQueryGenerator do
  subject(:result) { described_class.call(ruling, ai_client:) }

  let(:ai_client) { instance_double(OpenaiClient) }
  let(:ruling) do
    create(
      :tariff_knowledge_public_atar_ruling,
      ref: '600014988',
      commodity_code: '6302100000',
      goods_nomenclature_item_id: '6302100000',
      description: 'Bed linen woven from cotton fabric, printed with a floral pattern.',
      justification: 'Classified in accordance with GIR 1.',
    )
  end
  let(:accepted_tiers) do
    { 'generic' => 'bed linen', 'ordinary' => 'cotton bed sheets', 'specific' => 'printed cotton bed linen set' }
  end

  before do
    gn = create(:goods_nomenclature, goods_nomenclature_item_id: '6302100000', validity_start_date: 3.years.ago)
    # Two description periods for the same code, out of insertion order and with no
    # ORDER BY in a naive query these could come back in either order — the older one
    # must never win, so give it a lower period sid and different text.
    create(
      :goods_nomenclature_description,
      goods_nomenclature_sid: gn.goods_nomenclature_sid,
      goods_nomenclature_item_id: gn.goods_nomenclature_item_id,
      goods_nomenclature_description_period_sid: 1,
      description: 'Old bed linen description',
      validity_start_date: 3.years.ago,
      validity_end_date: 1.year.ago,
    )
    create(
      :goods_nomenclature_description,
      goods_nomenclature_sid: gn.goods_nomenclature_sid,
      goods_nomenclature_item_id: gn.goods_nomenclature_item_id,
      goods_nomenclature_description_period_sid: 2,
      description: 'Bed linen, of cotton',
      validity_start_date: 1.year.ago,
      validity_end_date: nil,
    )
  end

  context 'when the model returns 3 acceptable tiers on the first attempt' do
    before { allow(ai_client).to receive(:call).and_return(accepted_tiers) }

    it 'returns the cleaned tiers' do
      expect(result).to eq(accepted_tiers)
    end

    it 'persists 3 gold query rows with the expected persona mapping' do
      result

      rows = EvaluationGoldQuery.where(source_type: 'atar', source_id: '600014988').order(:persona).all
      expect(rows.map(&:persona)).to eq(%w[emu_generic emu_ordinary emu_specific])
      expect(rows.map(&:query)).to eq(['bed linen', 'cotton bed sheets', 'printed cotton bed linen set'])
      expect(rows.map(&:expected_code).uniq).to eq(%w[6302100000])
      # Must be the newer description period's text (sid 2), never the older one (sid 1),
      # regardless of insertion order or database row ordering.
      expect(rows.map(&:expected_description).uniq).to eq(['Bed linen, of cotton'])
      expect(rows.map(&:generator).uniq).to eq(['gpt-5-mini-2025-08-07'])
    end

    it 'calls the AI client once with the tiered prompt and the ATaR description' do
      result

      expect(ai_client).to have_received(:call).once.with(
        array_including(
          hash_including(role: 'system', content: a_string_including('GENERIC tier', 'ORDINARY tier', 'SPECIFIC tier')),
          hash_including(role: 'user', content: a_string_including('Bed linen woven from cotton fabric')),
        ),
        model: 'gpt-5-mini-2025-08-07',
        event_kind: 'evaluation_gold_query_generation',
      )
    end
  end

  context 'when an existing row for a persona is inactive' do
    before do
      create(
        :evaluation_gold_query,
        source_type: 'atar',
        source_id: '600014988',
        persona: 'emu_specific',
        query: 'stale rejected query',
        expected_code: '0000000000',
        active: false,
      )
      allow(ai_client).to receive(:call).and_return(accepted_tiers)
    end

    it 'reactivates the row and overwrites it with the fresh generation' do
      result

      row = EvaluationGoldQuery.where(source_type: 'atar', source_id: '600014988', persona: 'emu_specific').first
      expect(row.active).to be(true)
      expect(row.query).to eq('printed cotton bed linen set')
      expect(row.expected_code).to eq('6302100000')
    end
  end

  context 'when an existing row for a persona is already active' do
    before do
      create(
        :evaluation_gold_query,
        source_type: 'atar',
        source_id: '600014988',
        persona: 'emu_specific',
        query: 'previously approved query',
        expected_code: '6302100000',
      )
      allow(ai_client).to receive(:call).and_return(accepted_tiers)
    end

    it 'leaves the active row untouched instead of overwriting it with a new generation' do
      result

      row = EvaluationGoldQuery.where(source_type: 'atar', source_id: '600014988', persona: 'emu_specific').first
      expect(row.query).to eq('previously approved query')
    end
  end

  context 'when the commodity code has no matching goods_nomenclature_description row' do
    let(:ruling) do
      create(
        :tariff_knowledge_public_atar_ruling,
        ref: '600014989',
        commodity_code: '9999999999',
        goods_nomenclature_item_id: '9999999999',
        description: 'Some item with no matching commodity description in the database.',
        justification: 'Classified in accordance with GIR 1.',
      )
    end

    before { allow(ai_client).to receive(:call).and_return(accepted_tiers) }

    it 'persists nil (not an empty string) for expected_description' do
      result

      rows = EvaluationGoldQuery.where(source_type: 'atar', source_id: '600014989').all
      expect(rows).to be_present
      expect(rows.map(&:expected_description).uniq).to eq([nil])
    end
  end

  context 'when the first attempt fails the acceptability filter and the second succeeds' do
    before do
      allow(ai_client).to receive(:call).and_return(
        { 'generic' => 'excluding bed linen', 'ordinary' => 'cotton bed sheets', 'specific' => 'printed cotton bed linen set' },
        accepted_tiers,
      )
    end

    it 'retries and returns the tiers from the successful attempt' do
      expect(result).to eq(accepted_tiers)
      expect(ai_client).to have_received(:call).twice
    end
  end

  context 'when every attempt fails the acceptability filter' do
    before do
      allow(ai_client).to receive(:call).and_return(
        { 'generic' => 'chapter 63 item', 'ordinary' => 'chapter 63 bed linen', 'specific' => 'chapter 63 cotton bed linen set' },
      )
    end

    it 'returns nil after 3 attempts and persists nothing' do
      expect(result).to be_nil
      expect(ai_client).to have_received(:call).exactly(3).times
      expect(EvaluationGoldQuery.where(source_id: '600014988').count).to eq(0)
    end
  end

  context 'when the AI client raises a retryable error on every attempt' do
    before do
      allow(ai_client).to receive(:call).and_raise(OpenaiClient::ApiError.new(status: 500, body: 'nope'))
      allow(Rails.logger).to receive(:warn)
    end

    it 'returns nil without raising, and logs a warning including the HTTP status' do
      expect(result).to be_nil
      expect(Rails.logger).to have_received(:warn).with(/Gold query generation failed for ATaR 600014988/).exactly(3).times
      expect(Rails.logger).to have_received(:warn).with(/status=500/).exactly(3).times
    end
  end

  context 'when persisting fails partway through the tiers' do
    before do
      allow(ai_client).to receive(:call).and_return(accepted_tiers)

      # EvaluationGoldQuery.dataset is a frozen Sequel::Dataset, so it can't be stubbed
      # directly. Wrap it in a plain delegator and stub the wrapper instead, forwarding
      # to the real dataset except on the 2nd insert_conflict call (the 'ordinary' tier),
      # which simulates a connection blip partway through the 3-insert loop.
      real_dataset = EvaluationGoldQuery.dataset
      wrapped_dataset = SimpleDelegator.new(real_dataset)
      call_count = 0
      allow(wrapped_dataset).to receive(:insert_conflict) do |*args|
        call_count += 1
        raise Sequel::DatabaseError, 'connection blip' if call_count == 2

        real_dataset.insert_conflict(*args)
      end
      allow(EvaluationGoldQuery).to receive(:dataset).and_return(wrapped_dataset)
    end

    it 'rolls back the whole batch instead of leaving partial persona rows for a single generation' do
      expect { result }.to raise_error(Sequel::DatabaseError)
      expect(EvaluationGoldQuery.where(source_type: 'atar', source_id: '600014988').count).to eq(0)
    end
  end

  context 'when the GENERIC tier is a single word' do
    before { allow(ai_client).to receive(:call).and_return(accepted_tiers.merge('generic' => 'linen')) }

    it 'accepts it, matching the system prompt allowing 1-3 words for GENERIC' do
      expect(result).to eq(accepted_tiers.merge('generic' => 'linen'))
    end
  end

  describe 'the acceptability filter' do
    before { allow(ai_client).to receive(:call).and_return(accepted_tiers.merge('generic' => rejected_generic)) }

    context 'when a tier contains a forbidden token' do
      let(:rejected_generic) { 'excluding bed linen' }

      it 'rejects the whole attempt' do
        expect(result).to be_nil
      end
    end

    context 'when a tier is over the word limit' do
      let(:rejected_generic) { 'a b c d e f g h i j k l m' }

      it 'rejects the whole attempt' do
        expect(result).to be_nil
      end
    end

    context 'when a tier contains a 4+ digit number' do
      let(:rejected_generic) { 'linen 6302 fabric' }

      it 'rejects the whole attempt' do
        expect(result).to be_nil
      end
    end
  end
end
