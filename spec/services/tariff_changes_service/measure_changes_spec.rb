DummyOperationKlass = Class.new do
  def self.where(*_args)
    []
  end
end

RSpec.describe TariffChangesService::MeasureChanges do
  let(:date) { Date.new(2025, 1, 15) }

  describe '.collect' do
    let(:operation_klass) { class_double(DummyOperationKlass) }

    it 'uses the Measure operation class to find records from the specified date' do
      allow(Measure).to receive(:operation_klass).and_return(operation_klass)
      allow(operation_klass).to receive(:where).and_return([])

      described_class.collect(date)

      expect(Measure).to have_received(:operation_klass)
    end

    it 'returns an array of analyzed results' do
      allow(Measure).to receive(:operation_klass).and_return(operation_klass)
      allow(operation_klass).to receive(:where).and_return([])

      results = described_class.collect(date)

      expect(results).to be_an(Array)
    end
  end

  describe 'instance methods' do
    let(:record) { create(:measure, operation_date: date) }
    let(:measure_changes) { described_class.new(record, date) }

    describe '#object_name' do
      it 'returns "Measure"' do
        expect(measure_changes.object_name).to eq('Measure')
      end
    end

    describe '#object_sid' do
      it 'returns the measure_sid of the record' do
        expect(measure_changes.object_sid).to eq(record.measure_sid)
      end
    end

    describe '#excluded_columns' do
      it 'includes base excluded columns plus measure-specific ones' do
        base_excluded = %i[oid operation operation_date created_at updated_at filename]
        measure_excluded = %i[measure_generating_regulation_id justification_regulation_role justification_regulation_id national]
        expected = base_excluded + measure_excluded

        expect(measure_changes.excluded_columns).to eq(expected)
      end
    end

    describe 'inheritance from BaseChanges' do
      it 'inherits from TariffChangesService::BaseChanges' do
        expect(described_class.superclass).to eq(TariffChangesService::BaseChanges)
      end

      it 'can call inherited methods' do
        allow(measure_changes).to receive_messages(no_changes?: false, action: 'creation', date_of_effect: date)

        expect { measure_changes.analyze }.not_to raise_error
      end
    end

    describe 'integration with analyze method' do
      let(:record) do
        create(
          :measure,
          operation_date: date,
          validity_start_date: date,
          validity_end_date: nil,
        )
      end

      before do
        allow(record).to receive(:operation).and_return(:create)
      end

      it 'returns a properly formatted measure change analysis' do
        result = measure_changes.analyze

        expect(result[:type]).to eq('Measure')
        expect(result[:object_sid]).to eq(record.measure_sid)
        expect(result[:goods_nomenclature_sid]).to eq(record.goods_nomenclature_sid)
        expect(result[:action]).to eq('creation')
        expect(result[:validity_start_date]).to eq(date)
        expect(result[:validity_end_date]).to be_nil
      end
    end

    describe 'measure-specific behavior' do
      context 'when record has measure-specific attributes' do
        let(:record) do
          create(
            :measure,
            measure_sid: 12_345,
            goods_nomenclature_sid: 67_890,
            operation_date: date,
          )
        end

        it 'correctly identifies the measure_sid as object_sid' do
          expect(measure_changes.object_sid).to eq(12_345)
        end

        it 'correctly identifies the goods_nomenclature_sid' do
          allow(measure_changes).to receive_messages(no_changes?: false, action: :creation, date_of_effect: date)

          result = measure_changes.analyze
          expect(result[:goods_nomenclature_sid]).to eq(67_890)
        end
      end
    end
  end
end
