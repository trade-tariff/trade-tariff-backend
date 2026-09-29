# spec/services/evaluation/gold_query_generator_spec.rb
require 'rails_helper'

RSpec.describe Evaluation::GoldQueryGenerator do
  subject(:result) { described_class.call(source, set: gold_query_set, ai_client:) }

  let(:ai_client) { instance_double(OpenaiClient) }
  let(:source) { Evaluation::GoldQuerySource.from_public_atar_ruling(ruling) }
  let(:gold_query_set) { create(:evaluation_gold_query_set, created_by: 'user-123') }
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

  def accepted_tiers
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

    it 'stores each row in the set, with the source text as its oracle text' do
      result

      rows = EvaluationGoldQuery.where(source_id: '600014988').all
      expect(rows.map(&:set_id).uniq).to eq([gold_query_set.id])
      expect(rows.map(&:oracle_text).uniq).to eq(['Bed linen woven from cotton fabric, printed with a floral pattern.'])
    end

    it 'records the generated text as version 1 of each row, naming the person who asked for the set' do
      result

      rows = EvaluationGoldQuery.where(source_id: '600014988').all
      expect(rows.size).to eq(3)
      rows.each do |row|
        expect(row.versions.map(&:event)).to eq(%w[create])
        expect(row.versions.first.whodunnit).to eq('user-123')
        expect(row.versions.first.object.to_h).to include('query' => row.query, 'set_id' => gold_query_set.id)
      end
    end

    context 'when the ATaR ruling only classified to heading level (8 digits, not a full 10-digit leaf)' do
      let(:ruling) do
        create(
          :tariff_knowledge_public_atar_ruling,
          ref: '600014988',
          commodity_code: '63021000',
          description: 'Bed linen woven from cotton fabric, printed with a floral pattern.',
          justification: 'Classified in accordance with GIR 1.',
        )
      end

      it 'stores expected_code at the ruling\'s native 8-digit granularity, never right-padded to a 10-digit leaf' do
        result

        rows = EvaluationGoldQuery.where(source_type: 'atar', source_id: '600014988').all
        # Must equal the RAW ruling.commodity_code, never ruling.goods_nomenclature_item_id
        # (the DB-level right-padded value) — right-padding an 8-digit code can land on a
        # non-declarable intermediate node with several declarable descendants, which
        # would silently become the wrong exact-match target for anything scoring against
        # this row later (e.g. AI-1073). expected_code_digits (see EvaluationGoldQuery)
        # is how a consumer is meant to detect this, not by inferring it from length
        # themselves.
        expect(rows.map(&:expected_code).uniq).to eq(%w[63021000])
        expect(rows.first.expected_code_digits).to eq(8)
        expect(ruling.goods_nomenclature_item_id).to eq('6302100000') # sanity: DB-level padding exists but is NOT what got persisted
      end
    end

    it 'calls the AI client once with the tiered prompt and the labelled ATaR description' do
      result

      expect(ai_client).to have_received(:call).once.with(
        array_including(
          hash_including(role: 'system', content: a_string_including('GENERIC tier', 'ORDINARY tier', 'SPECIFIC tier')),
          hash_including(role: 'user', content: 'Description: Bed linen woven from cotton fabric, printed with a floral pattern.'),
        ),
        model: 'gpt-5-mini-2025-08-07',
        event_kind: 'evaluation_gold_query_generation',
        timeout: 60,
      )
    end

    it 'leaves out the real search paragraph, because an ATaR has no real user search' do
      result

      expect(ai_client).to have_received(:call) do |messages, **|
        expect(messages.first[:content]).not_to include('real user typed')
        expect(messages.last[:content]).not_to include('Real user search')
      end
    end
  end

  context 'with a synthetic ATaR as the source' do
    let(:synthetic_atar) do
      create(
        :tariff_knowledge_synthetic_atar,
        real_user_search: 'lunch box',
        description: 'Plastic lunch box with a lid, for carrying food.',
        goods_nomenclature_item_id: '3924100000',
      )
    end
    let(:source) { Evaluation::GoldQuerySource.from_synthetic_atar(synthetic_atar) }

    def synthetic_tiers
      { 'generic' => 'food box', 'ordinary' => 'plastic food container', 'specific' => 'plastic lunch box with clip lid' }
    end

    before { allow(ai_client).to receive(:call).and_return(synthetic_tiers) }

    it 'sends the real user search and the description as two labelled lines' do
      result

      expect(ai_client).to have_received(:call).once.with(
        array_including(
          hash_including(role: 'user', content: "Real user search: lunch box\nDescription: Plastic lunch box with a lid, for carrying food."),
        ),
        model: 'gpt-5-mini-2025-08-07',
        event_kind: 'evaluation_gold_query_generation',
        timeout: 60,
      )
    end

    it 'adds the real search paragraph to the system prompt, after the normal prompt' do
      result

      expect(ai_client).to have_received(:call) do |messages, **|
        system_prompt = messages.first[:content]
        expect(system_prompt).to start_with(described_class::SYSTEM_PROMPT)
        expect(system_prompt).to end_with(described_class::REAL_SEARCH_NOTE)
        expect(system_prompt).to include('a real user typed into the tariff search')
      end
    end

    it 'persists 3 rows for the synthetic ATaR, using its id as the source id' do
      result

      rows = EvaluationGoldQuery.where(source_type: 'synthetic_atar', source_id: synthetic_atar.id.to_s).order(:persona).all
      expect(rows.map(&:persona)).to eq(%w[emu_generic emu_ordinary emu_specific])
      expect(rows.map(&:expected_code).uniq).to eq(%w[3924100000])
    end

    it 'does not count a phrase that repeats the real search as leaked source text' do
      allow(ai_client).to receive(:call).and_return(synthetic_tiers.merge('generic' => 'lunch box'))

      expect(result).to include('generic' => 'lunch box')
    end

    context 'when a phrase copies the start of the description' do
      let(:synthetic_atar) do
        create(:tariff_knowledge_synthetic_atar, real_user_search: 'lunch box', description: 'Plastic lunch box with a clip lid for food')
      end

      it 'is still rejected (the leak check reads the description, as it does for an ATaR)' do
        allow(ai_client).to receive(:call).and_return(synthetic_tiers.merge('specific' => 'plastic lunch box with a clip lid for food'))

        expect(result).to be_nil
      end
    end
  end

  context 'when the same set already has a row for one persona (a retried job)' do
    let!(:existing) do
      create(
        :evaluation_gold_query,
        evaluation_gold_query_set: gold_query_set,
        source_type: 'atar',
        source_id: '600014988',
        persona: 'emu_specific',
        query: 'previously approved query',
      )
    end

    before { allow(ai_client).to receive(:call).and_return(accepted_tiers) }

    it 'leaves that row untouched, and its history, instead of overwriting it' do
      expect { result }.not_to(change { existing.versions.count })

      expect(existing.reload.query).to eq('previously approved query')
    end

    it 'still creates the other two rows, without duplicating the existing one' do
      result

      rows = EvaluationGoldQuery.where(source_id: '600014988').order(:persona).all
      expect(rows.map(&:persona)).to eq(%w[emu_generic emu_ordinary emu_specific])
    end
  end

  context 'when the same source item is already in another set' do
    before do
      create(:evaluation_gold_query, source_type: 'atar', source_id: '600014988', persona: 'emu_generic', query: 'another sets query')
      allow(ai_client).to receive(:call).and_return(accepted_tiers)
    end

    it 'creates its own rows, because each set owns its rows' do
      result

      expect(EvaluationGoldQuery.where(source_id: '600014988').count).to eq(4)
      expect(EvaluationGoldQuery.where(source_id: '600014988', set_id: gold_query_set.id).count).to eq(3)
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
      expect(Rails.logger).to have_received(:warn).with(/Gold query generation failed for atar 600014988/).exactly(3).times
      expect(Rails.logger).to have_received(:warn).with(/status=500/).exactly(3).times
    end
  end

  context 'when the AI client exceeds its per-attempt deadline on every attempt' do
    before do
      allow(ai_client).to receive(:call).and_raise(
        OpenaiClient::DeadlineExceeded.new(timeout_seconds: 60, elapsed_seconds: 60.4),
      )
      allow(Rails.logger).to receive(:warn)
    end

    it 'returns nil without raising (DeadlineExceeded is not a raw RETRYABLE_ERRORS member), and logs the elapsed time' do
      expect(result).to be_nil
      expect(ai_client).to have_received(:call).exactly(3).times
      expect(Rails.logger).to have_received(:warn).with(/elapsed=60\.4s/).exactly(3).times
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
      expect(Version.where(item_type: 'EvaluationGoldQuery').count).to eq(0)
    end
  end

  context 'when the GENERIC tier is a single word' do
    before { allow(ai_client).to receive(:call).and_return(accepted_tiers.merge('generic' => 'linen')) }

    it 'accepts it, matching the system prompt allowing 1-3 words for GENERIC' do
      expect(result).to eq(accepted_tiers.merge('generic' => 'linen'))
    end
  end

  context 'when the ORDINARY tier is a single word' do
    before { allow(ai_client).to receive(:call).and_return(accepted_tiers.merge('ordinary' => 'linen')) }

    it 'rejects it — ORDINARY requires 2-6 words, unlike GENERIC' do
      expect(result).to be_nil
    end
  end

  context 'when the SPECIFIC tier is only 3 words' do
    before { allow(ai_client).to receive(:call).and_return(accepted_tiers.merge('specific' => 'printed cotton linen')) }

    it 'rejects it — SPECIFIC requires 4-10 words' do
      expect(result).to be_nil
    end
  end

  context 'when two tiers come back identical' do
    before do
      allow(ai_client).to receive(:call).and_return(accepted_tiers.merge('ordinary' => 'printed cotton bed linen set'))
    end

    it 'rejects the whole attempt even though each tier individually passes its own filter' do
      expect(result).to be_nil
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

    context 'when a heading number is glued directly onto a letter prefix, with no space' do
      let(:rejected_generic) { 'HS6302 linen' }

      it 'still rejects it (a 4+ digit run is forbidden regardless of what immediately precedes it)' do
        expect(result).to be_nil
      end
    end

    context 'when a CN code is glued directly onto its prefix, with no space' do
      let(:rejected_generic) { 'CN6302 linen' }

      it 'still rejects it' do
        expect(result).to be_nil
      end
    end

    context 'when "heading" is glued directly onto its number, with no space' do
      let(:rejected_generic) { 'heading6302 linen' }

      it 'still rejects it' do
        expect(result).to be_nil
      end
    end

    context 'when a tier contains a full CAS registry number' do
      let(:rejected_generic) { 'CAS 50-00-0 dye' }

      it 'rejects it (the whole hyphenated number is consumed, not just its first digit)' do
        expect(result).to be_nil
      end
    end

    context 'when a tier contains the banned word "other"' do
      let(:rejected_generic) { 'other linen' }

      it 'rejects the whole attempt, matching SYSTEM_PROMPT explicitly banning it' do
        expect(result).to be_nil
      end
    end
  end

  context 'when a tier value is not a String' do
    before { allow(ai_client).to receive(:call).and_return(accepted_tiers.merge('generic' => %w[linen])) }

    it 'rejects the whole attempt instead of coercing it into a fake-looking query' do
      expect(result).to be_nil
      expect(EvaluationGoldQuery.where(source_id: '600014988').count).to eq(0)
    end
  end

  context 'when a tier value is a number' do
    before { allow(ai_client).to receive(:call).and_return(accepted_tiers.merge('generic' => 123)) }

    it 'rejects the whole attempt instead of coercing it into a fake-looking query' do
      expect(result).to be_nil
    end
  end
end
