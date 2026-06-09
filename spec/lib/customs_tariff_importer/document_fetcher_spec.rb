RSpec.describe CustomsTariffImporter::DocumentFetcher do
  subject(:fetcher) { described_class.new }

  describe '#call (unit: date parsing and link extraction)' do
    describe 'parse_entry_into_force_date (private)' do
      subject(:parse) { fetcher.send(:parse_entry_into_force_date, text) }

      context 'with standard link text' do
        let(:text) do
          'The Tariff of the United Kingdom, version 1.30, dated 14 January 2026 (entry into force 22 January 2026)'
        end

        it 'parses the entry into force date' do
          expect(parse).to eq(Date.new(2026, 1, 22))
        end
      end

      context 'with a different month and year' do
        let(:text) do
          'The Tariff of the United Kingdom, version 1.31, dated 3 March 2026 (entry into force 1 April 2026)'
        end

        it 'parses the entry into force date' do
          expect(parse).to eq(Date.new(2026, 4, 1))
        end
      end

      context 'when text contains no entry into force date' do
        let(:text) { 'The Tariff of the United Kingdom, version 1.30, dated 14 January 2026' }

        it 'returns nil' do
          expect(parse).to be_nil
        end
      end
    end

    describe 'parse_dated_date (private)' do
      subject(:parse) { fetcher.send(:parse_dated_date, text) }

      context 'with standard link text' do
        let(:text) do
          'The Tariff of the United Kingdom, version 1.30, dated 14 January 2026 (entry into force 22 January 2026)'
        end

        it 'parses the dated publication date' do
          expect(parse).to eq(Date.new(2026, 1, 14))
        end
      end

      context 'with a single-digit day' do
        let(:text) do
          'The Tariff of the United Kingdom, version 1.31, dated 3 March 2026 (entry into force 1 April 2026)'
        end

        it 'parses the dated publication date' do
          expect(parse).to eq(Date.new(2026, 3, 3))
        end
      end

      context 'when text contains no dated date' do
        let(:text) { 'The Tariff of the United Kingdom' }

        it 'returns nil' do
          expect(parse).to be_nil
        end
      end
    end

    describe 'all_docx_links (private)' do
      subject(:links) { fetcher.send(:all_docx_links, html) }

      let(:html) do
        <<~HTML
          <html><body>
            <div class="gem-c-attachment">
              <a class="gem-c-attachment__thumbnail-image" href="https://assets.publishing.service.gov.uk/media/abc/The_Tariff_of_the_United_Kingdom_1.31.docx"></a>
              <h3 class="gem-c-attachment__title">
                <a href="https://assets.publishing.service.gov.uk/media/abc/The_Tariff_of_the_United_Kingdom_1.31.docx">
                  The Tariff of the United Kingdom, version 1.31, dated 3 March 2026 (entry into force 1 April 2026)
                </a>
              </h3>
            </div>
            <div class="gem-c-attachment">
              <a class="gem-c-attachment__thumbnail-image" href="https://assets.publishing.service.gov.uk/media/def/The_Tariff_of_the_United_Kingdom_1.32.docx"></a>
              <h3 class="gem-c-attachment__title">
                <a href="https://assets.publishing.service.gov.uk/media/def/The_Tariff_of_the_United_Kingdom_1.32.docx">
                  The Tariff of the United Kingdom, version 1.32, dated 14 January 2026 (entry into force 22 January 2026)
                </a>
              </h3>
            </div>
            <div class="gem-c-attachment">
              <h3 class="gem-c-attachment__title">
                <a href="https://assets.publishing.service.gov.uk/media/ghi/some_other_file.pdf">
                  Some PDF document
                </a>
              </h3>
            </div>
          </body></html>
        HTML
      end

      it 'returns only .docx links' do
        expect(links.size).to eq(2)
      end

      it 'returns the correct URLs' do
        expect(links.map { |l| l[:url] }).to contain_exactly(
          'https://assets.publishing.service.gov.uk/media/abc/The_Tariff_of_the_United_Kingdom_1.31.docx',
          'https://assets.publishing.service.gov.uk/media/def/The_Tariff_of_the_United_Kingdom_1.32.docx',
        )
      end

      it 'returns the link text for each document' do
        expect(links.first[:text]).to include('version 1.31')
        expect(links.last[:text]).to include('version 1.32')
      end

      context 'when there are no .docx links' do
        let(:html) { '<html><body><p>No attachments here</p></body></html>' }

        it 'returns an empty array' do
          expect(links).to eq([])
        end
      end
    end

    describe 'extract_version (private)' do
      subject(:extract) { fetcher.send(:extract_version, url, text) }

      context 'when text contains "version X.Y"' do
        let(:url)  { 'https://assets.publishing.service.gov.uk/media/abc/The_Tariff_of_the_United_Kingdom_1.32.docx' }
        let(:text) { 'The Tariff of the United Kingdom, version 1.32, dated 14 January 2026 (entry into force 22 January 2026)' }

        it 'returns the version from the link text' do
          expect(extract).to eq('1.32')
        end
      end

      context 'when text has no version label but URL has _X.Y.docx' do
        let(:url)  { 'https://assets.publishing.service.gov.uk/media/abc/The_Tariff_of_the_United_Kingdom_1.30.docx' }
        let(:text) { 'Some document with no version label' }

        it 'falls back to the URL pattern' do
          expect(extract).to eq('1.30')
        end
      end

      context 'when text version and URL version differ' do
        let(:url)  { 'https://assets.publishing.service.gov.uk/media/abc/The_Tariff_of_the_United_Kingdom_1.30.docx' }
        let(:text) { 'The Tariff of the United Kingdom, version 1.32, dated 14 January 2026' }

        it 'prefers the text version' do
          expect(extract).to eq('1.32')
        end
      end

      context 'when neither text nor URL contains a version' do
        let(:url)  { 'https://assets.publishing.service.gov.uk/media/abc/document.docx' }
        let(:text) { 'Some document' }

        it 'returns nil' do
          expect(extract).to be_nil
        end
      end
    end
  end

  describe '#call instrumentation' do
    let(:docx_url) { 'https://assets.publishing.service.gov.uk/media/abc/The_Tariff_of_the_United_Kingdom_1.32.docx' }
    let(:link_text) { 'The Tariff of the United Kingdom, version 1.32, dated 14 January 2026 (entry into force 22 January 2026)' }
    let(:page_html) do
      <<~HTML
        <html><body>
          <h3 class="gem-c-attachment__title">
            <a href="#{docx_url}">#{link_text}</a>
          </h3>
        </body></html>
      HTML
    end

    before do
      stub_request(:get, described_class::PUBLICATION_URL).to_return(body: page_html)
      stub_request(:get, docx_url).to_return(body: 'fake docx binary')
      allow(CustomsTariffImporter::Instrumentation).to receive(:fetch_started)
      allow(CustomsTariffImporter::Instrumentation).to receive(:document_fetched)
      allow(CustomsTariffImporter::Instrumentation).to receive(:fetch_failed)
    end

    it 'emits fetch_started with the publication URL' do
      fetcher.call
      expect(CustomsTariffImporter::Instrumentation).to have_received(:fetch_started).with(
        url: described_class::PUBLICATION_URL,
      )
    end

    it 'emits document_fetched for each document with version and timing' do
      fetcher.call
      expect(CustomsTariffImporter::Instrumentation).to have_received(:document_fetched).with(
        version: '1.32',
        duration_ms: a_kind_of(Float),
      )
    end

    context 'when fetching raises' do
      before { stub_request(:get, described_class::PUBLICATION_URL).to_raise(RuntimeError.new('timeout')) }

      it 'emits fetch_failed and re-raises' do
        expect { fetcher.call }.to raise_error(RuntimeError)
        expect(CustomsTariffImporter::Instrumentation).to have_received(:fetch_failed).with(
          url: described_class::PUBLICATION_URL,
          error_class: 'RuntimeError',
          error_message: 'timeout',
        )
      end
    end
  end
end
