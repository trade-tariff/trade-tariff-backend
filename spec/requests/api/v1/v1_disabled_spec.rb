RSpec.describe 'V1 API disabled' do
  let(:v1_headers) { { 'Accept' => 'application/vnd.hmrc.1.0+json', 'Content-Type' => 'application/json' } }
  let(:no_headers) { { 'Content-Type' => 'application/json' } }

  shared_examples 'returns 404 for V1 requests' do |path|
    it "returns 404 for #{path} with V1 Accept header" do
      get path, headers: v1_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  shared_examples 'returns 404 for URL-versioned V1 requests' do |path|
    it "returns 404 for #{path} without Accept header" do
      get path, headers: no_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'with UK service' do
    include_examples 'returns 404 for V1 requests', '/uk/api/chapters.json'
    include_examples 'returns 404 for V1 requests', '/uk/api/headings/0101.json'
    include_examples 'returns 404 for V1 requests', '/uk/api/commodities/0101210000.json'
    include_examples 'returns 404 for V1 requests', '/uk/api/sections.json'

    include_examples 'returns 404 for URL-versioned V1 requests', '/uk/api/v1/chapters.json'
    include_examples 'returns 404 for URL-versioned V1 requests', '/uk/api/v1/headings/0101.json'
    include_examples 'returns 404 for URL-versioned V1 requests', '/uk/api/v1/commodities/0101210000.json'
    include_examples 'returns 404 for URL-versioned V1 requests', '/uk/api/v1/sections.json'
  end

  context 'with XI service' do
    before { allow(TradeTariffBackend).to receive(:xi?).and_return(true) }

    include_examples 'returns 404 for V1 requests', '/xi/api/chapters.json'
    include_examples 'returns 404 for V1 requests', '/xi/api/headings/0101.json'
    include_examples 'returns 404 for V1 requests', '/xi/api/commodities/0101210000.json'
    include_examples 'returns 404 for V1 requests', '/xi/api/sections.json'

    include_examples 'returns 404 for URL-versioned V1 requests', '/xi/api/v1/chapters.json'
    include_examples 'returns 404 for URL-versioned V1 requests', '/xi/api/v1/headings/0101.json'
    include_examples 'returns 404 for URL-versioned V1 requests', '/xi/api/v1/commodities/0101210000.json'
    include_examples 'returns 404 for URL-versioned V1 requests', '/xi/api/v1/sections.json'
  end
end
