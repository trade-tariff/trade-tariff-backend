RSpec.describe MeasureUnitService do
  subject(:service) { described_class.new(measures) }

  describe '#call' do
    context 'when the measures do not express units' do
      let(:measures) { create_list(:measure, 1, :no_expresses_units) }

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
            'expansion' => '100 kg of the standard quality (std qual)',
            'unit_question' => 'What is the weight net of the standard quality of the goods you will be importing?',
            'unit_hint' => 'Enter the value in kilograms',
            'unit' => 'kilograms',
            'multiplier' => '0.01',
            'coerced_measurement_unit_code' => 'KGM',
            'original_unit' => 'x 100 kg',
            'measurement_unit_type' => 'weight',
          },
        }
      end

      it { expect(service.call).to eq(expected_applicable_units) }
    end

    context 'when the measures express multiple matching units' do
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
            'expansion' => 'percentage ABV (% vol)',
            'measurement_unit_code' => 'ASV',
            'measurement_unit_qualifier_code' => nil,
            'unit' => 'percent',
            'unit_hint' => 'Enter the alcohol by volume (ABV) percentage',
            'unit_question' => 'What is the alcohol percentage (%) of the goods you are importing?',
            'multiplier' => nil,
            'coerced_measurement_unit_code' => nil,
            'original_unit' => nil,
            'measurement_unit_type' => 'percentage_abv',
          },
          'HLT' => {
            'abbreviation' => 'hl',
            'expansion' => '100 litre (hl)',
            'measurement_unit_code' => 'HLT',
            'measurement_unit_qualifier_code' => nil,
            'unit' => 'litres',
            'unit_hint' => 'Enter the value in litres',
            'unit_question' => 'What is the volume of the goods that you will be importing?',
            'multiplier' => '0.01',
            'coerced_measurement_unit_code' => 'LTR',
            'original_unit' => 'x 100 litres',
            'measurement_unit_type' => 'volume',
          },
        }
      end

      it { expect(service.call).to eq(expected_applicable_units) }
    end
  end
end
