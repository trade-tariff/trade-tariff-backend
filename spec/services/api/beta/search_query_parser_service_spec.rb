RSpec.describe Api::Beta::SearchQueryParserService do
  let(:search_query_parser_service_url) { 'http://localhost:5000/api/search' }

  describe '#call' do
    context 'when the search query matches a known synonym' do
      subject(:result) { described_class.new('yakutian laika', '1').call }

      it { expect(result.null_result).to eq(true) }
    end

    context 'when the search query is empty' do
      subject(:result) { described_class.new('', '1').call }

      it { expect(result.null_result).to eq(true) }
    end

    context 'when the search query is nil' do
      subject(:result) { described_class.new(nil, '1').call }

      it { expect(result.null_result).to eq(true) }
    end

    context 'when the search query parser response is success' do
      subject(:result) { described_class.new('aaa bbb', '1').call }

      before { stub_request(:get, "#{search_query_parser_service_url}/tokens?q=aaa+bbb&spell=1").to_return(response) }

      let(:response) do
        {
          status: 200,
          body: {
            corrected_search_query: 'aaa bib',
            original_search_query: 'aaa bbb',
            tokens: {
              adjectives: [],
              all: %w[aaa bib],
              noun_chunks: %w[aaa bib],
              nouns: %w[aaa bib],
              verbs: [],
            },
          }.to_json,
        }
      end

      it { is_expected.to be_a(Beta::Search::SearchQueryParserResult) }

      it { expect(result.id).to eq('ca476c11a9e6c7dea1e75d14ad4cbb10') }
      it { expect(result.corrected_search_query).to eq('aaa bib') }
      it { expect(result.original_search_query).to eq('aaa bbb') }
      it { expect(result.adjectives).to eq([]) }
      it { expect(result.noun_chunks).to eq(%w[aaa bib]) }
      it { expect(result.nouns).to eq(%w[aaa bib]) }
      it { expect(result.verbs).to eq([]) }
      it { expect(result.null_result).to eq(false) }
    end

    context 'when the search query parser response is bad request' do
      subject(:result) { described_class.new('aaa bbb', '1').call }

      before { stub_request(:get, "#{search_query_parser_service_url}/tokens?q=aaa+bbb&spell=1").to_return(response) }

      let(:response) { { status: 400 } }

      it { expect { result }.to raise_error(Faraday::BadRequestError) }
    end
  end
end
