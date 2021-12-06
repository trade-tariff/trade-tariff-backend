RSpec.describe MeasureUnitService do
  subject(:service) { described_class.new(measures) }

  describe '#call' do
    context 'when the measures do not express units' do
      let(:measures) { [create(:measure, :no_expresses_units)] }

      it 'returns an empty Hash of units' do
        expect(service.call).to eq({})
      end
    end

    context 'when the measures express a single matching units' do
      let(:measures) { [measure] }
      let(:measure) do
        create(
          :measure,
          :with_measure_components,
          :with_measure_conditions,
          :expresses_units,
          :single_unit,
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
          },
        }
      end

      it { expect(service.call).to eq(expected_applicable_units) }
    end

    context 'when the measures express a multiple matching units' do
      let(:measures) { [measure] }
      let(:measure) do
        create(
          :measure,
          :with_measure_components,
          :with_measure_conditions,
          :expresses_units,
          :compound_unit,
        )
      end

      let(:expected_applicable_units) do
        {
          'ASV' => {
            'abbreviation' => '% vol',
            'measurement_unit_code' => 'ASV',
            'measurement_unit_qualifier_code' => '',
            'unit' => 'percent',
            'unit_hint' => 'Enter the alcohol by volume (ABV) percentage',
            'unit_question' => 'What is the alcohol percentage (%) of the goods you are importing?',
          },
          'HLT' => {
            'abbreviation' => 'hl',
            'measurement_unit_code' => 'HLT',
            'measurement_unit_qualifier_code' => '',
            'unit' => 'x 100 litres',
            'unit_hint' => 'Enter the value in hectolitres (100 litres)',
            'unit_question' => 'What is the volume of the goods that you will be importing?',
          },
        }
      end

      it { expect(service.call).to eq(expected_applicable_units) }
    end
  end
end
