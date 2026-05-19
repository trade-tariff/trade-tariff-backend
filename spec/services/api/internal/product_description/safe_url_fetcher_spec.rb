RSpec.describe Api::Internal::ProductDescription::SafeUrlFetcher do
  subject(:fetcher) { described_class.new(url) }

  let(:url) { 'https://example.com/product' }
  let(:public_addrinfo) { instance_double(Addrinfo, ip_address: '93.184.216.34') }

  before do
    allow(Addrinfo).to receive(:getaddrinfo).and_return([public_addrinfo])
  end

  it 'fetches a public https html page' do
    stub_request(:get, 'https://example.com/product')
      .to_return(status: 200, headers: { 'Content-Type' => 'text/html; charset=utf-8' }, body: '<html>Product</html>')

    result = fetcher.call

    expect(result).to have_attributes(
      final_url: 'https://example.com/product',
      content_type: 'text/html; charset=utf-8',
      body: '<html>Product</html>',
    )
  end

  it 'rejects blank URLs' do
    expect {
      described_class.new('').call
    }.to raise_error(described_class::FetchError, 'Url is required')
  end

  it 'rejects non-https URLs' do
    expect {
      described_class.new('http://example.com/product').call
    }.to raise_error(described_class::FetchError, 'Only https URLs are supported')
  end

  it 'rejects URLs with credentials' do
    expect {
      described_class.new('https://user:password@example.com/product').call
    }.to raise_error(described_class::FetchError, 'URL credentials are not supported')
  end

  it 'rejects unsafe resolved IPs' do
    allow(Addrinfo).to receive(:getaddrinfo).and_return([instance_double(Addrinfo, ip_address: '127.0.0.1')])

    expect {
      fetcher.call
    }.to raise_error(described_class::FetchError, 'URL resolves to an unsafe address')
  end

  it 'revalidates redirect targets' do
    allow(Addrinfo).to receive(:getaddrinfo)
      .with('example.com', nil)
      .and_return([public_addrinfo])
    allow(Addrinfo).to receive(:getaddrinfo)
      .with('internal.example', nil)
      .and_return([instance_double(Addrinfo, ip_address: '10.0.0.1')])

    stub_request(:get, 'https://example.com/product')
      .to_return(status: 302, headers: { 'Location' => 'https://internal.example/admin' })

    expect {
      fetcher.call
    }.to raise_error(described_class::FetchError, 'URL resolves to an unsafe address')
  end

  it 'rejects too many redirects' do
    allow(AdminConfiguration).to receive(:integer_value).and_call_original
    allow(AdminConfiguration).to receive(:integer_value)
      .with('product_description_max_redirects')
      .and_return(1)

    stub_request(:get, 'https://example.com/product')
      .to_return(status: 302, headers: { 'Location' => 'https://example.com/product-2' })
    stub_request(:get, 'https://example.com/product-2')
      .to_return(status: 302, headers: { 'Location' => 'https://example.com/product-3' })

    expect {
      fetcher.call
    }.to raise_error(described_class::FetchError, 'Too many redirects')
  end

  it 'uses admin configured open and read timeouts' do
    allow(AdminConfiguration).to receive(:integer_value).and_call_original
    allow(AdminConfiguration).to receive(:integer_value)
      .with('product_description_open_timeout_seconds')
      .and_return(7)
    allow(AdminConfiguration).to receive(:integer_value)
      .with('product_description_read_timeout_seconds')
      .and_return(11)

    stub_request(:get, 'https://example.com/product')
      .to_return(status: 200, headers: { 'Content-Type' => 'text/html' }, body: '<html>Product</html>')

    fetcher.call

    expect(a_request(:get, 'https://example.com/product')).to have_been_made
    expect(AdminConfiguration).to have_received(:integer_value).with('product_description_open_timeout_seconds')
    expect(AdminConfiguration).to have_received(:integer_value).with('product_description_read_timeout_seconds')
  end

  it 'rejects unsupported content types' do
    stub_request(:get, 'https://example.com/product')
      .to_return(status: 200, headers: { 'Content-Type' => 'application/pdf' }, body: '%PDF')

    expect {
      fetcher.call
    }.to raise_error(described_class::FetchError, 'Unsupported content type')
  end

  it 'keeps only response content up to the byte limit' do
    allow(AdminConfiguration).to receive(:integer_value).and_call_original
    allow(AdminConfiguration).to receive(:integer_value)
      .with('product_description_max_response_bytes')
      .and_return(12)

    stub_request(:get, 'https://example.com/product')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'text/html' },
        body: 'a' * 13,
      )

    result = fetcher.call

    expect(result.body).to eq('a' * 12)
  end

  it 'rejects unsafe IPv6 resolved IPs' do
    allow(Addrinfo).to receive(:getaddrinfo).and_return([instance_double(Addrinfo, ip_address: '::1')])

    expect {
      fetcher.call
    }.to raise_error(described_class::FetchError, 'URL resolves to an unsafe address')
  end
end
