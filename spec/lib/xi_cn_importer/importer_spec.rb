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
      cellar_url: 'https://publications.europa.eu/resource/cellar/abc.0006.03/DOC_1',
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
    allow(XiCnImporter::Instrumentation).to receive(:document_imported)
    allow(XiCnImporter::Instrumentation).to receive(:document_import_failed)
  end

  describe '#call' do
    it 'writes the PDF to S3 at the XI prefix path' do
      importer.call
      expect(TariffSynchronizer::FileService)
        .to have_received(:write_file)
        .with("data/customs_tariff_documents/xi/CN_#{celex}.pdf", pdf_content)
    end

    it 'writes the XHTML to S3 at the XI prefix path' do
      importer.call
      expect(TariffSynchronizer::FileService)
        .to have_received(:write_file)
        .with("data/customs_tariff_documents/xi/CN_#{celex}.xhtml", html_content)
    end

    it 'persists the update attributes' do
      expect { importer.call }
        .to change { CustomsTariffUpdate.where(version: celex).count }.by(1)

      update = CustomsTariffUpdate.first(version: celex)
      expect(update).to have_attributes(
        version: celex,
        validity_start_date: force_date,
        import_error: nil,
        source_url: fetched_result.cellar_url,
        s3_path: "data/customs_tariff_documents/xi/CN_#{celex}.pdf",
        file_checksum: pdf_checksum,
        document_created_on: fetched_result.publication_date,
      )
    end

    it 'persists the note attributes', :aggregate_failures do
      importer.call

      sections = CustomsTariffSectionNote.where(customs_tariff_update_version: celex).all
      chapters = CustomsTariffChapterNote.where(customs_tariff_update_version: celex).all
      general_rules = CustomsTariffGeneralRule.where(customs_tariff_update_version: celex).all

      expect(sections).to contain_exactly(
        have_attributes(
          customs_tariff_update_version: celex,
          section_id: 1,
          content: extracted_result.sections.fetch(1),
          validity_start_date: force_date,
        ),
      )
      expect(chapters).to contain_exactly(
        have_attributes(
          customs_tariff_update_version: celex,
          chapter_id: '01',
          content: extracted_result.chapters.fetch('01'),
          validity_start_date: force_date,
        ),
      )
      expect(general_rules).to contain_exactly(
        have_attributes(
          customs_tariff_update_version: celex,
          rule_label: '1',
          content: extracted_result.general_rules.fetch('1'),
          validity_start_date: force_date,
        ),
      )
    end

    it 'returns :imported status' do
      results = importer.call
      expect(results.first.status).to eq :imported
      expect(results.first.celex).to eq celex
    end

    it 'instruments a successful import' do
      importer.call

      expect(XiCnImporter::Instrumentation).to have_received(:document_imported).with(
        celex:,
        duration_ms: a_kind_of(Numeric),
      ).once
      expect(XiCnImporter::Instrumentation).not_to have_received(:document_import_failed)
    end

    context 'with a pre-existing failed update' do
      before do
        CustomsTariffUpdate.create(
          version: celex,
          validity_start_date: 1.year.ago.to_date,
          import_error: 'previous failure',
        )
      end

      it 'replaces it with one imported update' do
        importer.call

        updates = CustomsTariffUpdate.where(version: celex).all
        expect(updates).to contain_exactly(
          have_attributes(import_error: nil),
        )
      end
    end

    context 'when a later note write fails' do
      before do
        allow(CustomsTariffChapterNote).to receive(:create)
          .and_raise(RuntimeError, 'persistence error')
      end

      it 'rolls back before recording failure', :aggregate_failures do
        results = importer.call

        updates = CustomsTariffUpdate.where(version: celex).all
        expect(results.first).to have_attributes(
          status: :failed,
          celex:,
          error: 'persistence error',
        )
        expect(updates).to contain_exactly(
          have_attributes(import_error: 'persistence error'),
        )
        expect(CustomsTariffSectionNote.where(customs_tariff_update_version: celex).count).to eq 0
        expect(CustomsTariffChapterNote.where(customs_tariff_update_version: celex).count).to eq 0
        expect(CustomsTariffGeneralRule.where(customs_tariff_update_version: celex).count).to eq 0
        expect(XiCnImporter::Instrumentation).to have_received(:document_import_failed).with(
          celex:,
          error_class: 'RuntimeError',
          error_message: 'persistence error',
        ).once
        expect(XiCnImporter::Instrumentation).not_to have_received(:document_imported)
      end
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

      it 'creates a failed CustomsTariffUpdate with the import error' do
        importer.call
        update = CustomsTariffUpdate.first(version: celex)
        expect(update.import_error).to eq 'parse error'
      end

      it 'instruments the failed import' do
        importer.call

        expect(XiCnImporter::Instrumentation).to have_received(:document_import_failed).with(
          celex:,
          error_class: 'RuntimeError',
          error_message: 'parse error',
        ).once
        expect(XiCnImporter::Instrumentation).not_to have_received(:document_imported)
      end

      context 'when a pre-existing failed record exists' do
        it 'refreshes the error message and timestamp' do
          old_error = 'previous import error'
          old_updated_at = travel_to 2.days.ago do
            CustomsTariffUpdate.create(
              version: celex,
              validity_start_date: Time.zone.today,
              import_error: old_error,
            ).updated_at
          end

          travel_to 1.day.ago do
            importer.call
          end

          update = CustomsTariffUpdate.first(version: celex)
          expect(update.import_error).to eq 'parse error'
          expect(update.updated_at).to be > old_updated_at
        end
      end
    end
  end
end
