require 'rails_helper'

RSpec.describe XiCnImporter::DocumentFetcher do
  subject(:fetcher) { described_class.new }

  let(:cellar_html_url) { "https://publications.europa.eu/resource/cellar/#{guid}.0006.03/DOC_1" }
  let(:cellar_pdf_url)  { "https://publications.europa.eu/resource/cellar/#{guid}.0006.01/DOC_1" }

  let(:sparql_response_body) do
    {
      'results' => {
        'bindings' => [
          {
            'work' => { 'value' => "http://publications.europa.eu/resource/cellar/#{guid}" },
            'celex' => { 'value' => '32025R1926' },
            'force_date' => { 'value' => '2026-01-01' },
            'pub_date' => { 'value' => '2025-10-31' },
          },
        ],
      },
    }.to_json
  end

  let(:html_body) { '<html><body><p>test</p></body></html>' }
  let(:pdf_body)  { '%PDF-1.4 fake' }

  def guid
    'abc123def456'
  end

  before do
    allow(Kernel).to receive(:sleep)

    stub_request(:post, described_class::SPARQL_ENDPOINT)
      .to_return(status: 200, body: sparql_response_body,
                 headers: { 'Content-Type' => 'application/sparql-results+json' })

    stub_request(:get, cellar_html_url)
      .with(headers: { 'Accept' => 'application/xhtml+xml' })
      .to_return(status: 200, body: html_body)

    stub_request(:get, cellar_pdf_url)
      .to_return(status: 200, body: pdf_body, headers: { 'Content-Type' => 'application/pdf' })
  end

  describe '#call' do
    it 'returns a Result with the correct CELEX and dates' do
      result = fetcher.call.first
      expect(result.celex).to eq '32025R1926'
      expect(result.force_date).to eq Date.new(2026, 1, 1)
      expect(result.publication_date).to eq Date.new(2025, 10, 31)
    end

    it 'populates html_content, pdf_content, and pdf_checksum' do
      result = fetcher.call.first
      expect(result.html_content).to eq html_body
      expect(result.pdf_content).to eq pdf_body
      expect(result.pdf_checksum).to eq Digest::SHA256.hexdigest(pdf_body)
    end

    it 'stores the Cellar URL as cellar_url' do
      result = fetcher.call.first
      expect(result.cellar_url).to eq cellar_html_url
    end

    context 'when the version is already imported (not failed)' do
      before { create(:customs_tariff_update, version: '32025R1926') }

      it 'skips the version and returns an empty array' do
        expect(fetcher.call).to be_empty
      end
    end

    context 'when the version previously failed' do
      before { create(:customs_tariff_update, :failed, version: '32025R1926') }

      it 'retries the version' do
        expect(fetcher.call.length).to eq 1
      end
    end

    context 'with the SPARQL endpoint' do
      it 'returns empty when no bindings' do
        stub_request(:post, described_class::SPARQL_ENDPOINT)
          .to_return(status: 200, body: { 'results' => { 'bindings' => [] } }.to_json,
                     headers: { 'Content-Type' => 'application/sparql-results+json' })

        expect(fetcher.call).to be_empty
      end

      it 'retries on transient 500 then succeeds' do
        stub_request(:post, described_class::SPARQL_ENDPOINT)
          .to_return({ status: 500 }, { status: 200, body: sparql_response_body, headers: { 'Content-Type' => 'application/sparql-results+json' } })

        result = fetcher.call.first
        expect(result.celex).to eq '32025R1926'
        expect(a_request(:post, described_class::SPARQL_ENDPOINT)).to have_been_made.times(2)
      end

      it 'raises after exhausting retries on persistent 5xx' do
        stub_request(:post, described_class::SPARQL_ENDPOINT).to_return(status: 500)

        expect { fetcher.call }.to raise_error(described_class::RetryableHTTPError, 'HTTP 500')
        expect(a_request(:post, described_class::SPARQL_ENDPOINT)).to have_been_made.times(4)
      end

      it 'raises immediately without retrying on a client error (4xx)' do
        stub_request(:post, described_class::SPARQL_ENDPOINT).to_return(status: 404)

        expect { fetcher.call }.to raise_error(RuntimeError, 'SPARQL request failed: HTTP 404')
        expect(a_request(:post, described_class::SPARQL_ENDPOINT)).to have_been_made.times(1)
      end
    end

    context 'with the HTML endpoint' do
      it 'raises immediately without retrying when HTML fetch returns an error status' do
        stub_request(:get, cellar_html_url)
          .with(headers: { 'Accept' => 'application/xhtml+xml' })
          .to_return(status: 500)

        expect { fetcher.call }.to raise_error(RuntimeError, "Failed to fetch #{cellar_html_url}: HTTP 500")
        expect(a_request(:get, cellar_html_url)).to have_been_made.times(1)
      end
    end
  end
end
