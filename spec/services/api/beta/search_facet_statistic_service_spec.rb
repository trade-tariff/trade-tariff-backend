RSpec.describe Api::Beta::SearchFacetStatisticService do
  describe '#call' do
    subject(:call) do
      described_class.new(goods_nomenclature_hits).call.map do |facet_filter_statistic|
        { count: facet_filter_statistic.facet_count, facet_filter: facet_filter_statistic.facet_filter }
      end
    end

    context 'when there are filters returned in the search result' do
      let(:goods_nomenclature_hits) { build(:search_result, :clothing).hits }

      let(:expected_facet_statistics) do
        [
          { count: 4, facet_filter: 'filter_material' },
          { count: 2, facet_filter: 'filter_clothing_gender' },
          { count: 2, facet_filter: 'filter_garment_type' },
        ]
      end

      it { is_expected.to eq(expected_facet_statistics) }
    end

    context 'when there are no filters in the search result' do
      let(:goods_nomenclature_hits) { build(:search_result, :no_hits).hits }

      let(:expected_facet_statistics) { [] }

      it { is_expected.to eq(expected_facet_statistics) }
    end
  end
end
