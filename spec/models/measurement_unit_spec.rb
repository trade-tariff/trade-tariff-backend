RSpec.describe MeasurementUnit do
  subject(:measurement_unit) { create :measurement_unit, :with_description }

  describe '#to_s' do
    it 'is an alias for description' do
      expect(measurement_unit.to_s).to eq measurement_unit.description
    end
  end

  describe '#abbreviation' do
    it { expect(measurement_unit.abbreviation).to eq(measurement_unit.description) }
  end

  describe '#measurement_unit_abbreviation' do
    context 'with measurement_unit_abbreviation' do
      let!(:measurement_unit_abbreviation) do
        create(:measurement_unit_abbreviation, measurement_unit_code: measurement_unit.measurement_unit_code)
      end

      it { expect(measurement_unit.measurement_unit_abbreviation).to eq(measurement_unit_abbreviation) }
    end
  end

  describe '.units' do
    context 'with a single measurement unit' do
      subject(:result) { described_class.units('ASV', 'ASV') }

      it { is_expected.to include_json([{ 'unit' => 'percent' }]) }
    end

    context 'with a compound measurement unit' do
      subject(:result) { described_class.units('ASV', 'ASVX') }

      it { is_expected.to include_json([{ 'unit' => 'percent' }, { 'unit' => 'x 100 litres' }]) }
    end

    context 'with missing measurement unit present in database' do
      subject(:result) { described_class.units('ASV', 'ASVX') }

      before do
        measurement_unit
        allow(Sentry).to receive(:capture_message).and_call_original
        allow(described_class).to receive(:measurement_units).and_return({})
        result
      end

      let(:measurement_unit) do
        create(
          :measurement_unit,
          :with_description,
          measurement_unit_code: 'ASV',
        )
      end

      let(:expected_units) do
        [
          {
            'abbreviation' => measurement_unit.abbreviation,
            'measurement_unit_code' => 'ASV',
            'measurement_unit_qualifier_code' => 'X',
            'unit' => nil,
            'unit_hint' => "Please correctly enter unit: #{measurement_unit.description}",
            'unit_question' => "Please enter unit: #{measurement_unit.description}",
          },
        ]
      end

      it { is_expected.to eq(expected_units) }
      it { expect(Sentry).to have_received(:capture_message) }
    end

    context 'with measurement unit not in the database' do
      subject(:result) { described_class.units('FC1', 'FC1X') }

      before do
        allow(Sentry).to receive(:capture_message).and_call_original
        allow(described_class).to receive(:measurement_units).and_return({})
        result
      end

      let(:expected_units) do
        [
          {
            'abbreviation' => nil,
            'measurement_unit_code' => 'FC1',
            'measurement_unit_qualifier_code' => 'X',
            'unit' => nil,
            'unit_hint' => 'Please correctly enter unit: FC1',
            'unit_question' => 'Please enter unit: FC1',
          },
        ]
      end

      it { is_expected.to eq(expected_units) }
      it { expect(Sentry).to have_received(:capture_message) }
    end
  end
end
