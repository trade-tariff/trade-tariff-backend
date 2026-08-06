require 'tmpdir'

RSpec.describe VatGuidance::ContextGraphSource do
  subject(:result) { described_class.new.call }

  before do
    described_class::DOCUMENT_PATHS.each_value do |path|
      stub_content_api(path, content_payload(path))
    end
  end

  it 'collects directly referenced GOV.UK documents to a bounded depth' do
    root_path = described_class::DOCUMENT_PATHS.fetch('701-23')
    referenced_path = '/guidance/referenced-vat-notice'
    deeper_path = '/guidance/deeper-vat-notice'
    stub_content_api(
      root_path,
      content_payload(
        root_path,
        body: <<~HTML,
          <p>
            <a href="https://www.gov.uk#{referenced_path}#rate">Referenced notice</a>
            <a href="https://example.com/not-official">Other site</a>
          </p>
        HTML
      ),
    )
    stub_content_api(
      referenced_path,
      content_payload(referenced_path, body: %(<a href="#{deeper_path}">Deeper notice</a>)),
    )

    expect(result.payloads.pluck('base_path')).to contain_exactly(
      *described_class::DOCUMENT_PATHS.values,
      referenced_path,
    )
    expect(a_request(:get, content_api_url(deeper_path))).not_to have_been_made
    expect(result.failures).to be_empty
  end

  it 'follows Content API redirects and records aliases and failed sources' do
    root_path = described_class::DOCUMENT_PATHS.fetch('701-14')
    redirecting_path = '/vat-record-keeping/vat-invoices'
    canonical_path = '/vat-record-keeping'
    missing_path = '/guidance/withdrawn-vat-notice'
    stub_content_api(
      root_path,
      content_payload(
        root_path,
        body: <<~HTML,
          <a href="#{redirecting_path}">Record keeping</a>
          <a href="#{missing_path}">Withdrawn notice</a>
        HTML
      ),
    )
    stub_request(:get, content_api_url(redirecting_path)).to_return(
      status: 303,
      headers: { 'Location' => content_api_url(canonical_path) },
    )
    stub_content_api(canonical_path, content_payload(canonical_path))
    stub_request(:get, content_api_url(missing_path)).to_return(status: 404)

    expect(result.payloads.pluck('base_path')).to include(canonical_path)
    expect(result.path_aliases).to include(redirecting_path => canonical_path)
    expect(result.failures.fetch(missing_path)).to include('HTTP 404')
  end

  it 'fails the build when a required root document cannot be fetched' do
    root_path = described_class::DOCUMENT_PATHS.fetch('701-23')
    stub_request(:get, content_api_url(root_path)).to_return(status: 503)

    expect { result }.to raise_error(described_class::FetchError, /HTTP 503/)
  end

  it 'loads root and additional snapshots without network requests' do
    Dir.mktmpdir do |directory|
      described_class::DOCUMENT_PATHS.each do |key, path|
        File.write(File.join(directory, "vat-#{key}.json"), JSON.generate(content_payload(path)))
      end
      File.write(
        File.join(directory, 'referenced.json'),
        JSON.generate(content_payload('/guidance/referenced-vat-notice')),
      )

      snapshot_result = described_class.new(source_directory: directory).call

      expect(snapshot_result.payloads.length).to eq(5)
      expect(snapshot_result.root_paths).to eq(described_class::DOCUMENT_PATHS.values)
      expect(a_request(:any, /www\.gov\.uk/)).not_to have_been_made
    end
  end

  def stub_content_api(path, payload)
    stub_request(:get, content_api_url(path)).to_return(
      status: 200,
      headers: { 'Content-Type' => 'application/json' },
      body: JSON.generate(payload),
    )
  end

  def content_api_url(path)
    "https://www.gov.uk/api/content#{path}"
  end

  def content_payload(path, body: '<p>Content</p>')
    {
      'base_path' => path,
      'content_id' => SecureRandom.uuid,
      'title' => "Document for #{path}",
      'details' => { 'body' => body },
    }
  end
end
