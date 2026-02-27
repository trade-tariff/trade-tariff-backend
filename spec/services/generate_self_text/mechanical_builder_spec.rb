RSpec.describe GenerateSelfText::MechanicalBuilder do
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

    before do
      commodity
    end

    it 'builds self-text by joining ancestor descriptions with node description' do
      result

      expect(self_text_for_sid(commodity.goods_nomenclature_sid))
        .to eq('Live animals >> Live horses >> Pure-bred breeding animals')
    end

    it 'builds self-text for the heading' do
      result

      expect(self_text_for_sid(heading.goods_nomenclature_sid))
        .to eq('Live animals >> Live horses')
    end

    it 'builds self-text for the chapter as its own description' do
      result

      expect(self_text_for_sid(chapter.goods_nomenclature_sid))
        .to eq('Live animals')
    end

    it 'sets generation_type to mechanical' do
      result

      record = GoodsNomenclatureSelfText[commodity.goods_nomenclature_sid]

      expect(record.generation_type).to eq('mechanical')
    end

    it 'stores input_context as JSONB with ancestors and description' do
      result

      record = GoodsNomenclatureSelfText[commodity.goods_nomenclature_sid]
      context = record.input_context

      expect(context['ancestors']).to eq([
        { 'sid' => chapter.goods_nomenclature_sid, 'description' => 'Live animals' },
        { 'sid' => heading.goods_nomenclature_sid, 'description' => 'Live horses' },
      ])
      expect(context['description']).to eq('Pure-bred breeding animals')
    end

    it 'computes a SHA256 context_hash from the input context' do
      result

      record = GoodsNomenclatureSelfText[commodity.goods_nomenclature_sid]
      expected_hash = Digest::SHA256.hexdigest(JSON.generate(record.input_context))

      expect(record.context_hash).to eq(expected_hash)
    end

    it 'returns processed, skipped_other, skipped_ai_non_other, and skipped counts' do
      expect(result).to eq({ processed: 3, skipped_other: 0, skipped_ai_non_other: 0, skipped: 0 })
    end

    context 'with a chapter that has no descendants' do
      let(:heading) { nil }
      let(:commodity) { nil }

      before { chapter }

      it 'creates a single self-text for the chapter' do
        result

        expect(self_text_for_sid(chapter.goods_nomenclature_sid))
          .to eq('Live animals')
      end

      it 'returns correct stats' do
        expect(result).to eq({ processed: 1, skipped_other: 0, skipped_ai_non_other: 0, skipped: 0 })
      end
    end

    context 'with "Other" nodes' do
      let(:other_commodity) do
        create(:commodity, :with_description,
               description: 'Other',
               parent: heading)
      end

      before do
        other_commodity
      end

      it 'skips "Other" nodes' do
        result

        expect(GoodsNomenclatureSelfText[other_commodity.goods_nomenclature_sid]).to be_nil
      end

      it 'includes skipped_other in stats' do
        expect(result).to eq({ processed: 3, skipped_other: 1, skipped_ai_non_other: 0, skipped: 0 })
      end
    end

    context 'with an "Other" ancestor that has no self-text' do
      let(:other_heading) do
        create(:heading, :with_description,
               description: 'Other',
               parent: chapter)
      end

      let(:commodity_under_other) do
        create(:commodity, :with_description,
               description: 'Widgets',
               parent: other_heading)
      end

      before do
        commodity_under_other
      end

      it 'skips the bare "Other" ancestor in the chain' do
        result

        expect(self_text_for_sid(commodity_under_other.goods_nomenclature_sid))
          .to eq('Live animals >> Widgets')
      end
    end

    context 'with an "Other" ancestor that has a generated self-text' do
      let(:other_heading) do
        create(:heading, :with_description,
               description: 'Other',
               parent: chapter)
      end

      let(:commodity_under_other) do
        create(:commodity, :with_description,
               description: 'Widgets',
               parent: other_heading)
      end

      before do
        create(:goods_nomenclature_self_text,
               goods_nomenclature: other_heading,
               self_text: 'Live animals >> Other live animals',
               generation_type: 'ai')

        commodity_under_other
      end

      it 'uses the Other ancestor self-text in the chain' do
        result

        expect(self_text_for_sid(commodity_under_other.goods_nomenclature_sid))
          .to eq('Live animals >> Other live animals >> Widgets')
      end

      it 'includes the Other self-text in input_context' do
        result

        record = GoodsNomenclatureSelfText[commodity_under_other.goods_nomenclature_sid]
        other_ancestor = record.input_context['ancestors'].find { |a| a['sid'] == other_heading.goods_nomenclature_sid }

        expect(other_ancestor['self_text']).to eq('Live animals >> Other live animals')
      end
    end

    context 'with nested "Other" ancestors' do
      let(:other_heading) do
        create(:heading, :with_description,
               description: 'Other',
               parent: chapter)
      end

      let(:other_subheading) do
        create(:commodity, :with_description,
               description: 'Other',
               parent: other_heading,
               producline_suffix: '10')
      end

      let(:leaf_commodity) do
        create(:commodity, :with_description,
               description: 'Gadgets',
               parent: other_subheading)
      end

      before do
        create(:goods_nomenclature_self_text,
               goods_nomenclature: other_heading,
               self_text: 'Live animals >> Other live animals',
               generation_type: 'ai')

        create(:goods_nomenclature_self_text,
               goods_nomenclature: other_subheading,
               self_text: 'Live animals >> Other live animals >> Other gadgets',
               generation_type: 'ai')

        leaf_commodity
      end

      it 'uses the nearest Other ancestor self-text' do
        result

        expect(self_text_for_sid(leaf_commodity.goods_nomenclature_sid))
          .to eq('Live animals >> Other live animals >> Other gadgets >> Gadgets')
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

    context 'with a stale record' do
      it 'clears staleness on regeneration' do
        described_class.call(chapter)

        record = GoodsNomenclatureSelfText[commodity.goods_nomenclature_sid]
        record.update(stale: true)

        # Change context so the update_where condition allows update
        record.update(context_hash: 'outdated_hash', manually_edited: false)

        described_class.call(chapter)

        record.refresh
        expect(record.stale).to be false
      end
    end

    context 'when records already exist with matching context' do
      it 'skips unchanged records on second run' do
        first_result = described_class.call(chapter)
        expect(first_result[:processed]).to eq(3)

        second_result = described_class.call(chapter)
        expect(second_result[:skipped]).to eq(3)
        expect(second_result[:processed]).to eq(0)
      end

      it 'still populates generated_texts for downstream nodes' do
        described_class.call(chapter)

        # Second run should still produce the same self_text values
        second_result = described_class.call(chapter)
        expect(second_result[:skipped]).to eq(3)

        expect(GoodsNomenclatureSelfText[commodity.goods_nomenclature_sid].self_text)
          .to eq('Live animals >> Live horses >> Pure-bred breeding animals')
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

    context 'with an existing ai_non_other record' do
      before do
        create(:goods_nomenclature_self_text,
               goods_nomenclature: commodity,
               self_text: 'AI-generated pure-bred breeding horses',
               generation_type: 'ai_non_other')
      end

      it 'skips nodes with ai_non_other generation_type' do
        expect(result[:skipped_ai_non_other]).to be >= 1
      end

      it 'does not overwrite the ai_non_other record' do
        result

        record = GoodsNomenclatureSelfText[commodity.goods_nomenclature_sid]
        expect(record.generation_type).to eq('ai_non_other')
        expect(record.self_text).to eq('AI-generated pure-bred breeding horses')
      end
    end

    def self_text_for_sid(sid)
      GoodsNomenclatureSelfText[sid]&.self_text
    end
  end
end
