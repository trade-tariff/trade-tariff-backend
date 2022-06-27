RSpec.describe SearchQueryParser do
  subject(:search_query_parser) { described_class.new }

  let(:search_query_parser_service_url) { 'http://localhost:5000/api/search' }

  before do
    stub_request(:get, "#{search_query_parser_service_url}/tokens?q=aaa+bbb")
      .to_return(body: success_response.to_json, status: 200)

    stub_request(:get, "#{search_query_parser_service_url}/tokens?q=")
        .to_return(status: 400)
  end

  describe '#get_tokens' do
    let(:success_response) do
      {
        entities: {
          noun_chunks: [
            'aaa bbb',
          ],
          tokens: {
            adjectives: [],
            all: %w[
              aaa
              bbb
            ],
            nouns: %w[
              bbb
            ],
            verbs: [],
          },
        },
      }
    end

    let(:pattern) do
      success_response
    end

    context 'when the query term is a valid string' do
      let(:term) { 'aaa bbb' }

      it 'returns a valid response' do
        response = search_query_parser.get_tokens(term)

        expect(response).to match_json_expression(pattern)
      end
    end

    context 'when the query term is empty' do
      let(:term) { '' }

      it { expect { search_query_parser.get_tokens('') }.to raise_error(Faraday::BadRequestError) }
    end
  end
end
