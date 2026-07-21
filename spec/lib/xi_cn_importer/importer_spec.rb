require 'rails_helper'

RSpec.describe XiCnImporter::Importer do
  subject(:importer) { described_class.new }

  let(:fetched_result) do
    pdf_content = '%PDF-1.4 stub'
    XiCnImporter::DocumentFetcher::Result.new(
      celex: '32025R1926',
      force_date: Date.new(2026, 1, 1),
      publication_date: Date.new(2025, 10, 31),
      cellar_url: 'https://publications.europa.eu/resource/cellar/abc.0006.03/DOC_1',
      html_content: '<html><body></body></html>',
      pdf_content:,
      pdf_checksum: Digest::SHA256.hexdigest(pdf_content),
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
        .with("data/customs_tariff_documents/xi/CN_#{fetched_result.celex}.pdf", fetched_result.pdf_content)
    end

    it 'writes the XHTML to S3 at the XI prefix path' do
      importer.call
      expect(TariffSynchronizer::FileService)
        .to have_received(:write_file)
        .with("data/customs_tariff_documents/xi/CN_#{fetched_result.celex}.xhtml", fetched_result.html_content)
    end

    it 'persists the update attributes' do
      expect { importer.call }
        .to change { CustomsTariffUpdate.where(version: fetched_result.celex).count }.by(1)

      update = CustomsTariffUpdate.first(version: fetched_result.celex)
      expect(update).to have_attributes(
        version: fetched_result.celex,
        validity_start_date: fetched_result.force_date,
        import_error: nil,
        source_url: fetched_result.cellar_url,
        s3_path: "data/customs_tariff_documents/xi/CN_#{fetched_result.celex}.pdf",
        file_checksum: fetched_result.pdf_checksum,
        document_created_on: fetched_result.publication_date,
      )
    end

    it 'persists the note attributes', :aggregate_failures do
      importer.call

      sections = CustomsTariffSectionNote.where(customs_tariff_update_version: fetched_result.celex).all
      chapters = CustomsTariffChapterNote.where(customs_tariff_update_version: fetched_result.celex).all
      general_rules = CustomsTariffGeneralRule.where(customs_tariff_update_version: fetched_result.celex).all

      expect(sections).to contain_exactly(
        have_attributes(
          customs_tariff_update_version: fetched_result.celex,
          section_id: 1,
          content: extracted_result.sections.fetch(1),
          validity_start_date: fetched_result.force_date,
        ),
      )
      expect(chapters).to contain_exactly(
        have_attributes(
          customs_tariff_update_version: fetched_result.celex,
          chapter_id: '01',
          content: extracted_result.chapters.fetch('01'),
          validity_start_date: fetched_result.force_date,
        ),
      )
      expect(general_rules).to contain_exactly(
        have_attributes(
          customs_tariff_update_version: fetched_result.celex,
          rule_label: '1',
          content: extracted_result.general_rules.fetch('1'),
          validity_start_date: fetched_result.force_date,
        ),
      )
    end

    it 'returns :imported status' do
      results = importer.call
      expect(results.first.status).to eq :imported
      expect(results.first.celex).to eq fetched_result.celex
    end

    it 'instruments a successful import' do
      importer.call

      expect(XiCnImporter::Instrumentation).to have_received(:document_imported).with(
        celex: fetched_result.celex,
        duration_ms: a_kind_of(Numeric),
      ).once
      expect(XiCnImporter::Instrumentation).not_to have_received(:document_import_failed)
    end

    context 'with a pre-existing failed update' do
      before do
        CustomsTariffUpdate.create(
          version: fetched_result.celex,
          validity_start_date: 1.year.ago.to_date,
          import_error: 'previous failure',
        )
      end

      it 'replaces it with one imported update' do
        importer.call

        updates = CustomsTariffUpdate.where(version: fetched_result.celex).all
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

        updates = CustomsTariffUpdate.where(version: fetched_result.celex).all
        expect(results.first).to have_attributes(
          status: :failed,
          celex: fetched_result.celex,
          error: 'persistence error',
        )
        expect(updates).to contain_exactly(
          have_attributes(import_error: 'persistence error'),
        )
        expect(CustomsTariffSectionNote.where(customs_tariff_update_version: fetched_result.celex).count).to eq 0
        expect(CustomsTariffChapterNote.where(customs_tariff_update_version: fetched_result.celex).count).to eq 0
        expect(CustomsTariffGeneralRule.where(customs_tariff_update_version: fetched_result.celex).count).to eq 0
        expect(XiCnImporter::Instrumentation).to have_received(:document_import_failed).with(
          celex: fetched_result.celex,
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
        update = CustomsTariffUpdate.first(version: fetched_result.celex)
        expect(update.import_error).to eq 'parse error'
      end

      it 'instruments the failed import' do
        importer.call

        expect(XiCnImporter::Instrumentation).to have_received(:document_import_failed).with(
          celex: fetched_result.celex,
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
              version: fetched_result.celex,
              validity_start_date: Time.zone.today,
              import_error: old_error,
            ).updated_at
          end

          travel_to 1.day.ago do
            importer.call
          end

          update = CustomsTariffUpdate.first(version: fetched_result.celex)
          expect(update.import_error).to eq 'parse error'
          expect(update.updated_at).to be > old_updated_at
        end
      end
    end
  end
end
