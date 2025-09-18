RSpec.describe DeltaReportService::BaseChanges do
  let(:test_class) do
    Class.new(described_class) do
      attr_accessor :previous_record

      def object_name
        'Test Object'
      end
    end
  end

  let(:record) { build(:measure, operation: :update, operation_date: date, oid: 123) }
  let(:date) { Date.parse('2024-08-11') }
  let(:instance) { test_class.new(record, date) }

  describe '#initialize' do
    it 'sets record and date' do
      expect(instance.record).to eq(record)
      expect(instance.date).to eq(date)
    end

    it 'calls get_changes' do
      instance = test_class.allocate
      allow(instance).to receive(:record=)
      allow(instance).to receive(:date=)
      allow(instance).to receive(:get_changes)
      instance.send(:initialize, record, date)
      expect(instance).to have_received(:get_changes)
    end
  end

  describe '#excluded_columns' do
    it 'returns default excluded columns' do
      expected_columns = %i[oid operation operation_date created_at updated_at filename]
      expect(instance.excluded_columns).to eq(expected_columns)
    end
  end

  describe '#no_changes?' do
    context 'when operation is update and changes are empty' do
      before do
        allow(record).to receive(:operation).and_return(:update)
        instance.changes = []
      end

      it 'returns true' do
        expect(instance.no_changes?).to be(true)
      end
    end

    context 'when operation is create' do
      before do
        allow(record).to receive(:operation).and_return(:create)
        instance.changes = []
      end

      it 'returns false' do
        expect(instance.no_changes?).to be(false)
      end
    end

    context 'when operation is update but changes exist' do
      before do
        allow(record).to receive(:operation).and_return(:update)
        instance.changes = %w[name]
      end

      it 'returns false' do
        expect(instance.no_changes?).to be(false)
      end
    end
  end

  describe '#get_changes' do
    let(:previous_record) do
      build(:measure,
            measure_sid: record.measure_sid,
            validity_start_date: Date.parse('2024-08-01'),
            validity_end_date: Date.parse('2024-08-31'),
            goods_nomenclature_item_id: '1000000000')
    end

    let(:get_changes_record) do
      build(:measure,
            measure_sid: previous_record.measure_sid,
            validity_start_date: Date.parse('2024-08-15'),
            validity_end_date: Date.parse('2024-08-31'),
            goods_nomenclature_item_id: '2000000000')
    end

    let(:get_changes_instance) { test_class.new(get_changes_record, date) }

    before do
      allow(get_changes_record).to receive(:previous_record).and_return(previous_record)
    end

    context 'when operation is update' do
      before do
        allow(get_changes_record).to receive(:operation).and_return(:update)
      end

      it 'identifies changed columns' do
        get_changes_instance.get_changes
        expect(get_changes_instance.changes).to include('validity start date')
        expect(get_changes_instance.changes).not_to include('measure sid')
      end

      it 'sets change to first changed value' do
        get_changes_instance.get_changes
        expect(get_changes_instance.change).not_to be_nil
        expect(get_changes_instance.change).not_to be_blank
      end
    end

    context 'when operation is not update' do
      before do
        allow(get_changes_record).to receive(:operation).and_return(:create)
      end

      it 'does not set changes' do
        get_changes_instance.get_changes
        expect(get_changes_instance.changes).to be_empty
      end
    end

    context 'when no previous record exists' do
      before do
        allow(get_changes_record).to receive_messages(operation: :update, previous_record: nil)
      end

      it 'does not set changes' do
        get_changes_instance.get_changes
        expect(get_changes_instance.changes).to be_empty
      end
    end
  end

  describe '#date_of_effect' do
    let(:validity_start_date) { Date.parse('2024-08-15') }
    let(:validity_end_date) { Date.parse('2024-08-20') }
    let(:operation_date) { Date.parse('2024-08-10') }
    let(:date_record) do
      build(:measure,
            validity_start_date: validity_start_date,
            operation_date: operation_date).tap do |record|
        allow(record).to receive(:validity_end_date).and_return(validity_end_date)
      end
    end
    let(:date_instance) { test_class.new(date_record, date) }

    context 'when validity_start_date is in changes' do
      before { date_instance.changes = ['validity start date'] }

      it 'returns validity_start_date' do
        expect(date_instance.date_of_effect).to eq(validity_start_date)
      end
    end

    context 'when validity_end_date is in changes' do
      before { date_instance.changes = ['validity end date'] }

      it 'returns validity_end_date' do
        expect(date_instance.date_of_effect).to eq(validity_end_date + 1.day)
      end
    end

    context 'when validity_start_date is after operation_date' do
      before { date_instance.changes = [] }

      it 'returns validity_start_date' do
        expect(date_instance.date_of_effect).to eq(validity_start_date)
      end
    end
  end

  describe '#description' do
    context 'when operation is create' do
      before { allow(record).to receive(:operation).and_return(:create) }

      it 'returns correct description' do
        expect(instance.description).to eq('Test Object added')
      end
    end

    context 'when operation is update with changes' do
      before do
        allow(record).to receive(:operation).and_return(:update)
        instance.changes = %w[name description]
      end

      it 'returns correct description with changes listed' do
        expect(instance.description).to eq('Test Object name, description updated')
      end
    end

    context 'when operation is update without changes' do
      before do
        allow(record).to receive(:operation).and_return(:update)
        instance.changes = []
      end

      it 'returns generic update description' do
        expect(instance.description).to eq('Test Object updated')
      end
    end

    context 'when operation is delete' do
      before { allow(record).to receive(:operation).and_return(:destroy) }

      it 'returns correct description' do
        expect(instance.description).to eq('Test Object removed')
      end
    end
  end
end
