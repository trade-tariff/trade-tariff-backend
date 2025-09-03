RSpec.describe DeltaReportService::MeasurePresenter do
  let(:test_class) do
    Class.new do
      include DeltaReportService::MeasurePresenter
    end
  end

  let(:instance) { test_class.new }

  describe '#measure_type' do
    let(:measure_type) { instance_double(MeasureType, id: '103', description: 'Third country duty') }
    let(:measure) { instance_double(Measure, measure_type: measure_type) }

    it 'returns formatted measure type with id and description' do
      result = instance.measure_type(measure)
      expect(result).to eq('103: Third country duty')
    end
  end

  describe '#import_export' do
    let(:measure_type) { instance_double(MeasureType) }
    let(:measure) { instance_double(Measure, measure_type: measure_type) }

    context 'when trade_movement_code is 0' do
      before { allow(measure_type).to receive(:trade_movement_code).and_return(0) }

      it 'returns Import' do
        expect(instance.import_export(measure)).to eq('Import')
      end
    end

    context 'when trade_movement_code is 1' do
      before { allow(measure_type).to receive(:trade_movement_code).and_return(1) }

      it 'returns Export' do
        expect(instance.import_export(measure)).to eq('Export')
      end
    end

    context 'when trade_movement_code is 2' do
      before { allow(measure_type).to receive(:trade_movement_code).and_return(2) }

      it 'returns Both' do
        expect(instance.import_export(measure)).to eq('Both')
      end
    end

    context 'when trade_movement_code is nil' do
      before { allow(measure_type).to receive(:trade_movement_code).and_return(nil) }

      it 'returns empty string' do
        expect(instance.import_export(measure)).to eq('')
      end
    end

    context 'when trade_movement_code is other value' do
      before { allow(measure_type).to receive(:trade_movement_code).and_return(99) }

      it 'returns empty string' do
        expect(instance.import_export(measure)).to eq('')
      end
    end

    context 'when measure_type is nil' do
      let(:measure) { instance_double(Measure, measure_type: nil) }

      it 'returns empty string' do
        expect(instance.import_export(measure)).to eq('')
      end
    end
  end

  describe '#geo_area' do
    context 'when geo_area is present' do
      let(:geo_area) { instance_double(GeographicalArea, id: 'GB', description: 'United Kingdom') }

      it 'returns formatted geo area with id and description' do
        result = instance.geo_area(geo_area)
        expect(result).to eq('GB: United Kingdom')
      end
    end

    context 'when geo_area is nil' do
      it 'returns empty string' do
        result = instance.geo_area(nil)
        expect(result).to eq('')
      end
    end

    context 'when geo_area is blank' do
      it 'returns empty string' do
        result = instance.geo_area('')
        expect(result).to eq('')
      end
    end
  end

  describe '#additional_code' do
    context 'when additional_code is present' do
      let(:additional_code) { build(:additional_code, :with_description, additional_code: '123') }

      it 'returns formatted additional code with code and description' do
        result = instance.additional_code(additional_code)
        expect(result).to eq("1123: #{additional_code.additional_code_description.description}")
      end
    end

    context 'when additional_code is nil' do
      it 'returns nil' do
        result = instance.additional_code(nil)
        expect(result).to be_nil
      end
    end
  end

  describe '#duty_expression' do
    let(:measure) { instance_double(Measure, duty_expression: '10.5% + €15.25 / 100 kg') }

    it 'returns the duty expression from the measure' do
      result = instance.duty_expression(measure)
      expect(result).to eq('10.5% + €15.25 / 100 kg')
    end
  end
end
