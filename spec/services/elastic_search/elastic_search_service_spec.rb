RSpec.describe ElasticSearch::ElasticSearchService do
  before do
    TradeTariffBackend.search_client.drop_index(Search::GoodsNomenclatureIndex.new)
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

  # Searching in ElasticSearch index
  describe 'search suggestion' do
    context 'when filtering by date' do
      context 'when with goods codes that have bounded validity period' do
        subject { described_class.new(q: '2851000000', as_of: date).to_suggestions[:data][0] }

        before do
          heading = create :heading,
                           goods_nomenclature_item_id: '2851000000',
                           validity_start_date: Date.new(1972, 1, 1),
                           validity_end_date: Date.new(2006, 12, 31),
                           description: 'Other inorganic compounds (including distilled or conductivity water and water of similar purity);'

          heading.save
        end

        # heading that has validity period of 1972-01-01 to 2006-12-31
        let(:heading_pattern) do
          {
            type: :search_suggestion,
            attributes: {
              value: '2851000000',
              goods_nomenclature_class: 'Heading',
              suggestion_type: 'Goods Nomenclature Item Id',
              query: '2851000000',
            }.ignore_extra_keys!,
          }.ignore_extra_keys!
        end

        context 'with search date within goods code validity period' do
          let(:date) { '2007-01-01' }

          it { is_expected.not_to match_json_expression heading_pattern }
        end

        context 'with search date outside goods code validity period' do
          let(:date) { '2005-01-01' }

          it { is_expected.to match_json_expression heading_pattern }
        end
      end

      context 'when with goods codes that have unbounded validity period' do
        subject(:result) { described_class.new(q: 'bovine', as_of: date).to_suggestions[:data][0] }

        before do
          heading = create :heading, :with_description,
                           goods_nomenclature_item_id: '0102000000',
                           validity_start_date: Date.new(1972, 1, 1),
                           validity_end_date: nil,
                           description: 'Live bovine animals'

          heading.save
        end

        # heading that has validity period starting from 1972-01-01
        let(:heading_pattern) do
          {
            type: :search_suggestion,
            attributes: {
              value: 'Live bovine animals',
              goods_nomenclature_class: 'Heading',
              suggestion_type: 'Goods Nomenclature Description',
              query: 'bovine',
            }.ignore_extra_keys!,
          }.ignore_extra_keys!
        end

        context 'with search date greater than start of validity period it returns goods code' do
          let(:date) { '2007-01-01' }

          it { is_expected.to match_json_expression heading_pattern }
        end

        context 'with search date is less than start of validity period does not return goods code' do
          let(:date) { '1970-01-01' }

          it { is_expected.not_to match_json_expression heading_pattern }
        end
      end
    end

    describe 'querying with ambiguous characters' do
      subject(:result) do
        described_class.new(q: '! bovinn',
                            as_of: '2007-01-01').to_suggestions[:data][0]
      end

      before do
        heading = create :heading, :with_description,
                         goods_nomenclature_item_id: '0102000000',
                         validity_start_date: Date.new(1972, 1, 1),
                         validity_end_date: nil,
                         description: 'Live bovine animals'

        heading.save
      end

      let(:heading_pattern) do
        {
          type: :search_suggestion,
          attributes: {
            value: 'Live bovine animals',
            goods_nomenclature_class: 'Heading',
            suggestion_type: 'Goods Nomenclature Description',
            query: '! bovinn',
          }.ignore_extra_keys!,
        }.ignore_extra_keys!
      end

      context 'for fuzzy query search returns valid result' do
        it { is_expected.to match_json_expression heading_pattern }
      end
    end
  end

  context 'when reference search' do
    describe 'validity period function' do
      subject { described_class.new(q: 'tea', as_of: nil).to_suggestions[:data][0] }

      before do
        ref = create :search_reference, :with_commodity,
                     title: 'tea'

        ref.save
      end

      let(:heading_pattern) do
        {
          type: :search_suggestion,
          attributes: {
            value: 'tea',
            goods_nomenclature_class: 'Commodity',
            suggestion_type: 'Goods Nomenclature Search References',
            query: 'tea',
          }.ignore_extra_keys!,
        }.ignore_extra_keys!
      end

      context 'with search date falls within validity period' do
        let(:date) { '2005-01-01' }

        it { is_expected.to match_json_expression heading_pattern }
      end
    end
  end
end
