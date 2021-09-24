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

  describe '.measurement_unit' do
    let(:measurement_unit) do
      create(
        :measurement_unit,
        :with_description,
        measurement_unit_code: measurement_unit_code,
      )
    end

    let(:measurement_unit_code) { 'ASV' }

    context 'with valid measurement unit' do
      let(:unit_code) { 'ASV' }
      let(:unit_key) { 'ASV' }

      it { expect(described_class.measurement_unit(unit_code, unit_key)).to include('unit' => 'percent') }
    end

    context 'with missing measurement unit present in database' do
      subject(:result) { described_class.measurement_unit(unit_code, unit_key) }

      before do
        measurement_unit
        allow(Raven).to receive(:capture_message).and_return(true)
        allow(described_class).to receive(:measurement_units).and_return({})
      end

      let(:unit_code) { 'ASV' }
      let(:unit_key) { 'ASVX' }
      let(:unit_description) { measurement_unit.description }

      it { is_expected.to include('measurement_unit_code' => unit_code) }
      it { is_expected.to include('measurement_unit_qualifier_code' => 'X') }
      it { is_expected.to include('unit' => nil) }
      it { is_expected.to include('abbreviation' => measurement_unit.abbreviation) }
      it { is_expected.to include('unit_question' => "Please enter unit: #{unit_description}") }
      it { is_expected.to include('unit_hint' =>  "Please correctly enter unit: #{unit_description}") }

      it 'sends a message to Sentry' do
        result
        expect(Raven).to have_received(:capture_message)
      end
    end

    context 'with measurement unit not in the database' do
      let(:unit) { described_class.measurement_unit('UNKNOWN', 'UNKNOWN') }

      it 'will raise an InvalidMeasurementUnit exception' do
        expect { unit }.to raise_exception(MeasurementUnit::InvalidMeasurementUnit)
      end
    end
  end
end
