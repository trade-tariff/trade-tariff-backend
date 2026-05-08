require 'zip'

RSpec.describe CustomsTariffImporter::Reimporter do
  subject(:reimporter) { described_class.new }

  def build_docx(*paragraph_texts)
    ns = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
    paras = paragraph_texts.map { |t|
      "<w:p><w:r><w:t>#{CGI.escapeHTML(t)}</w:t></w:r></w:p>"
    }.join
    xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <w:document xmlns:w="#{ns}"><w:body>#{paras}</w:body></w:document>
    XML
    buffer = StringIO.new.tap(&:binmode)
    Zip::OutputStream.write_buffer(buffer) do |z|
      z.put_next_entry('word/document.xml')
      z.write(xml)
    end
    StringIO.new(buffer.string)
  end

  let(:update) do
    create(:customs_tariff_update,
           version: '1.31',
           status: CustomsTariffUpdate::APPROVED,
           validity_start_date: Date.new(2026, 4, 1),
           s3_path: 'data/customs_tariff_documents/UKGT_1.31.docx')
  end

  let(:docx_io) do
    build_docx(
      'SECTION I', 'Section Notes', 'Live animals note.', 'CHAPTER 1',
      'Chapter Notes', 'All live animals are classified here.', 'CHAPTER 2'
    )
  end

  before do
    update
    allow(TariffSynchronizer::FileService).to receive(:get)
      .with(update.s3_path)
      .and_return(docx_io)
  end

  describe '#call' do
    context 'when note records already exist for the update' do
      before do
        create(:customs_tariff_section_note, customs_tariff_update: update, section_id: 1, content: 'Old section note.')
        create(:customs_tariff_chapter_note, customs_tariff_update: update, chapter_id: '01', content: 'Old chapter note.')
      end

      it 'replaces existing notes with freshly extracted content' do
        reimporter.call

        section_note = CustomsTariffSectionNote.where(
          customs_tariff_update_version: update.version, section_id: 1,
        ).first

        chapter_note = CustomsTariffChapterNote.where(
          customs_tariff_update_version: update.version, chapter_id: '01',
        ).first

        expect(section_note.content).to eq('Live animals note.')
        expect(chapter_note.content).to eq('All live animals are classified here.')
      end

      it 'sets newly created notes to pending status' do
        reimporter.call

        statuses = CustomsTariffSectionNote
          .where(customs_tariff_update_version: update.version)
          .select_map(:status)

        expect(statuses).to all(eq(CustomsTariffSectionNote::PENDING))
      end
    end

    context 'when no note records exist yet' do
      it 'inserts extracted notes' do
        expect { reimporter.call }
          .to change { CustomsTariffSectionNote.where(customs_tariff_update_version: update.version).count }.by(1)
          .and change { CustomsTariffChapterNote.where(customs_tariff_update_version: update.version).count }.by(1)
      end
    end

    context 'when there are no updates' do
      before { update.destroy }

      it 'does nothing' do
        allow(TariffSynchronizer::FileService).to receive(:get)
        expect { reimporter.call }.not_to raise_error
        expect(TariffSynchronizer::FileService).not_to have_received(:get)
      end
    end

    context 'when there are multiple updates' do
      let(:update2) do
        create(:customs_tariff_update,
               version: '1.30',
               status: CustomsTariffUpdate::PENDING,
               validity_start_date: Date.new(2026, 3, 1),
               s3_path: 'data/customs_tariff_documents/UKGT_1.30.docx')
      end
      let(:docx_io2) { build_docx('SECTION II', 'Section Notes', 'Vegetable products are classified here.', 'CHAPTER 6') }

      before do
        update2
        allow(TariffSynchronizer::FileService).to receive(:get)
          .with(update2.s3_path)
          .and_return(docx_io2)
      end

      it 'reimports notes for every non-failed update' do
        reimporter.call

        expect(CustomsTariffSectionNote.where(customs_tariff_update_version: '1.31').count).to eq(1)
        expect(CustomsTariffSectionNote.where(customs_tariff_update_version: '1.30').count).to eq(1)
      end
    end

    context 'when an update has FAILED status' do
      before { update.update(status: CustomsTariffUpdate::FAILED) }

      it 'skips failed updates' do
        allow(TariffSynchronizer::FileService).to receive(:get)
        reimporter.call
        expect(TariffSynchronizer::FileService).not_to have_received(:get)
      end
    end
  end
end
