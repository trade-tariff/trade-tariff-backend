RSpec.describe ElasticSearch::ElasticSearchService do
  before do
    index = Search::SearchSuggestionsIndex.new
    TradeTariffBackend.search_client.drop_index(index)
    TradeTariffBackend.search_client.create_index(index)
  end

  describe 'initialization' do
    let(:query) { Forgery(:basic).text }

    it 'assigns search query' do
      expect(
        described_class.new(q: query).q,
      ).to eq query
    end

    it 'strips [, ] characters from search query' do
      expect(
        described_class.new(q: '[hello] [world]').q,
      ).to eq 'hello world'
    end
  end

  describe '#valid?' do
    it 'is valid if has no q param assigned' do
      expect(
        described_class.new(q: nil),
      ).to be_valid
    end

    it 'is valid if has no as_of param assigned' do
      expect(
        described_class.new(q: 'value'),
      ).to be_valid
    end

    it 'is valid if has both t and as_of params provided' do
      expect(
        described_class.new(q: 'value', as_of: Time.zone.today),
      ).to be_valid
    end
  end

  describe 'search suggestion' do
    context 'when searching by goods nomenclature item id' do
      subject(:result) { described_class.new(q: '0102000000', as_of: '2007-01-01').to_suggestions[:data][0] }

      before do
        heading = create :heading, :with_description,
                         goods_nomenclature_item_id: '0102000000',
                         validity_start_date: Date.new(1972, 1, 1),
                         validity_end_date: nil,
                         description: 'Live bovine animals'
        index_model(heading)
      end

      let(:heading_pattern) do
        {
          type: :search_suggestion,
          attributes: {
            value: '0102000000',
            goods_nomenclature_class: 'Heading',
            suggestion_type: 'goods_nomenclature',
            query: '0102000000',
          }.ignore_extra_keys!,
        }.ignore_extra_keys!
      end

      it { is_expected.to match_json_expression heading_pattern }
    end

    describe 'querying with ambiguous characters' do
      subject(:result) do
        described_class.new(q: '! 01020000',
                            as_of: '2007-01-01').to_suggestions[:data][0]
      end

      before do
        heading = create :heading, :with_description,
                         goods_nomenclature_item_id: '0102000000',
                         validity_start_date: Date.new(1972, 1, 1),
                         validity_end_date: nil,
                         description: 'Live bovine animals'
        index_model(heading)
      end

      let(:heading_pattern) do
        {
          type: :search_suggestion,
          attributes: {
            value: '0102000000',
            goods_nomenclature_class: 'Heading',
            suggestion_type: 'goods_nomenclature',
            query: '01020000',
          }.ignore_extra_keys!,
        }.ignore_extra_keys!
      end

      context 'for fuzzy query search returns valid result' do
        it { is_expected.to match_json_expression heading_pattern }
      end
    end
  end

  context 'when reference search' do
    describe 'searching by reference title' do
      subject { described_class.new(q: 'tea', as_of: nil).to_suggestions[:data][0] }

      before do
        ref = create :search_reference, :with_commodity,
                     title: 'tea'
        index_model(ref)
      end

      let(:heading_pattern) do
        {
          type: :search_suggestion,
          attributes: {
            value: 'tea',
            goods_nomenclature_class: 'Commodity',
            suggestion_type: 'search_reference',
            query: 'tea',
          }.ignore_extra_keys!,
        }.ignore_extra_keys!
      end

      it { is_expected.to match_json_expression heading_pattern }
    end
  end

  context 'when chemical search' do
    describe 'with chemical data indexed' do
      before do
        chem = create :full_chemical
        index_model(chem)
      end

      context 'when search by chemical name' do
        subject { described_class.new(q: 'powder', as_of: nil).to_suggestions[:data][0] }

        let(:heading_pattern) do
          {
            type: :search_suggestion,
            attributes: {
              value: 'mel powder',
              goods_nomenclature_class: 'Heading',
              suggestion_type: 'full_chemical_name',
              query: 'powder',
            }.ignore_extra_keys!,
          }.ignore_extra_keys!
        end

        it { is_expected.to match_json_expression heading_pattern }
      end

      context 'when search by cus number' do
        subject { described_class.new(q: '0154438', as_of: nil).to_suggestions[:data][0] }

        let(:heading_pattern) do
          {
            type: :search_suggestion,
            attributes: {
              value: '0154438-3',
              goods_nomenclature_class: 'Heading',
              suggestion_type: 'full_chemical_cus',
              query: '0154438',
            }.ignore_extra_keys!,
          }.ignore_extra_keys!
        end

        it { is_expected.to match_json_expression heading_pattern }
      end

      context 'when search by cas_rn number' do
        subject { described_class.new(q: '8028', as_of: nil).to_suggestions[:data][0] }

        let(:heading_pattern) do
          {
            type: :search_suggestion,
            attributes: {
              value: '8028-66-8',
              goods_nomenclature_class: 'Heading',
              suggestion_type: 'full_chemical_cas',
              query: '8028',
            }.ignore_extra_keys!,
          }.ignore_extra_keys!
        end

        it { is_expected.to match_json_expression heading_pattern }
      end
    end
  end
end
