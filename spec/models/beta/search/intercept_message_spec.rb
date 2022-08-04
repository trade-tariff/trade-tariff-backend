RSpec.describe Beta::Search::InterceptMessage do
  describe '.build' do
    subject(:result) { described_class.build(search_query_parser_result.original_search_query) }

    let(:search_query_parser_result) { build(:search_query_parser_result, :multiple_hits) }

    it { is_expected.to be_a(described_class) }
    it { expect(result.id).to eq('f12f2d963bd9edfcbc56138adff3698a') }
    it { expect(result).to respond_to(:term) }
    it { expect(result).to respond_to(:message) }
  end
end
