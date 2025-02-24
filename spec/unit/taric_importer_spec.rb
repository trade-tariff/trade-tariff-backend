RSpec.describe TaricImporter do
  before do
    allow(TradeTariffBackend).to receive(:service).and_return('xi')
  end

  describe '#import' do
    let(:example_date) { Date.new(2013, 8, 2) }
    let(:example_date2) { Date.new(2014, 8, 2) }
    let(:taric_update) { create :taric_update, example_date: }
    let(:taric_update2) { create :taric_update, example_date: example_date2 }

    before do
      ExplicitAbrogationRegulation.unrestrict_primary_key
      allow(taric_update).to receive(:file_path)
        .and_return('spec/fixtures/taric_samples/unknown_record.xml')
    end

    context 'when importing a record that triggers an error' do
      before do
        allow(taric_update).to receive(:file_path)
          .and_return('spec/fixtures/taric_samples/broken_insert_record.xml')
      end

      it 'raises TaricImportException' do
        importer = described_class.new(taric_update)
        expect { importer.import }.to raise_error TaricImporter::ImportException
      end

      it 'logs an error event', :aggregate_failures do
        allow(Rails.logger).to receive(:error)
        importer = described_class.new(taric_update)
        expect { importer.import }.to raise_error TaricImporter::ImportException
        expect(Rails.logger).to have_received(:error)
        expect(Rails.logger).to have_received(:error).with(include('Taric import failed: uninitialized constant'))
      end
    end

    context 'when importing a complex record' do
      let(:taric_file_path) { 'spec/fixtures/taric_samples/create_measure.xml' }
      let(:taric_update_path) { 'spec/fixtures/taric_samples/update_measure.xml' }

      before do
        Measure.unrestrict_primary_key
        allow(taric_update).to receive(:file_path)
          .and_return('spec/fixtures/taric_samples/create_measure.xml')
        allow(taric_update2).to receive(:file_path)
          .and_return('spec/fixtures/taric_samples/update_measure.xml')
      end

      after { Measure.restrict_primary_key }

      it 'imports single Measure' do
        described_class.new(taric_update).import
        expect(Measure.count).to eq 1
      end

      it 'imports single Measure and updates it' do
        described_class.new(taric_update).import
        described_class.new(taric_update2).import
        expect(Measure.count).to eq 1
      end

      it 'creates single Measure::Operation(oplog) entry', :aggregate_failures do
        described_class.new(taric_update).import

        expect(Measure::Operation.count).to eq 1
        expect(
          Measure::Operation.where(
            operation: 'C',
            measure_sid: '3318239',
            operation_date: example_date,
          ).first,
        ).to be_present
      end

      it 'creates two Measure::Operation(oplog) entries after update', :aggregate_failures do
        described_class.new(taric_update).import
        described_class.new(taric_update2).import

        expect(Measure::Operation.count).to eq 2

        update = Measure::Operation.where(operation: 'U', measure_sid: '3318239', operation_date: example_date2).first
        expect(update).to be_present
        expect(update.validity_end_date).to be_present
      end
    end

    context 'when provided with valid taric file' do
      before do
        ExplicitAbrogationRegulation.unrestrict_primary_key
        allow(taric_update).to receive(:file_path)
          .and_return('spec/fixtures/taric_samples/insert_record.xml')
      end

      after { ExplicitAbrogationRegulation.restrict_primary_key }

      it 'logs an info event', :aggregate_failures do
        allow(Rails.logger).to receive(:info)
        importer = described_class.new(taric_update)
        importer.import
        expect(Rails.logger).to have_received(:info)
        expect(Rails.logger).to have_received(:info).with('Successfully imported Taric file: 2013-08-02_TGB13214.xml')
      end
    end

    context 'on an unexpected update operation type'

    it 'logs an error event', :aggregate_failures do
      allow(Rails.logger).to receive(:error)
      importer = described_class.new(taric_update)
      expect { importer.import }.to raise_error TaricImporter::ImportException
      expect(Rails.logger).to have_received(:error).with(include('Unexpected Taric operation type:'))
    end
  end
end
