RSpec.describe GovUkTariffDocumentFetcher do
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

      # Mirrors the real GOV.UK gem-c-attachment structure: a thumbnail <a> and a
      # title <h3><a> per attachment. Only the <h3> link carries the date text.
      let(:html) do
        <<~HTML
          <html><body>
            <div class="gem-c-attachment">
              <a class="gem-c-attachment__thumbnail-image" href="https://assets.publishing.service.gov.uk/media/abc/UKGT_1.30.docx"></a>
              <h3 class="gem-c-attachment__title">
                <a href="https://assets.publishing.service.gov.uk/media/abc/UKGT_1.30.docx">
                  The Tariff of the United Kingdom, version 1.30, dated 14 January 2026 (entry into force 22 January 2026)
                </a>
              </h3>
            </div>
            <div class="gem-c-attachment">
              <a class="gem-c-attachment__thumbnail-image" href="https://assets.publishing.service.gov.uk/media/def/UKGT_1.31.docx"></a>
              <h3 class="gem-c-attachment__title">
                <a href="https://assets.publishing.service.gov.uk/media/def/UKGT_1.31.docx">
                  The Tariff of the United Kingdom, version 1.31, dated 3 March 2026 (entry into force 1 April 2026)
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
          'https://assets.publishing.service.gov.uk/media/abc/UKGT_1.30.docx',
          'https://assets.publishing.service.gov.uk/media/def/UKGT_1.31.docx',
        )
      end

      it 'returns the link text for each document' do
        expect(links.first[:text]).to include('version 1.30')
        expect(links.last[:text]).to include('version 1.31')
      end

      context 'when there are no .docx links' do
        let(:html) { '<html><body><p>No attachments here</p></body></html>' }

        it 'returns an empty array' do
          expect(links).to eq([])
        end
      end
    end
  end
end
