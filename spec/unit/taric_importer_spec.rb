RSpec.describe TaricImporter do
  before do
    allow(TradeTariffBackend).to receive(:service).and_return('xi')
  end

  describe '#import' do
    let(:example_date) { Date.new(2013, 8, 2) }
    let(:second_example_date) { Date.new(2014, 8, 2) }
    let(:taric_update) { create :taric_update, example_date: }
    let(:second_taric_update) { create :taric_update, example_date: second_example_date }

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
      before do
        Measure.unrestrict_primary_key
        allow(taric_update).to receive(:file_path)
          .and_return('spec/fixtures/taric_samples/create_measure.xml')
        allow(second_taric_update).to receive(:file_path)
          .and_return('spec/fixtures/taric_samples/update_measure.xml')
      end

      after { Measure.restrict_primary_key }

      it 'imports single Measure' do
        described_class.new(taric_update).import
        Measure.refresh!(concurrently: false)

        expect(Measure.count).to eq 1
      end

      it 'imports single Measure and updates it' do
        described_class.new(taric_update).import
        described_class.new(second_taric_update).import
        Measure.refresh!(concurrently: false)

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
        described_class.new(second_taric_update).import

        expect(Measure::Operation.count).to eq 2

        update = Measure::Operation.where(operation: 'U', measure_sid: '3318239', operation_date: second_example_date).first
        expect(update).to be_present
        expect(update.validity_end_date).to be_present
      end
    end

    context 'when a file creates and destroys the same Measure' do
      before do
        Measure.unrestrict_primary_key
        allow(taric_update).to receive(:file_path)
          .and_return('spec/fixtures/taric_samples/create_then_destroy_measure.xml')
      end

      after { Measure.restrict_primary_key }

      it 'records a clean create-then-destroy oplog sequence, not a rollback or a dropped destroy' do
        described_class.new(taric_update).import

        operations = Measure::Operation.where(measure_sid: '4264227').order(:oid).map { |op| op[:operation] }
        expect(operations).to eq(%w[C D])
      end
    end

    context 'when a file creates and updates the same Measure' do
      before do
        Measure.unrestrict_primary_key
        allow(taric_update).to receive(:file_path)
          .and_return('spec/fixtures/taric_samples/create_then_update_measure.xml')
      end

      after { Measure.restrict_primary_key }

      it 'records a clean create-then-update oplog sequence, not a duplicate create' do
        described_class.new(taric_update).import

        operations = Measure::Operation.where(measure_sid: '4263779').order(:oid).map { |op| op[:operation] }
        expect(operations).to eq(%w[C U])
      end
    end

    context 'when a create and its later destroy land in different batches' do
      before do
        Measure.unrestrict_primary_key
        # batch_size 1 forces every record to flush in its own batch, so this
        # exercises the batch-flush boundary itself - unlike a larger batch
        # size, where create+destroy would still land in separate multi_insert
        # calls anyway, just because chunk_while splits by operation type.
        allow(TradeTariffBackend).to receive(:taric_importer_batch_size).and_return(1)
        allow(taric_update).to receive(:file_path)
          .and_return('spec/fixtures/taric_samples/create_then_destroy_measure_batch_boundary.xml')
      end

      after { Measure.restrict_primary_key }

      it 'still preserves oplog order across the batch flush boundary' do
        described_class.new(taric_update).import

        operations = Measure::Operation.where(measure_sid: '4264227').order(:oid).map { |op| op[:operation] }
        expect(operations).to eq(%w[C D])
      end

      it 'flushes each record in its own batch, proving the boundary was actually exercised' do
        allow(Measure::Operation).to receive(:multi_insert).and_call_original

        described_class.new(taric_update).import

        expect(Measure::Operation).to have_received(:multi_insert).exactly(3).times
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

      it 'stores string entity keys in the oplog inserts payload' do
        oplog_inserts = described_class.new(taric_update).import

        expect(oplog_inserts[:operations][:create]).to include('ExplicitAbrogationRegulation')
        expect(oplog_inserts[:operations][:create]).not_to include(ExplicitAbrogationRegulation)
        expect { oplog_inserts.to_json }.not_to raise_error
      end
    end

    context 'with an unexpected update operation type' do
      it 'logs both the inner UnknownOperationError and the outer wrapper', :aggregate_failures do
        allow(Rails.logger).to receive(:error)
        importer = described_class.new(taric_update)

        expect { importer.import }.to raise_error TaricImporter::ImportException

        expect(Rails.logger).to have_received(:error).with(include('Unknown TARIC operation:')).twice
      end

      it 'wraps the specific UnknownOperationError as the original, not a generic error', :aggregate_failures do
        importer = described_class.new(taric_update)

        expect { importer.import }.to raise_error(TaricImporter::ImportException) do |caught|
          expect(caught.message).to eq('TARIC record import failed')
          expect(caught.original).to be_a(TaricImporter::UnknownOperationError)
          expect(caught.original.message).to include('Unknown TARIC operation:')
          expect(caught.cause).to eq(caught.original)
        end
      end
    end
  end
end
