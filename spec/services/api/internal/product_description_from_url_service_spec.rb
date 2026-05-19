RSpec.describe Api::Internal::ProductDescriptionFromUrlService do
  describe '.call' do
    let(:url) { 'https://example.com/product' }
    let(:page) do
      Api::Internal::ProductDescription::FetchedPage.new(
        final_url: 'https://example.com/canonical-product',
        content_type: 'text/html',
        body: '<html><h1>Cotton T-shirt</h1></html>',
      )
    end
    let(:extracted_content) do
      Api::Internal::ProductDescription::ExtractedContent.new(
        title: 'Cotton T-shirt',
        meta_description: nil,
        open_graph_title: nil,
        open_graph_description: nil,
        h1: 'Cotton T-shirt',
        product_data: {},
        body_text: 'Short-sleeved cotton T-shirt',
      )
    end
    let(:generated_result) do
      Api::Internal::ProductDescription::Result.success(
        description: 'Short-sleeved cotton T-shirt',
        source_url: 'https://example.com/canonical-product',
        confidence: 'high',
        metadata: { 'title' => 'Cotton T-shirt' },
      )
    end

    it 'fetches, extracts and generates a product description' do
      allow(Api::Internal::ProductDescription::SafeUrlFetcher).to receive(:call).with(url).and_return(page)
      allow(Api::Internal::ProductDescription::ProductPageExtractor).to receive(:call).with(page.body).and_return(extracted_content)
      allow(Api::Internal::ProductDescription::ProductDescriptionGenerator).to receive(:call)
        .with(extracted_content, source_url: page.final_url)
        .and_return(generated_result)

      result = described_class.call(url)

      expect(result).to eq(generated_result)
    end

    it 'returns fetcher failures as controlled result failures' do
      allow(Api::Internal::ProductDescription::SafeUrlFetcher).to receive(:call)
        .and_raise(Api::Internal::ProductDescription::SafeUrlFetcher::FetchError.new('Unsafe URL', 'URL resolves to an unsafe address'))

      result = described_class.call(url)

      expect(result).not_to be_success
      expect(result.error_title).to eq('Unsafe URL')
      expect(result.error_detail).to eq('URL resolves to an unsafe address')
    end

    it 'generates a product description from URL content when fetching returns an HTTP status error' do
      url_content = extracted_content.with(
        title: 'pure cotton garment dyed t shirt',
        h1: nil,
        body_text: 'URL path suggests: pure cotton garment dyed t shirt',
      )
      fetch_error = Api::Internal::ProductDescription::SafeUrlFetcher::FetchError.new(
        'Fetch failed',
        'URL returned HTTP 404',
        reason: :http_status,
      )

      allow(Api::Internal::ProductDescription::SafeUrlFetcher).to receive(:call)
        .with(url)
        .and_raise(fetch_error)
      allow(Api::Internal::ProductDescription::UrlContentExtractor).to receive(:call)
        .with(url)
        .and_return(url_content)
      allow(Api::Internal::ProductDescription::ProductDescriptionGenerator).to receive(:call)
        .with(url_content, source_url: url)
        .and_return(generated_result.with(source_url: url, confidence: 'high'))

      result = described_class.call(url)

      expect(result).to be_success
      expect(result.source_url).to eq(url)
      expect(result.confidence).to eq('low')
    end

    it 'returns a controlled failure when URL content fallback generation fails' do
      url_content = extracted_content.with(
        title: 'pure cotton garment dyed t shirt',
        h1: nil,
        body_text: 'URL path suggests: pure cotton garment dyed t shirt',
      )
      fetch_error = Api::Internal::ProductDescription::SafeUrlFetcher::FetchError.new(
        'Fetch failed',
        'URL returned HTTP 404',
        reason: :http_status,
      )

      allow(Api::Internal::ProductDescription::SafeUrlFetcher).to receive(:call)
        .with(url)
        .and_raise(fetch_error)
      allow(Api::Internal::ProductDescription::UrlContentExtractor).to receive(:call)
        .with(url)
        .and_return(url_content)
      allow(Api::Internal::ProductDescription::ProductDescriptionGenerator).to receive(:call)
        .with(url_content, source_url: url)
        .and_raise(OpenaiClient::ApiError.new(status: 400, body: { 'error' => 'bad request' }))
      allow(ActiveSupport::Notifications).to receive(:instrument)

      result = described_class.call(url)

      expect(result).not_to be_success
      expect(result.error_title).to eq('Product description failed')
      expect(result.error_detail).to eq('Could not generate a product description from the URL')
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'description_failed.product_description',
        error_class: 'OpenaiClient::ApiError',
        error_message: /OpenAI API error/,
      )
    end

    it 'returns a controlled failure when extracted content is insufficient' do
      insufficient_content = extracted_content.with(title: nil, h1: nil, body_text: 'Home')

      allow(Api::Internal::ProductDescription::SafeUrlFetcher).to receive(:call).with(url).and_return(page)
      allow(Api::Internal::ProductDescription::ProductPageExtractor).to receive(:call).with(page.body).and_return(insufficient_content)

      result = described_class.call(url)

      expect(result).not_to be_success
      expect(result.error_title).to eq('Insufficient product information')
      expect(result.error_detail).to eq('Could not identify enough product information from the URL')
    end

    it 'logs unexpected exceptions and returns a generic failure' do
      allow(Api::Internal::ProductDescription::SafeUrlFetcher).to receive(:call).and_raise(StandardError, 'boom')
      allow(ActiveSupport::Notifications).to receive(:instrument)

      result = described_class.call(url)

      expect(result).not_to be_success
      expect(result.error_title).to eq('Product description failed')
      expect(result.error_detail).to eq('Could not generate a product description from the URL')
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'description_failed.product_description',
        error_class: 'StandardError',
        error_message: 'boom',
      )
    end
  end
end
