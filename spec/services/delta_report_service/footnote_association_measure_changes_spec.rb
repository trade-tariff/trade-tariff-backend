RSpec.describe DeltaReportService::FootnoteAssociationMeasureChanges do
  let(:date) { Date.parse('2024-08-11') }
  let(:measure) { build(:measure, measure_sid: '12345') }
  let(:footnote) { build(:footnote, footnote_id: '001', footnote_type_id: 'TN', oid: '999') }
  let(:footnote_association) do
    build(
      :footnote_association_measure,
      oid: '123',
      measure_sid: measure.measure_sid,
      footnote_id: footnote.footnote_id,
      footnote_type_id: footnote.footnote_type_id,
      operation_date: date,
    )
  end

  before do
    allow(footnote_association).to receive_messages(
      footnote: footnote,
      measure: measure,
    )
    allow(footnote).to receive(:code).and_return("#{footnote.footnote_type_id}#{footnote.footnote_id}")
  end

  describe '.collect' do
    let(:association1) { build(:footnote_association_measure, oid: 1, operation_date: date) }
    let(:association2) { build(:footnote_association_measure, oid: 2, operation_date: date) }
    let(:associations) { [association1, association2] }

    before do
      allow(FootnoteAssociationMeasure).to receive_message_chain(:where, :order).and_return(associations)
    end

    it 'finds footnote association measures for the given date and returns analyzed changes' do
      instance1 = described_class.new(association1, date)
      instance2 = described_class.new(association2, date)

      allow(described_class).to receive(:new).and_return(instance1, instance2)
      allow(instance1).to receive(:analyze).and_return({ type: 'FootnoteAssociationMeasure' })
      allow(instance2).to receive(:analyze).and_return({ type: 'FootnoteAssociationMeasure' })

      result = described_class.collect(date)

      expect(FootnoteAssociationMeasure).to have_received(:where).with(operation_date: date)
      expect(result).to eq([{ type: 'FootnoteAssociationMeasure' }, { type: 'FootnoteAssociationMeasure' }])
    end

    it 'filters out nil results from analyze' do
      instance1 = described_class.new(association1, date)
      instance2 = described_class.new(association2, date)

      allow(described_class).to receive(:new).and_return(instance1, instance2)
      allow(instance1).to receive(:analyze).and_return({ type: 'FootnoteAssociationMeasure' })
      allow(instance2).to receive(:analyze).and_return(nil)

      result = described_class.collect(date)

      expect(result).to eq([{ type: 'FootnoteAssociationMeasure' }])
    end
  end

  describe '#object_name' do
    let(:instance) { described_class.new(footnote_association, date) }

    it 'returns the correct object name with footnote code' do
      expect(instance.object_name).to eq('Footnote')
    end
  end

  describe '#analyze' do
    let(:instance) { described_class.new(footnote_association, date) }
    let(:geographical_area) { build(:geographical_area, geographical_area_id: 'GB') }
    let(:additional_code) { build(:additional_code, additional_code: '1234') }

    before do
      allow(instance).to receive_messages(
        no_changes?: false,
        description: 'Footnote TN001 updated',
        change: nil,
      )
      allow(measure).to receive_messages(
        geographical_area: geographical_area,
        additional_code: additional_code,
        measure_type: instance_double(MeasureType, id: '103', description: 'Import duty', trade_movement_code: 0),
        duty_expression: '10%',
      )
      allow(additional_code).to receive_messages(
        additional_code_description: instance_double(AdditionalCodeDescription, description: '1234'),
        code: '1234',
      )
      allow(geographical_area).to receive_messages(
        geographical_area_description: instance_double(GeographicalAreaDescription, description: 'United Kingdom'),
        id: 'GB',
      )
    end

    context 'when there are no changes' do
      before { allow(instance).to receive(:no_changes?).and_return(true) }

      it 'returns nil' do
        expect(instance.analyze).to be_nil
      end
    end

    context 'when record is a create operation and measure was created on the same date' do
      before do
        allow(footnote_association).to receive(:operation).and_return(:create)
        allow(measure).to receive(:operation_date).and_return(date)
      end

      it 'returns nil' do
        expect(instance.analyze).to be_nil
      end
    end

    context 'when record is a create operation and footnote was created on the same date' do
      before do
        allow(footnote_association).to receive(:operation).and_return(:create)
        allow(measure).to receive(:operation_date).and_return(date - 1)
        allow(footnote).to receive(:operation_date).and_return(date)
      end

      it 'returns nil' do
        expect(instance.analyze).to be_nil
      end
    end

    context 'when changes should be included' do
      before do
        allow(footnote_association).to receive(:operation).and_return(:update)
        allow(measure).to receive(:operation_date).and_return(date - 1)
        allow(footnote).to receive(:operation_date).and_return(date - 1)
      end

      it 'returns the correct analysis hash' do
        result = instance.analyze

        expect(result).to eq({
          type: 'FootnoteAssociationMeasure',
          measure_sid: measure.measure_sid,
          measure_type: '103: Import duty',
          import_export: 'Import',
          geo_area: 'GB: United Kingdom',
          additional_code: '1234: 1234',
          duty_expression: '10%',
          description: 'Footnote TN001 updated',
          date_of_effect: date,
          change: footnote.code,
        })
      end
    end

    context 'when change value is present' do
      before do
        allow(footnote_association).to receive(:operation).and_return(:update)
        allow(measure).to receive(:operation_date).and_return(date - 1)
        allow(footnote).to receive(:operation_date).and_return(date - 1)
        allow(instance).to receive(:change).and_return('national updated')
      end

      it 'includes the change value in the result' do
        result = instance.analyze
        expect(result[:change]).to eq("#{footnote.code}: national updated")
      end
    end

    context 'when record is a create operation but entities were created on different dates' do
      before do
        allow(footnote_association).to receive(:operation).and_return(:create)
        allow(measure).to receive(:operation_date).and_return(date - 1)
        allow(footnote).to receive(:operation_date).and_return(date - 2)
      end

      it 'returns the analysis hash' do
        result = instance.analyze

        expect(result).to eq({
          type: 'FootnoteAssociationMeasure',
          measure_sid: measure.measure_sid,
          measure_type: '103: Import duty',
          import_export: 'Import',
          geo_area: 'GB: United Kingdom',
          additional_code: '1234: 1234',
          duty_expression: '10%',
          description: 'Footnote TN001 updated',
          date_of_effect: date,
          change: footnote.code,
        })
      end
    end
  end

  describe '#date_of_effect' do
    let(:instance) { described_class.new(footnote_association, date) }

    it 'returns the date passed to the instance' do
      expect(instance.date_of_effect).to eq(date)
    end
  end
end
