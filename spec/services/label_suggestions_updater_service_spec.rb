RSpec.describe LabelSuggestionsUpdaterService do
  let(:commodity) { create(:commodity, :with_description) }

  describe '#call' do
    context 'when label has synonym, brand, and colloquial terms' do
      before do
        create(:goods_nomenclature_label,
               goods_nomenclature: commodity,
               labels: {
                 'known_brands' => %w[Acme Globex],
                 'colloquial_terms' => %w[widget],
                 'synonyms' => %w[gadget],
               },
               known_brands: Sequel.pg_array(%w[Acme Globex], :text),
               colloquial_terms: Sequel.pg_array(%w[widget], :text),
               synonyms: Sequel.pg_array(%w[gadget], :text))
      end

      it 'creates search suggestions for all label terms' do
        expect {
          described_class.new(commodity).call
        }.to change(SearchSuggestion, :count).by(4)
      end

      it 'creates suggestions with correct types' do
        described_class.new(commodity).call

        types = SearchSuggestion
          .where(goods_nomenclature_sid: commodity.goods_nomenclature_sid)
          .where(type: LabelSuggestionsUpdaterService::LABEL_TYPES)
          .select_map(:type)

        expect(types).to contain_exactly(
          'known_brand', 'known_brand', 'colloquial_term', 'synonym'
        )
      end

      it 'lowercases and strips term values' do
        described_class.new(commodity).call

        values = SearchSuggestion
          .where(goods_nomenclature_sid: commodity.goods_nomenclature_sid)
          .where(type: 'known_brand')
          .select_map(:value)

        expect(values).to contain_exactly('acme', 'globex')
      end
    end

    context 'when old suggestions exist and label terms change' do
      before do
        create(:goods_nomenclature_label,
               goods_nomenclature: commodity,
               labels: {
                 'known_brands' => [],
                 'colloquial_terms' => [],
                 'synonyms' => %w[old-synonym],
               },
               known_brands: Sequel.pg_array([], :text),
               colloquial_terms: Sequel.pg_array([], :text),
               synonyms: Sequel.pg_array(%w[old-synonym], :text))

        described_class.new(commodity).call
      end

      it 'removes old label suggestions and inserts new ones' do
        expect(
          SearchSuggestion
            .where(goods_nomenclature_sid: commodity.goods_nomenclature_sid, type: 'synonym')
            .select_map(:value),
        ).to eq(%w[old-synonym])

        # Update the label directly
        label = GoodsNomenclatureLabel
          .where(goods_nomenclature_sid: commodity.goods_nomenclature_sid)
          .first
        label.update(
          labels: Sequel.pg_jsonb({
            'known_brands' => [],
            'colloquial_terms' => [],
            'synonyms' => %w[new-synonym],
          }),
          synonyms: Sequel.pg_array(%w[new-synonym], :text),
        )

        described_class.new(commodity).call

        values = SearchSuggestion
          .where(goods_nomenclature_sid: commodity.goods_nomenclature_sid, type: 'synonym')
          .select_map(:value)

        expect(values).to eq(%w[new-synonym])
      end
    end

    context 'when goods nomenclature has no label' do
      it 'does not raise and removes any stale suggestions' do
        # Pre-insert a stale suggestion
        SearchSuggestion.unrestrict_primary_key
        SearchSuggestion.create(
          id: "#{commodity.goods_nomenclature_sid}_synonym_stale",
          value: 'stale',
          type: 'synonym',
          goods_nomenclature_sid: commodity.goods_nomenclature_sid,
          goods_nomenclature_class: 'Commodity',
        )
        SearchSuggestion.restrict_primary_key

        expect {
          described_class.new(commodity).call
        }.to change {
          SearchSuggestion
            .where(goods_nomenclature_sid: commodity.goods_nomenclature_sid, type: 'synonym')
            .count
        }.from(1).to(0)
      end
    end

    context 'when label fields are empty' do
      before do
        create(:goods_nomenclature_label,
               goods_nomenclature: commodity,
               labels: {
                 'known_brands' => [],
                 'colloquial_terms' => [],
                 'synonyms' => [],
               },
               known_brands: Sequel.pg_array([], :text),
               colloquial_terms: Sequel.pg_array([], :text),
               synonyms: Sequel.pg_array([], :text))
      end

      it 'does not create any suggestions' do
        expect {
          described_class.new(commodity).call
        }.not_to change(SearchSuggestion, :count)
      end
    end

    it 'does not affect non-label suggestion types' do
      create(:search_suggestion, :search_reference,
             goods_nomenclature: commodity,
             value: 'reference term')

      create(:goods_nomenclature_label,
             goods_nomenclature: commodity,
             labels: {
               'known_brands' => [],
               'colloquial_terms' => [],
               'synonyms' => %w[test],
             },
             known_brands: Sequel.pg_array([], :text),
             colloquial_terms: Sequel.pg_array([], :text),
             synonyms: Sequel.pg_array(%w[test], :text))

      described_class.new(commodity).call

      expect(
        SearchSuggestion
          .where(goods_nomenclature_sid: commodity.goods_nomenclature_sid, type: 'search_reference')
          .count,
      ).to eq(1)
    end
  end
end
