RSpec.describe MeasureUnitService do
  subject(:service) { described_class.new(measures) }

  describe '#call' do
    context 'when the measures do not express units' do
      let(:measures) { [create(:measure, :no_expresses_units)] }

      it 'returns an empty Hash of units' do
        expect(service.call).to eq({})
      end
    end

    context 'when the measures express units' do
      let(:measures) { [measure] }
      let(:measure) do
        create(
          :measure,
          :with_measure_components,
          :with_measure_conditions,
          :expresses_units,
          :no_ad_valorem,
        )
      end
      let(:expected_applicable_units) do
        {
          'DTNR' => {
            'measurement_unit_code' => 'DTN',
            'measurement_unit_qualifier_code' => 'R',
            'abbreviation' => '100 kg std qual',
            'unit_question' => 'What is the weight net of the standard quality of the goods you will be importing?',
            'unit_hint' => 'Enter the value in decitonnes (100kg)',
            'unit' => 'x 100 kg',
            'measure_sids' => Set.new([measure.measure_sid]),
          },
        }
      end

      it 'returns the correct annotated units' do
        expect(service.call).to eq(expected_applicable_units)
      end
    end
  end
end
