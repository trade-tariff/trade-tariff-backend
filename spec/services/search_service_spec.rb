RSpec.describe SearchService do
  let(:data_serializer) { Api::V2::SearchSerializationService.new }

  describe 'initialization' do
    let(:query) { Forgery(:basic).text }

    it 'assigns search query' do
      expect(
        described_class.new(data_serializer, q: query).q,
      ).to eq query
    end

    it 'strips [, ] characters from search query' do
      expect(
        described_class.new(data_serializer, q: '[hello] [world]').q,
      ).to eq 'hello world'
    end
  end

  describe '#valid?' do
    it 'is valid if has no q param assigned' do
      expect(
        described_class.new(data_serializer, q: nil),
      ).to be_valid
    end

    it 'is valid if has no as_of param assigned' do
      expect(
        described_class.new(data_serializer, q: 'value'),
      ).to be_valid
    end

    it 'is valid if has both t and as_of params provided' do
      expect(
        described_class.new(data_serializer, q: 'value', as_of: Time.zone.today),
      ).to be_valid
    end
  end

  # Searching in search suggestions or find historic goods nomenclature
  describe 'exact search' do
    subject(:result) do
      described_class.new(data_serializer, q: query).to_json[:data][:attributes]
    end

    around do |example|
      TimeMachine.now { example.run }
    end

    context 'when chapters' do
      let(:query) { '11' }
      let(:pattern) do
        {
          type: 'exact_match',
          entry: {
            endpoint: 'chapters',
            id: '11',
          },
        }
      end

      before do
        goods_nomenclature = create :chapter, goods_nomenclature_item_id: '1100000000'

        create :search_suggestion, :goods_nomenclature, goods_nomenclature:
      end

      it { expect(result).to match_json_expression pattern }
    end

    context 'when headings' do
      let(:query) { '0101' }
      let(:pattern) do
        {
          type: 'exact_match',
          entry: {
            endpoint: 'headings',
            id: '0101',
          },
        }
      end

      before do
        goods_nomenclature = create :heading, goods_nomenclature_item_id: '0101000000'

        create :search_suggestion, :goods_nomenclature, goods_nomenclature:
      end

      it { expect(result).to match_json_expression pattern }
    end

    context 'when subheadings' do
      let(:pattern) do
        {
          type: 'exact_match',
          entry: {
            endpoint: 'subheadings',
            id: '0101210000-10',
          },
        }
      end

      before do
        goods_nomenclature = create :subheading, goods_nomenclature_item_id: '0101210000'

        create :search_suggestion, :goods_nomenclature, goods_nomenclature:
      end

      context 'when subheading with suffix' do
        let(:query) { '0101210000-10' }

        it { expect(result).to match_json_expression pattern }
      end

      context 'when subheading with short code' do
        let(:query) { '010121' }

        it { expect(result).to match_json_expression pattern }
      end
    end

    context 'when commodities' do
      let(:pattern) do
        {
          type: 'exact_match',
          entry: {
            endpoint: 'commodities',
            id: '0101210000',
          },
        }
      end

      before do
        goods_nomenclature = create :commodity, goods_nomenclature_item_id: '0101210000'

        create :search_suggestion, :goods_nomenclature, goods_nomenclature:
      end

      context 'when searching by full code' do
        let(:query) { '0101210000' }

        it { expect(result).to match_json_expression pattern }
      end

      context 'when searching by a shorter version of the code' do
        let(:query) { '0101210' }

        it { expect(result).to match_json_expression pattern }
      end
    end

    context 'when chemicals by cas rn' do
      before do
        goods_nomenclature = create :commodity, goods_nomenclature_item_id: '0101210000'

        create :search_suggestion, :goods_nomenclature, goods_nomenclature:, value: '8028-66-8'
      end

      let(:pattern) do
        {
          type: 'exact_match',
          entry: {
            endpoint: 'commodities',
            id: '0101210000',
          },
        }
      end

      context 'when cas number with leading string "cas "' do
        let(:query) { 'cas 8028-66-8' }

        it { expect(result).to match_json_expression pattern }
      end

      context 'when cas number without leading string "cas "' do
        let(:query) { '8028-66-8' }

        it { expect(result).to match_json_expression pattern }
      end
    end

    context 'when chemicals by cus number' do
      let(:query) { '0150000-1' }
      let(:pattern) do
        {
          type: 'exact_match',
          entry: {
            endpoint: 'commodities',
            id: '0101210000',
          },
        }
      end

      before do
        goods_nomenclature = create :commodity, goods_nomenclature_item_id: '0101210000'

        create :search_suggestion, :goods_nomenclature, goods_nomenclature:, value: '0150000-1'
      end

      it { expect(result).to match_json_expression pattern }
    end

    context 'when chemicals by name' do
      let(:query) { 'insulin, human' }
      let(:pattern) do
        {
          type: 'exact_match',
          entry: {
            endpoint: 'commodities',
            id: '0101210000',
          },
        }
      end

      before do
        goods_nomenclature = create :commodity, goods_nomenclature_item_id: '0101210000'

        create :search_suggestion, :goods_nomenclature, goods_nomenclature:, value: 'insulin, human'
      end

      it { expect(result).to match_json_expression pattern }
    end

    context 'when search references' do
      context 'when optimised search disabled' do
        subject(:result) { described_class.new(data_serializer, q: 'Foo Bar', as_of: Time.zone.today, resource_id: 'foo').to_json[:data][:attributes] }

        before do
          create(
            :search_suggestion,
            :search_reference,
            goods_nomenclature: create(:heading, goods_nomenclature_item_id: '0102000000'),
            id: 'foo',
            value: 'foo bar',
          )

          allow(TradeTariffBackend).to receive(:optimised_search_enabled?).and_return false
        end

        let(:expected_pattern) do
          {
            type: 'exact_match',
            entry: {
              endpoint: 'headings',
              id: '0102',
            },
          }
        end

        it { is_expected.to match_json_expression(expected_pattern) }
      end

      context 'when optimised search enabled' do
        subject(:result) { described_class.new(data_serializer, q: 'Foo Bar', as_of: Time.zone.today, resource_id: 100).to_json[:data][:attributes] }

        before do
          create :goods_nomenclature, goods_nomenclature_item_id: '3903000000'

          allow(TradeTariffBackend).to receive(:optimised_search_enabled?).and_return true
        end

        let(:expected_pattern) do
          {
            type: 'exact_match',
            entry: {
              endpoint: 'headings',
              id: '3903',
            },
          }
        end

        it { is_expected.to match_json_expression(expected_pattern) }
      end
    end

    shared_examples_for 'an historic goods nomenclature exact search' do |goods_nomenclature_type, query|
      subject(:result) do
        described_class.new(
          data_serializer,
          q: query,
          as_of: Time.zone.today,
        ).to_json[:data][:attributes]
      end

      let(:pattern) do
        {
          type: 'exact_match',
          entry: {
            endpoint: goods_nomenclature_type.to_s.pluralize,
            id: goods_nomenclature.to_param,
          },
        }
      end

      let!(:goods_nomenclature) do
        create(
          goods_nomenclature_type,
          :expired,
          :with_heading,
          goods_nomenclature_item_id: query.ljust(10, '0'),
        )
      end

      it { is_expected.to match_json_expression pattern }
    end

    it_behaves_like 'an historic goods nomenclature exact search', :chapter, '01'
    it_behaves_like 'an historic goods nomenclature exact search', :heading, '0101'
    it_behaves_like 'an historic goods nomenclature exact search', :subheading, '010121'
    it_behaves_like 'an historic goods nomenclature exact search', :commodity, '0101210000'
  end

  # Searching in ElasticSearch index
  describe 'fuzzy search' do
    context 'when filtering by date' do
      context 'when with goods codes that have bounded validity period' do
        subject { described_class.new(data_serializer, q: 'water').to_json[:data][:attributes] }

        before do
          create :heading, :with_description,
                 goods_nomenclature_item_id: '2851000000',
                 validity_start_date: Date.new(1972, 1, 1),
                 validity_end_date: Date.new(2006, 12, 31),
                 description: 'Other inorganic compounds (including distilled or conductivity water and water of similar purity);'
        end

        # heading that has validity period of 1972-01-01 to 2006-12-31
        let(:heading_pattern) do
          {
            type: 'fuzzy_match',
            goods_nomenclature_match: {
              headings: [
                { '_source' => {
                  'goods_nomenclature_item_id' => '2851000000',
                }.ignore_extra_keys! }.ignore_extra_keys!,
              ].ignore_extra_values!,
            }.ignore_extra_keys!,
          }.ignore_extra_keys!
        end

        context 'with search date within goods code validity period' do
          around { |example| TimeMachine.at('2005-01-01') { example.run } }

          it { is_expected.to match_json_expression heading_pattern }
        end

        context 'with search date outside goods code validity period' do
          around { |example| TimeMachine.at('2007-01-01') { example.run } }

          it { is_expected.not_to match_json_expression heading_pattern }
        end
      end

      context 'when with goods codes that have unbounded validity period' do
        subject(:result) { described_class.new(data_serializer, q: 'Live bovine animals').to_json[:data][:attributes] }

        around { |example| TimeMachine.at(date) { example.run } }

        before do
          create :heading, :with_description,
                 goods_nomenclature_item_id: '0102000000',
                 validity_start_date: Date.new(1972, 1, 1),
                 validity_end_date: nil,
                 description: 'Live bovine animals'
        end

        # heading that has validity period starting from 1972-01-01
        let(:heading_pattern) do
          {
            type: 'fuzzy_match',
            goods_nomenclature_match: {
              headings: [
                { '_source' => {
                  'goods_nomenclature_item_id' => '0102000000',
                }.ignore_extra_keys! }.ignore_extra_keys!,
              ].ignore_extra_values!,
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
      # Ensure we use match (not query_string query)
      # query string interprets queries according to Lucene syntax
      # and we don't need these advanced features

      let(:result) do
        described_class.new(data_serializer, q: '!!! [t_e_s_t][',
                                             as_of: '1970-01-01').to_json[:data][:attributes]
      end

      specify 'search does not raise an exception' do
        expect { result }.not_to raise_error
      end

      specify 'search returns empty resilt' do
        expect(result).to match_json_expression SearchService::BaseSearch::BLANK_RESULT.merge(type: 'fuzzy_match')
      end
    end

    context 'when searching for sections' do
      # Sections do not have validity periods
      # We have to ensure there is special clause in Elasticsearch
      # query that takes that into account and they get found
      subject(:result) { described_class.new(data_serializer, q: 'example title', as_of: '1970-01-01').to_json[:data][:attributes] }

      before do
        create :section, title: 'example title'
      end

      let(:response_pattern) do
        {
          type: 'fuzzy_match',
          goods_nomenclature_match: {
            sections: [
              { '_source' => {
                'title' => 'example title',
              }.ignore_extra_keys! }.ignore_extra_keys!,
            ].ignore_extra_values!,
          }.ignore_extra_keys!,
        }.ignore_extra_keys!
      end

      it 'finds relevant sections' do
        expect(result).to match_json_expression response_pattern
      end
    end
  end

  context 'when reference search' do
    describe 'validity period function' do
      subject(:result) { TimeMachine.at(date) { described_class.new(data_serializer, q: 'water').to_json[:data][:attributes] } }

      before do
        create :search_suggestion,
               :search_reference,
               goods_nomenclature: heading,
               value: 'water'
      end

      let!(:heading) do
        create :heading, :with_description,
               goods_nomenclature_item_id: '2851000000',
               validity_start_date: Date.new(1972, 1, 1),
               validity_end_date: Date.new(2006, 12, 31),
               description: 'Test'
      end

      let(:heading_pattern) do
        {
          type: 'exact_match',
          entry: {
            endpoint: 'headings',
            id: heading.goods_nomenclature_item_id.first(4),
          }.ignore_extra_keys!,
        }.ignore_extra_keys!
      end

      context 'with search date falls within validity period' do
        let(:date) { '2005-01-01' }

        it { is_expected.to match_json_expression heading_pattern }
      end

      context 'with search date does not fall within validity period does not return goods code' do
        let(:date) { '2007-01-01' }

        it { is_expected.not_to match_json_expression heading_pattern }
      end
    end

    describe 'reference matching for multi term searches' do
      before do
        create :search_suggestion,
               :search_reference,
               goods_nomenclature: heading1,
               value: 'acid oil'

        create :search_suggestion,
               :search_reference,
               goods_nomenclature: heading2,
               value: 'other kind of oil'
      end

      let!(:heading1) do
        create :heading, :with_description,
               goods_nomenclature_item_id: '2851000000',
               description: 'Test 1'
      end
      let!(:heading2) do
        create :heading, :with_description,
               goods_nomenclature_item_id: '2920000000',
               description: 'Test 2'
      end

      let(:heading_pattern) do
        {
          type: 'exact_match',
          entry: {
            endpoint: 'headings',
            id: heading1.goods_nomenclature_item_id.first(4),
          }.ignore_extra_keys!,
        }.ignore_extra_keys!
      end

      it 'only matches exact phrases' do
        result = described_class.new(data_serializer, q: 'acid oil', as_of: Time.zone.today).to_json[:data][:attributes]

        expect(result).to match_json_expression heading_pattern
      end
    end
  end

  describe '#persisted?' do
    it 'returns false' do
      expect(described_class.new(data_serializer, q: '123')).not_to be_persisted
    end
  end
end
