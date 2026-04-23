RSpec.describe ImportCustomsTariffDocumentService do
  subject(:results) { described_class.new.call }

  let(:docx_content) { 'fake docx binary content' }
  let(:docx_url)     { 'https://assets.publishing.service.gov.uk/media/abc123/UKGT_1.30.docx' }
  let(:version)      { '1.30' }
  let(:checksum)     { Digest::SHA256.hexdigest(docx_content) }
  let(:published_on)         { Date.new(2026, 1, 14) }
  let(:entry_into_force_on)  { Date.new(2026, 1, 22) }

  let(:fetched_result) do
    GovUkTariffDocumentFetcher::Result.new(
      content: docx_content,
      url: docx_url,
      version:,
      checksum:,
      published_on:,
      entry_into_force_on:,
    )
  end

  let(:extracted_result) do
    TariffNotesExtractor::Result.new(
      chapters: { '01' => 'Chapter 1 notes content', '02' => 'Chapter 2 notes content' },
      sections: { 'I' => 'Section I notes content' },
      general_rules: { '1' => 'Rule 1 content', '2' => 'Rule 2 content' },
    )
  end

  before do
    allow(GovUkTariffDocumentFetcher).to receive(:new).and_return(
      instance_double(GovUkTariffDocumentFetcher, call: [fetched_result]),
    )
    allow(TariffNotesExtractor).to receive(:new).and_return(
      instance_double(TariffNotesExtractor, call: extracted_result),
    )
    allow(TariffSynchronizer::FileService).to receive(:write_file)
  end

  describe '#call' do
    it 'returns an array of results' do
      expect(results).to be_an(Array)
    end

    context 'when the document is new' do
      it 'returns an imported result' do
        expect(results.first.status).to eq(:imported)
        expect(results.first.version).to eq('1.30')
      end

      it 'archives the document to S3' do
        results
        expect(TariffSynchronizer::FileService).to have_received(:write_file).with(
          'data/customs_tariff_documents/UKGT_1.30.docx',
          docx_content,
        )
      end

      it 'creates a CustomsTariffUpdate record awaiting approval' do
        expect { results }.to change(CustomsTariffUpdate, :count).by(1)
        update = CustomsTariffUpdate.where(version: '1.30').first
        expect(update.status).to eq(CustomsTariffUpdate::PENDING)
        expect(update.file_checksum).to eq(checksum)
      end

      it 'sets validity_start_date to entry_into_force_on' do
        results
        update = CustomsTariffUpdate.where(version: '1.30').first
        expect(update.validity_start_date).to eq(entry_into_force_on)
      end

      it 'sets document_created_on to the dated (published) date' do
        results
        update = CustomsTariffUpdate.where(version: '1.30').first
        expect(update.document_created_on).to eq(published_on)
      end

      it 'creates associated chapter notes' do
        results
        expect(CustomsTariffChapterNote.where(customs_tariff_update_version: '1.30').count).to eq(2)
      end

      it 'creates associated section notes' do
        results
        expect(CustomsTariffSectionNote.where(customs_tariff_update_version: '1.30').count).to eq(1)
      end

      it 'creates associated general rules' do
        results
        expect(CustomsTariffGeneralRule.where(customs_tariff_update_version: '1.30').count).to eq(2)
      end
    end

    context 'when two documents are returned' do
      let(:docx_content_2) { 'fake docx binary content v2' }
      let(:fetched_result_2) do
        GovUkTariffDocumentFetcher::Result.new(
          content: docx_content_2,
          url: 'https://assets.publishing.service.gov.uk/media/def456/UKGT_1.31.docx',
          version: '1.31',
          checksum: Digest::SHA256.hexdigest(docx_content_2),
          published_on: Date.new(2026, 3, 3),
          entry_into_force_on: Date.new(2026, 4, 1),
        )
      end

      before do
        allow(GovUkTariffDocumentFetcher).to receive(:new).and_return(
          instance_double(GovUkTariffDocumentFetcher, call: [fetched_result, fetched_result_2]),
        )
      end

      it 'imports both documents in one call' do
        expect { results }.to change(CustomsTariffUpdate, :count).by(2)
        expect(results.map(&:version)).to eq(%w[1.30 1.31])
        expect(results.map(&:status)).to eq(%i[imported imported])
      end
    end

    context 'when the version has already been imported' do
      before { create(:customs_tariff_update, version: '1.30') }

      it 'returns a skipped result' do
        expect(results.first.status).to eq(:skipped)
      end

      it 'does not fetch or store anything' do
        results
        expect(TariffSynchronizer::FileService).not_to have_received(:write_file)
      end
    end

    context 'when a different version with the same content has been imported' do
      before { create(:customs_tariff_update, version: '1.29', file_checksum: checksum) }

      it 'returns a duplicate_content result' do
        expect(results.first.status).to eq(:duplicate_content)
      end
    end

    context 'when fetching fails' do
      before do
        allow(GovUkTariffDocumentFetcher).to receive(:new).and_return(
          instance_double(GovUkTariffDocumentFetcher).tap do |dbl|
            allow(dbl).to receive(:call).and_raise(RuntimeError, 'HTTP 503')
          end,
        )
      end

      it 'returns a failed result' do
        expect(results.first.status).to eq(:failed)
        expect(results.first.error).to eq('HTTP 503')
      end

      it 'does not create any database records' do
        expect { results }.not_to change(CustomsTariffUpdate, :count)
      end
    end

    context 'when parsing succeeds but database write fails' do
      before do
        allow(CustomsTariffUpdate).to receive(:create).and_raise(Sequel::Error, 'DB error')
      end

      it 'returns a failed result' do
        expect(results.first.status).to eq(:failed)
      end
    end
  end
end
