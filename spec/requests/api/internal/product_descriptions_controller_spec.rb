RSpec.describe Api::Internal::ProductDescriptionsController, :internal do
  describe 'POST /product_description' do
    it 'returns a generated product description' do
      allow(Api::Internal::ProductDescriptionFromUrlService).to receive(:call)
        .with('https://example.com/product')
        .and_return(
          Api::Internal::ProductDescription::Result.success(
            description: "Lightweight men's cotton T-shirt with short sleeves and a crew neck",
            source_url: 'https://example.com/product',
            confidence: 'high',
            metadata: { title: "Men's cotton T-shirt", brand: 'Example' },
          ),
        )

      post api_product_description_path(format: :json), params: { url: 'https://example.com/product' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        'data' => {
          'id' => 'https://example.com/product',
          'type' => 'product_description',
          'attributes' => {
            'description' => "Lightweight men's cotton T-shirt with short sleeves and a crew neck",
            'source_url' => 'https://example.com/product',
            'confidence' => 'high',
            'metadata' => { 'title' => "Men's cotton T-shirt", 'brand' => 'Example' },
          },
        },
      )
    end

    it 'returns 422 when the service rejects the URL' do
      allow(Api::Internal::ProductDescriptionFromUrlService).to receive(:call)
        .with('')
        .and_return(Api::Internal::ProductDescription::Result.failure('Invalid URL', 'Url is required'))

      post api_product_description_path(format: :json), params: { url: '' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq(
        'errors' => [
          {
            'status' => '422',
            'title' => 'Invalid URL',
            'detail' => 'Url is required',
            'source' => { 'pointer' => '/data/attributes/url' },
          },
        ],
      )
    end

    it 'fetches a product page and returns a generated description' do
      allow(Addrinfo).to receive(:getaddrinfo)
        .with('example.com', nil)
        .and_return([instance_double(Addrinfo, ip_address: '93.184.216.34')])
      stub_request(:get, 'https://example.com/product')
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'text/html' },
          body: <<~HTML,
            <html>
              <head>
                <title>Men's cotton T-shirt</title>
                <meta name="description" content="A soft short-sleeved T-shirt made from cotton.">
              </head>
              <body>
                <h1>Men's cotton T-shirt</h1>
                <p>This product has short sleeves, a crew neck and a regular fit.</p>
              </body>
            </html>
          HTML
        )
      allow(OpenaiClient).to receive(:call).and_return(
        {
          'description' => "Lightweight men's cotton T-shirt with short sleeves and a crew neck",
          'confidence' => 'high',
          'metadata' => { 'title' => "Men's cotton T-shirt", 'brand' => 'Example' },
        },
      )

      post api_product_description_path(format: :json), params: { url: 'https://example.com/product' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        'data' => {
          'id' => 'https://example.com/product',
          'type' => 'product_description',
          'attributes' => {
            'description' => "Lightweight men's cotton T-shirt with short sleeves and a crew neck",
            'source_url' => 'https://example.com/product',
            'confidence' => 'high',
            'metadata' => { 'title' => "Men's cotton T-shirt", 'brand' => 'Example' },
          },
        },
      )
    end

    it 'falls back to sanitized URL content when the product page returns an HTTP status error' do
      url = 'https://example.com/products/cotton-shirt/550e8400-e29b-41d4-a716-446655440000?token=secret-token#private'
      request_url = 'https://example.com/products/cotton-shirt/550e8400-e29b-41d4-a716-446655440000?token=secret-token'

      allow(Addrinfo).to receive(:getaddrinfo)
        .with('example.com', nil)
        .and_return([instance_double(Addrinfo, ip_address: '93.184.216.34')])
      stub_request(:get, request_url)
        .to_return(status: 404, headers: { 'Content-Type' => 'text/html' }, body: 'Not found')
      allow(OpenaiClient).to receive(:call).and_return(
        {
          'description' => 'Cotton shirt',
          'confidence' => 'low',
          'metadata' => { 'source' => 'url' },
        },
      )

      post api_product_description_path(format: :json), params: { url: }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('data', 'attributes')).to include(
        'description' => 'Cotton shirt',
        'source_url' => url,
        'confidence' => 'low',
        'metadata' => { 'source' => 'url' },
      )
      expect(OpenaiClient).to have_received(:call) do |messages|
        payload = messages.last.fetch(:content)

        expect(payload).to include('example cotton shirt')
        expect(payload).not_to include('secret-token')
        expect(payload).not_to include('550e8400')
        expect(payload).not_to include('private')
      end
    end
  end
end
