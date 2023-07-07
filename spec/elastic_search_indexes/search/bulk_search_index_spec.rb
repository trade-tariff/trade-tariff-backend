RSpec.describe Search::BulkSearchIndex do
  subject(:index) { described_class.new('testnamespace') }

  it { is_expected.to have_attributes type: 'bulk_search' }
  it { is_expected.to have_attributes name: 'testnamespace-bulk_searches-uk' }
  it { is_expected.to have_attributes serializer: Search::BulkSearchSerializer }

  describe '#serialize_record' do
    subject(:result) { index.serialize_record(record) }

    let(:record) do
      Hashie::TariffMash.new(
        number_of_digits: 8,
        short_code: '03028910',
        indexed_descriptions: ['FISH AND CRUSTACEANS, MOLLUSCS AND OTHER AQUATIC INVERTEBRATES', 'Fish, fresh or chilled', 'Other fish', 'Other'],
        indexed_tradeset_descriptions: ['fish', 'fish - fresh or chilled', 'fish - livers', 'fish - roes'],
        search_references: ['fish', 'fish - fresh or chilled', 'fish - livers', 'fish - roes'],
        intercept_terms: ['red mullet'],
      )
    end

    it 'returns a serialized record' do
      expect(result).to include(
        'number_of_digits' => 8,
        'short_code' => '03028910',
        'indexed_descriptions' => 'FISH AND CRUSTACEANS, MOLLUSCS AND OTHER AQUATIC INVERTEBRATES|Fish, fresh or chilled|Other fish|Other',
        'indexed_tradeset_descriptions' => 'fish|fish - fresh or chilled|fish - livers|fish - roes',
        'search_references' => 'fish|fish - fresh or chilled|fish - livers|fish - roes',
        'intercept_terms' => 'red mullet',
      )
    end
  end

  describe '#dataset_heading' do
    subject(:dataset_heading) do
      described_class
        .new('testnamespace')
        .dataset_heading(heading.heading_short_code)
    end

    let!(:heading) { create :heading, :with_description, goods_nomenclature_item_id: '0101000000' }

    it { is_expected.to all(be_a(Hashie::TariffMash)) }
  end

  describe '#definition' do
    context 'when the stemming exclusion and synonym references are specified in the environment' do
      before do
        allow(TradeTariffBackend).to receive(:stemming_exclusion_reference_analyzer).and_return(stemming_exclusion_reference_analyzer)
        allow(TradeTariffBackend).to receive(:synonym_reference_analyzer).and_return(synonym_reference_analyzer)
      end

      let(:stemming_exclusion_reference_analyzer) { 'analyzers/F135140295' }
      let(:synonym_reference_analyzer) { 'analyzers/F135140296' }

      it 'generates the correct stemmer_override filter setting' do
        expected_filter_setting = {
          type: 'stemmer_override',
          rules_path: 'analyzers/F135140295',
        }

        actual_filter_setting = index.definition.dig(
          :settings,
          :index,
          :analysis,
          :filter,
          :english_stem_exclusions,
        )

        expect(actual_filter_setting).to eq(expected_filter_setting)
      end

      it 'generates the correct synonym filter setting' do
        expected_filter_setting = {
          type: 'synonym',
          synonyms_path: 'analyzers/F135140296',
        }

        actual_filter_setting = index.definition.dig(
          :settings,
          :index,
          :analysis,
          :filter,
          :synonym,
        )

        expect(actual_filter_setting).to eq(expected_filter_setting)
      end

      it 'uses the correct filter order' do
        expected_filter_order = %w[
          synonym
          english_stem_exclusions
          english_possessive_stemmer
          lowercase
          english_stop
          english_stemmer
        ]

        actual_filter_order = index.definition.dig(
          :settings,
          :index,
          :analysis,
          :analyzer,
          :english,
          :filter,
        )

        expect(actual_filter_order).to eq(expected_filter_order)
      end
    end
  end
end
