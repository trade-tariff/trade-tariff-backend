DummyRecord = Struct.new(
  :goods_nomenclature_sid,
  :goods_nomenclature_item_id,
  :operation,
  :record_values,
  :previous_record,
  :validity_start_date,
  :validity_end_date,
  :oid,
  :field1,
  :field2,
  keyword_init: true,
) do
  def values
    record_values || {}
  end
end

RSpec.describe TariffChangesService::BaseChanges do
  let(:record) do
    DummyRecord.new(
      goods_nomenclature_sid: 12_345,
      goods_nomenclature_item_id: '0101010100',
      operation: :create,
      record_values: { field1: 'value1', field2: 'value2' },
      previous_record: nil,
    )
  end
  let(:date) { Date.new(2025, 1, 15) }

  describe '#initialize' do
    it 'sets record and date and calls get_changes' do
      instance = described_class.new(record, date)
      expect(instance.record).to eq(record)
      expect(instance.date).to eq(date)
      expect(instance.changes).to be_an(Array)
    end
  end

  describe '#object_name' do
    it 'raises NotImplementedError' do
      instance = described_class.new(record, date)
      expect { instance.object_name }.to raise_error(NotImplementedError)
    end
  end

  describe '#excluded_columns' do
    it 'returns expected excluded columns' do
      instance = described_class.new(record, date)
      expected_columns = %i[oid operation operation_date created_at updated_at filename]
      expect(instance.excluded_columns).to eq(expected_columns)
    end
  end

  describe '#no_changes?' do
    let(:instance) { described_class.new(record, date) }

    context 'when operation is update and changes is empty' do
      let(:record) { DummyRecord.new(operation: :update) }
      let(:instance) { described_class.new(record, date) }

      before do
        instance.changes = []
      end

      it 'returns true' do
        expect(instance.no_changes?).to be true
      end
    end

    context 'when operation is update but changes is not empty' do
      let(:record) { DummyRecord.new(operation: :update) }
      let(:instance) { described_class.new(record, date) }

      before do
        instance.changes = %w[some_field]
      end

      it 'returns false' do
        expect(instance.no_changes?).to be false
      end
    end

    context 'when operation is not update' do
      let(:record) { DummyRecord.new(operation: :create) }
      let(:instance) { described_class.new(record, date) }

      before do
        instance.changes = []
      end

      it 'returns false' do
        expect(instance.no_changes?).to be false
      end
    end
  end

  describe '#get_changes' do
    context 'when operation is not update' do
      let(:record) do
        DummyRecord.new(operation: :create)
      end

      it 'sets changes to empty array' do
        instance = described_class.new(record, date)
        expect(instance.changes).to eq([])
      end
    end

    context 'when operation is update' do
      let(:previous_record) { DummyRecord.new(field1: 'old_value1', field2: 'value2') }
      let(:record) do
        DummyRecord.new(
          operation: :update,
          record_values: { field1: 'value1', field2: 'value2', oid: 'test_oid' },
          previous_record: previous_record,
          field1: 'new_value1',
          field2: 'value2',
        )
      end

      it 'identifies changed fields' do
        instance = described_class.new(record, date)
        expect(instance.changes).to eq(%w[field1])
      end

      context 'when previous record is nil' do
        let(:record) do
          DummyRecord.new(
            operation: :update,
            record_values: { field1: 'value1' },
            previous_record: nil,
          )
        end

        it 'sets changes to empty array' do
          instance = described_class.new(record, date)
          expect(instance.changes).to eq([])
        end
      end
    end
  end

  describe '#date_of_effect' do
    let(:instance) { described_class.new(record, date) }

    context 'when validity_start_date changed and is present' do
      before do
        instance.changes = %w[validity_start_date]
        allow(record).to receive(:validity_start_date).and_return(date)
      end

      it 'returns the validity_start_date' do
        expect(instance.date_of_effect).to eq(date)
      end
    end

    context 'when validity_end_date changed and is present' do
      let(:end_date) { Date.new(2025, 2, 1) }

      before do
        instance.changes = %w[validity_end_date]
        allow(record).to receive(:validity_end_date).and_return(end_date)
      end

      it 'returns validity_end_date plus one day' do
        expect(instance.date_of_effect).to eq(end_date + 1.day)
      end
    end

    context 'when operation is create and record responds to validity_start_date' do
      let(:record) do
        DummyRecord.new(
          operation: :create,
          validity_start_date: date,
          previous_record: nil,
          record_values: {},
        )
      end

      it 'returns the validity_start_date' do
        expect(instance.date_of_effect).to eq(date)
      end
    end

    context 'when none of the above conditions are met' do
      let(:record) do
        DummyRecord.new(
          operation: :update,
          previous_record: nil,
          record_values: {},
        )
      end

      it 'returns date plus one day' do
        expect(instance.date_of_effect).to eq(date + 1.day)
      end
    end
  end

  describe '#action' do
    let(:instance) { described_class.new(record, date) }

    context 'when operation is create' do
      let(:record) do
        DummyRecord.new(operation: :create, previous_record: nil, record_values: {})
      end

      it 'returns :creation' do
        expect(instance.action).to eq(:creation)
      end
    end

    context 'when operation is update' do
      let(:record) do
        DummyRecord.new(operation: :update, previous_record: nil, record_values: {})
      end

      context 'when validity_end_date changed' do
        before do
          instance.changes = %w[validity_end_date]
        end

        it 'returns :ending' do
          expect(instance.action).to eq(:ending)
        end
      end

      context 'when validity_end_date did not change' do
        before do
          instance.changes = %w[some_other_field]
        end

        it 'returns :update' do
          expect(instance.action).to eq(:update)
        end
      end
    end

    context 'when operation is destroy' do
      let(:record) do
        DummyRecord.new(operation: :destroy, previous_record: nil, record_values: {})
      end

      it 'returns :deletion' do
        expect(instance.action).to eq(:deletion)
      end
    end
  end

  describe '#analyze' do
    let(:record) do
      DummyRecord.new(
        goods_nomenclature_sid: 12_345,
        goods_nomenclature_item_id: '0101010100',
        validity_start_date: date,
        validity_end_date: nil,
        oid: 'test_oid',
        operation: :create,
        previous_record: nil,
        record_values: {},
      )
    end
    let(:instance) { described_class.new(record, date) }

    before do
      allow(instance).to receive_messages(object_name: 'TestObject', object_sid: 12_345)
    end

    it 'returns a properly formatted analysis hash' do
      result = instance.analyze

      expect(result).to eq({
        type: 'TestObject',
        object_sid: 12_345,
        goods_nomenclature_sid: 12_345,
        goods_nomenclature_item_id: '0101010100',
        action: :creation,
        date_of_effect: date,
        validity_start_date: date,
        validity_end_date: nil,
      })
    end

    context 'when there are no changes' do
      let(:record) do
        DummyRecord.new(
          operation: :update,
          previous_record: nil,
          record_values: {},
        )
      end

      it 'returns nil' do
        expect(instance.analyze).to be_nil
      end
    end

    context 'when validity_end_date is present' do
      let(:end_date) { Date.new(2025, 2, 1) }
      let(:record) do
        DummyRecord.new(
          goods_nomenclature_sid: 12_345,
          goods_nomenclature_item_id: '0101010100',
          validity_start_date: date,
          validity_end_date: end_date,
          oid: 'test_oid',
          operation: :create,
          previous_record: nil,
          record_values: {},
        )
      end

      it 'includes the validity_end_date' do
        result = instance.analyze
        expect(result[:validity_end_date]).to eq(end_date)
      end
    end
  end
end
