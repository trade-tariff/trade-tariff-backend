RSpec.describe SearchQueryParser do
  subject(:search_query_parser){ described_class.new }

  describe '#get_tokens' do
    let(:success_response) {
      {
        entities: {
          noun_chunks: [
            'aaa bbb'
          ],
          tokens: {
            adjectives: [],
            all: [
              'aaa',
              'bbb'
            ],
            nouns: [
              'bbb'
            ],
            verbs: []
          }
        }
      }
    }

    let(:pattern) {
      {
        success: true,
        status: 200,
        data: success_response
      }
    }

    before do
      stub_request(:get, 'http://www.example.com/api/search/tokens/aaa bbb').
        to_return(body: success_response.to_json, status: 200)
    end

    it 'returns a valid response' do
      response = subject.get_tokens('aaa%20bbb')

      expect(response).to match_json_expression(pattern)
    end
  end
end
