require 'rails_helper'

RSpec.describe XiCnImporter::Reimporter do
  subject(:reimporter) { described_class.new }

  let(:celex)  { '32025R1926' }
  let(:update) do
    create(:customs_tariff_update,
           version: celex,
           s3_path: "data/customs_tariff_documents/xi/CN_#{celex}.pdf")
  end
  let(:html) { '<html><body></body></html>' }

  let(:extracted) do
    XiCnImporter::NotesExtractor::Result.new(
      sections: { 1 => 'Section content.' },
      chapters: { '01' => 'Chapter content.' },
      general_rules: { '1' => 'GRI content.' },
    )
  end

  before do
    update
    allow(TariffSynchronizer::FileService).to receive(:get)
      .with("data/customs_tariff_documents/xi/CN_#{celex}.xhtml")
      .and_return(StringIO.new(html))

    allow(XiCnImporter::NotesExtractor).to receive(:new).and_return(
      instance_double(XiCnImporter::NotesExtractor, call: extracted),
    )
  end

  describe '#call' do
    context 'with a specific version' do
      it 'deletes existing notes and recreates them' do
        create(:customs_tariff_section_note,
               customs_tariff_update: update,
               section_id: 1,
               content: 'old content')

        reimporter.call(version: celex)

        notes = CustomsTariffSectionNote.where(customs_tariff_update_version: celex).all
        expect(notes.length).to eq 1
        expect(notes.first.content).to eq 'Section content.'
      end

      it 'reads XHTML from S3 rather than fetching from Cellar' do
        reimporter.call(version: celex)
        expect(TariffSynchronizer::FileService)
          .to have_received(:get)
          .with("data/customs_tariff_documents/xi/CN_#{celex}.xhtml")
      end

      it 'is a no-op when the version does not exist' do
        expect { reimporter.call(version: 'nonexistent') }.not_to raise_error
      end

      context 'when the extractor returns an empty result' do
        before do
          allow(XiCnImporter::NotesExtractor).to receive(:new).and_return(
            instance_double(XiCnImporter::NotesExtractor,
                            call: XiCnImporter::NotesExtractor::Result.new(
                              sections: {}, chapters: {}, general_rules: {},
                            )),
          )
          create(:customs_tariff_section_note, customs_tariff_update: update, section_id: 1, content: 'existing')
        end

        it 'raises rather than wiping notes' do
          expect { reimporter.call(version: celex) }.to raise_error(/Empty extract/)
        end

        it 'leaves existing notes intact' do
          expect { reimporter.call(version: celex) }.to raise_error(/Empty extract/)
          expect(CustomsTariffSectionNote.where(customs_tariff_update_version: celex).count).to eq 1
        end
      end
    end

    context 'without a version (reimport all)' do
      let(:second_update) do
        create(:customs_tariff_update,
               version: '32024R1234',
               s3_path: 'data/customs_tariff_documents/xi/CN_32024R1234.pdf')
      end

      before do
        second_update
        allow(TariffSynchronizer::FileService).to receive(:get)
          .with("data/customs_tariff_documents/xi/CN_#{second_update.version}.xhtml")
          .and_return(StringIO.new(html))
      end

      it 'reimports all non-failed updates' do
        reimporter.call
        expect(XiCnImporter::NotesExtractor).to have_received(:new).twice
      end

      context 'when one update fails during reimport-all' do
        before do
          call_count = 0
          allow(XiCnImporter::NotesExtractor).to receive(:new) do
            call_count += 1
            if call_count == 1
              instance_double(XiCnImporter::NotesExtractor, call: extracted)
            else
              instance_double(XiCnImporter::NotesExtractor).tap { |d| allow(d).to receive(:call).and_raise(RuntimeError, 'parse error') }
            end
          end
        end

        it 'continues to the next update after a failure' do
          expect { reimporter.call }.not_to raise_error
          expect(XiCnImporter::NotesExtractor).to have_received(:new).twice
        end
      end
    end
  end
end
