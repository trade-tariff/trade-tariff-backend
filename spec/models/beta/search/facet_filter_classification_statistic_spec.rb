RSpec.describe Beta::Search::FacetFilterClassificationStatistic do
  describe '#facet' do
    subject(:facet) { build(:search_result, :generate_facet_statistics).facet_filter_statistics.first.facet_classification_statistics.first.facet }

    it { is_expected.to eq('animal_type') }
  end

  describe '.build' do
    subject(:facet_filter_statistic) { described_class.build(statistic) }

    let(:statistic) do
      {
        'count' => 10,
        'filter_facet' => 'filter_animal_type',
        'classification' => 'equine animals',
      }
    end

    it { is_expected.to be_a(described_class) }
    it { expect(facet_filter_statistic.id).to eq('3afc6150b5c9a06ba76a427bf50d4efb') }
    it { expect(facet_filter_statistic.facet_filter).to eq('filter_animal_type') }
    it { expect(facet_filter_statistic.classification).to eq('equine animals') }
    it { expect(facet_filter_statistic.count).to eq(10) }
  end
end
