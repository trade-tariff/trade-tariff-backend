RSpec.describe DeltaReportService::AdditionalCodeChanges do
  let(:date) { Date.parse('2024-08-11') }
  let(:additional_code_description) do
    instance_double(AdditionalCodeDescription,
                    description: 'Additional Code updated',
                    formatted_description: 'Additional Code updated')
  end

  let(:additional_code) do
    build(:additional_code, :with_description,
          additional_code_type_id: '8',
          additional_code: 'AAA',
          additional_code_description:)
  end
  let(:instance) { described_class.new(additional_code, date) }

  before do
    allow(instance).to receive_messages(get_changes: nil)

    receive_messages(
      additional_code_sid: '12345',
      description: 'Additional Code updated',
    )
  end

  describe '.collect' do
    let(:additional_code1) { build(:additional_code, :with_description, oid: 1, operation_date: date) }
    let(:additional_code2) { build(:additional_code, :with_description, oid: 2, operation_date: date) }
    let(:additional_codes) { [additional_code1, additional_code2] }

    before do
      allow(AdditionalCode).to receive_message_chain(:where, :order).and_return(additional_codes)
    end

    it 'finds additional codes for the given date and returns analyzed changes' do
      instance1 = described_class.new(additional_code1, date)
      instance2 = described_class.new(additional_code2, date)

      allow(described_class).to receive(:new).and_return(instance1, instance2)
      allow(instance1).to receive(:analyze).and_return({ type: 'AdditionalCode' })
      allow(instance2).to receive(:analyze).and_return({ type: 'AdditionalCode' })

      result = described_class.collect(date)

      expect(AdditionalCode).to have_received(:where).with(operation_date: date)
      expect(result).to eq([{ type: 'AdditionalCode' }, { type: 'AdditionalCode' }])
    end

    it 'filters out nil results from analyze' do
      instance1 = described_class.new(additional_code1, date)
      instance2 = described_class.new(additional_code2, date)

      allow(described_class).to receive(:new).and_return(instance1, instance2)
      allow(instance1).to receive_messages(analyze: nil)
      allow(instance2).to receive_messages(analyze: { type: 'AdditionalCode' })

      result = described_class.collect(date)

      expect(result).to eq([{ type: 'AdditionalCode' }])
    end
  end

  describe '#object_name' do
    it 'returns the correct object name' do
      expect(instance.object_name).to eq('Additional Code')
    end
  end

  describe '#analyze' do
    before do
      allow(instance).to receive_messages(
        no_changes?: false,
        date_of_effect: date,
        description: 'Additional Code updated',
        change: nil,
      )
    end

    context 'when there are no changes' do
      before { allow(instance).to receive_messages(no_changes?: true) }

      it 'returns nil' do
        expect(instance.analyze).to be_nil
      end
    end

    context 'when changes should be included' do
      before do
        allow(additional_code).to receive_messages(operation: :update, additional_code_sid: '12345', additional_code_description:)
      end

      it 'returns the correct analysis hash' do
        result = instance.analyze

        expect(result).to eq({
          type: 'AdditionalCode',
          additional_code_sid: '12345',
          additional_code: '8AAA: Additional Code updated',
          description: 'Additional Code updated',
          date_of_effect: date,
          change: '',
        })
      end
    end

    context 'when change is not nil' do
      before do
        allow(additional_code).to receive_messages(operation: :update)
        allow(instance).to receive_messages(change: 'description updated')
      end

      it 'uses the change value' do
        result = instance.analyze
        expect(result[:change]).to eq('description updated')
      end
    end

    context 'when additional_code helper returns nil' do
      before do
        allow(additional_code).to receive_messages(operation: :update)
        allow(instance).to receive_messages(additional_code: nil)
      end

      it 'includes nil additional_code in result' do
        result = instance.analyze
        expect(result[:additional_code]).to be_nil
      end
    end
  end

  describe '#previous_record' do
    let(:previous_additional_code) { build(:additional_code) }

    before do
      allow(AdditionalCode).to receive(:operation_klass).and_return(AdditionalCode)
      allow(AdditionalCode).to receive_message_chain(:where, :where, :order, :first)
                         .and_return(previous_additional_code)
    end

    it 'queries for the previous record by additional_code_sid and oid' do
      result = instance.previous_record

      expect(result).to eq(previous_additional_code)
    end

    it 'memoizes the result' do
      instance.previous_record
      instance.previous_record

      expect(AdditionalCode).to have_received(:operation_klass).once
    end
  end

  describe 'integration with BaseChanges' do
    it 'inherits from BaseChanges' do
      expect(described_class.superclass).to eq(DeltaReportService::BaseChanges)
    end

    it 'includes MeasurePresenter module' do
      expect(described_class.included_modules).to include(DeltaReportService::MeasurePresenter)
    end
  end

  describe 'MeasurePresenter integration' do
    context 'when using additional_code helper' do
      let(:additional_code_with_description) do
        build(:additional_code, :with_description,
              additional_code_type_id: '8',
              additional_code: 'AAA',
              additional_code_description: 'Test Description')
      end

      it 'formats additional code using MeasurePresenter helper' do
        instance = described_class.new(additional_code_with_description, date)
        result = instance.send(:additional_code, additional_code_with_description)

        expect(result).to include('8AAA:')
      end
    end
  end
end
