RSpec.describe Api::Beta::SearchQueryParserService do
  let(:search_query_parser_service_url) { 'http://localhost:5000/api/search' }

  describe '#call' do
    shared_examples_for 'a null result search query parser call' do |search_query, should_search|
      subject(:result) { described_class.new(search_query, should_search:).call }

      it { expect(result.null_result).to eq(true) }
    end

    it_behaves_like 'a null result search query parser call', '', true # Empty search query
    it_behaves_like 'a null result search query parser call', nil, true # Empty search query
    it_behaves_like 'a null result search query parser call', 'yakutian laika', true # Synonym search query
    it_behaves_like 'a null result search query parser call', 'ricotta', false # No search due to instruction

    context 'when the search query parser response is success' do
      subject(:result) { described_class.new('aaa bbb', spell: '1').call }

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
      subject(:result) { described_class.new('aaa bbb').call }

      before { stub_request(:get, "#{search_query_parser_service_url}/tokens?q=aaa+bbb&spell=1").to_return(response) }

      let(:response) { { status: 400 } }

      it { expect { result }.to raise_error(Faraday::BadRequestError) }
    end
  end
end
