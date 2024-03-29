RSpec.describe Api::Beta::SearchResultSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    context 'when the search result has multiple hits' do
      let(:serializable) do
        build(
          :search_result,
          :clothing,
          :generate_heading_and_chapter_statistics,
          :generate_guide_statistics,
          :generate_facet_statistics,
        )
      end

      let(:expected) do
        {
          data: {
            id: '6fc22ae4ee7f6fbe9b4988a4557dd3f9',
            type: :search_result,
            attributes: { took: 1, timed_out: false, max_score: 76.96534, total_results: 10 },
            relationships: {
              search_query_parser_result: {
                data: {
                  id: '50cf19912960f65490b334ea9c196eea',
                  type: :search_query_parser_result,
                },
              },
              intercept_message: {
                data: {
                  id: 'be815ed834d0c282cab563ea73556f97',
                  type: :intercept_message,
                },
              },
              hits: {
                data: [
                  { id: '43821', type: :subheading },
                  { id: '43606', type: :subheading },
                  { id: '43607', type: :commodity },
                  { id: '43608', type: :commodity },
                  { id: '43609', type: :commodity },
                  { id: '43522', type: :commodity },
                  { id: '43530', type: :commodity },
                  { id: '43486', type: :subheading },
                  { id: '43487', type: :commodity },
                  { id: '43488', type: :commodity },
                ],
              },
              direct_hit: { data: nil },
              heading_statistics: {
                data: [
                  { id: '6217', type: :heading_statistic },
                  { id: '6209', type: :heading_statistic },
                  { id: '6211', type: :heading_statistic },
                  { id: '6307', type: :heading_statistic },
                ],
              },
              chapter_statistics: {
                data: [
                  { id: '62', type: :chapter_statistic },
                  { id: '63', type: :chapter_statistic },
                ],
              },
              guide: { data: { id: '18', type: :guide } },
              facet_filter_statistics: {
                data: [
                  { id: '2ecbb6c19ee6282b0c79dda2aeaf0192', type: :facet_filter_statistic },
                  { id: 'b24e66a126ad13c1521cf6cda4b2c502', type: :facet_filter_statistic },
                  { id: 'b030d559d41aee55d3cd439888aa5edf', type: :facet_filter_statistic },
                ],
              },
            },
          },
        }
      end

      it { is_expected.to eq(expected) }
    end

    context 'when the search result has a direct hit' do
      let(:serializable) { build(:search_result, :single_hit) }
      let(:expected) do
        {
          data: {
            id: '51579623029349bc57538b4773f5a1ed',
            type: :search_result,
            attributes: { took: 0, timed_out: false, max_score: 79.16452, total_results: 1 },
            relationships: {
              search_query_parser_result: {
                data: {
                  id: '0e956af30bdc0dcd5679f2249adc6d94',
                  type: :search_query_parser_result,
                },
              },
              intercept_message: { data: nil },
              hits: { data: [{ id: '98910', type: :commodity }] },
              direct_hit: { data: { id: '0406105090-80', type: :commodity } },
              heading_statistics: { data: [] },
              chapter_statistics: { data: [] },
              guide: { data: nil },
              facet_filter_statistics: { data: [] },
            },
          },
        }
      end

      it { is_expected.to eq(expected) }
    end
  end
end
