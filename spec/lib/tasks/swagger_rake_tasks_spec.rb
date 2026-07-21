RSpec.describe SwaggerRakeTasks do
  describe '.remove_rswag_getters' do
    subject(:processed_document) { described_class.remove_rswag_getters(document) }

    let(:document) do
      {
        'paths' => {
          '/api/search' => {
            'parameters' => [
              { 'name' => 'Accept', 'getter' => 'accept', 'in' => 'header' },
              { '$ref' => '#/components/parameters/accept_header' },
            ],
          },
        },
        'components' => {
          'parameters' => {
            'accept_header' => { 'name' => 'Accept', 'getter' => 'accept', 'in' => 'header' },
          },
        },
      }
    end

    it 'recursively removes rswag getter metadata' do
      expect(processed_document).to eq(
        'paths' => {
          '/api/search' => {
            'parameters' => [
              { 'name' => 'Accept', 'in' => 'header' },
              { '$ref' => '#/components/parameters/accept_header' },
            ],
          },
        },
        'components' => {
          'parameters' => {
            'accept_header' => { 'name' => 'Accept', 'in' => 'header' },
          },
        },
      )
    end
  end
end
