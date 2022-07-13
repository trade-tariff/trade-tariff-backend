RSpec.describe Api::Beta::SearchResultSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) { build(:search_result, :multiple_hits, :generate_statistics) }

    let(:expected) do
      {
        data: {
          id: '40d70a67aafa270656c01738cfec041b',
          type: :search_result,
          attributes: { took: 3, timed_out: false, max_score: 161.34302, total_results: 10 },
          relationships: {
            search_query_parser_result: {
              data: {
                id: '52b14869c15726dda86b87cb93666a74',
                type: :search_query_parser_result,
              },
            },
            hits: {
              data: [
                { id: '93797', type: :subheading },
                { id: '93796', type: :commodity },
                { id: '93798', type: :subheading },
                { id: '93799', type: :commodity },
                { id: '93800', type: :commodity },
                { id: '93801', type: :commodity },
                { id: '72763', type: :commodity },
                { id: '27624', type: :heading },
                { id: '93994', type: :commodity },
                { id: '95674', type: :commodity },
              ],
            },
            heading_statistics: { data: [
              { id: '0101', type: :heading_statistic },
              { id: '0302', type: :heading_statistic },
            ] },
            chapter_statistics: {
              data: [
                { id: '01', type: :chapter_statistic },
                { id: '03', type: :chapter_statistic },
              ],
            },
          },
        },
      }
    end

    it { is_expected.to eq(expected) }
  end
end
