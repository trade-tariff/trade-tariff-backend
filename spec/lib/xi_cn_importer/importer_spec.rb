require 'rails_helper'

RSpec.describe XiCnImporter::Importer do
  subject(:importer) { described_class.new }

  let(:celex)        { '32025R1926' }
  let(:force_date)   { Date.new(2026, 1, 1) }
  let(:html_content) { '<html><body></body></html>' }
  let(:pdf_content)  { '%PDF-1.4 stub' }
  let(:pdf_checksum) { Digest::SHA256.hexdigest(pdf_content) }

  let(:fetched_result) do
    XiCnImporter::DocumentFetcher::Result.new(
      celex:,
      force_date:,
      publication_date: Date.new(2025, 10, 31),
      cellar_url: 'http://publications.europa.eu/resource/cellar/abc.0006.03/DOC_1',
      html_content:,
      pdf_content:,
      pdf_checksum:,
    )
  end

  let(:extracted_result) do
    XiCnImporter::NotesExtractor::Result.new(
      sections: { 1 => 'Section I note content.' },
      chapters: { '01' => 'Chapter 1 note content.' },
      general_rules: { '1' => 'GRI rule one.' },
    )
  end

  before do
    allow(XiCnImporter::DocumentFetcher).to receive(:new).and_return(
      instance_double(XiCnImporter::DocumentFetcher, call: [fetched_result]),
    )
    allow(XiCnImporter::NotesExtractor).to receive(:new).and_return(
      instance_double(XiCnImporter::NotesExtractor, call: extracted_result),
    )
    allow(TariffSynchronizer::FileService).to receive(:write_file)
  end

  describe '#call' do
    it 'writes the PDF to S3 at the XI prefix path' do
      importer.call
      expect(TariffSynchronizer::FileService)
        .to have_received(:write_file)
        .with("data/customs_tariff_documents/xi/CN_#{celex}.pdf", pdf_content)
    end

    it 'creates a CustomsTariffUpdate with status pending' do
      expect { importer.call }
        .to change { CustomsTariffUpdate.where(version: celex).count }.by(1)

      update = CustomsTariffUpdate.first(version: celex)
      expect(update.status).to eq CustomsTariffUpdate::PENDING
      expect(update.validity_start_date).to eq force_date
    end

    it 'creates chapter, section, and general rule notes' do
      importer.call
      expect(CustomsTariffChapterNote.where(customs_tariff_update_version: celex).count).to eq 1
      expect(CustomsTariffSectionNote.where(customs_tariff_update_version: celex).count).to eq 1
      expect(CustomsTariffGeneralRule.where(customs_tariff_update_version: celex).count).to eq 1
    end

    it 'returns :imported status' do
      results = importer.call
      expect(results.first.status).to eq :imported
      expect(results.first.celex).to eq celex
    end

    context 'when extraction raises an error' do
      before do
        allow(XiCnImporter::NotesExtractor).to receive(:new).and_raise(RuntimeError, 'parse error')
      end

      it 'returns :failed status' do
        results = importer.call
        expect(results.first.status).to eq :failed
        expect(results.first.error).to eq 'parse error'
      end

      it 'creates a failed CustomsTariffUpdate' do
        importer.call
        update = CustomsTariffUpdate.first(version: celex)
        expect(update.status).to eq CustomsTariffUpdate::FAILED
      end

      context 'when a pre-existing FAILED record exists' do
        it 'refreshes the error message and timestamp' do
          old_error = 'previous import error'
          old_timestamp = 2.days.ago
          CustomsTariffUpdate.create(
            version: celex,
            validity_start_date: old_timestamp.to_date,
            status: CustomsTariffUpdate::FAILED,
            import_error: old_error,
          )

          travel_to 1.day.ago do
            importer.call
          end

          update = CustomsTariffUpdate.first(version: celex)
          expect(update.status).to eq CustomsTariffUpdate::FAILED
          expect(update.import_error).to eq 'parse error'
          expect(update.updated_at).to be > old_timestamp
        end
      end
    end
  end
end
