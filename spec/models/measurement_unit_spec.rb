require 'rails_helper'

describe MeasurementUnit do
  let(:measurement_unit) { create :measurement_unit, :with_description }

  describe '#to_s' do
    it 'is an alias for description' do
      expect(measurement_unit.to_s).to eq measurement_unit.description
    end
  end

  describe '#abbreviation' do
    it {
      expect(measurement_unit.abbreviation).to eq(measurement_unit.description)
    }
  end

  describe '#measurement_unit_abbreviation' do
    context 'with measurement_unit_abbreviation' do
      let!(:measurement_unit_abbreviation) do
        create(:measurement_unit_abbreviation, measurement_unit_code: measurement_unit.measurement_unit_code)
      end

      it {
        expect(measurement_unit.measurement_unit_abbreviation).to eq(measurement_unit_abbreviation)
      }
    end
  end

  describe '.measurement_units' do
    let(:units) { described_class.send(:measurement_units) }

    it "will return the hash of all measurement units" do
      expect(units).to be_instance_of Hash
    end

    it "will include individual units indexed by key" do
      expect(units).to include("ASV")
    end
  end

  describe '.measurement_unit' do
    context 'with valid measurement unit' do
      it { expect(MeasurementUnit.measurement_unit('ASV')).to include('unit' => 'percent') }
    end

    context 'with missing measurement unit present in database' do
      before { allow(Raven).to receive(:capture_message).and_return(true) }
      before { allow(MeasurementUnit).to receive(:measurement_units).and_return({}) }

      subject! { MeasurementUnit.measurement_unit(unit_code) }

      let(:unit_code) { measurement_unit.measurement_unit_code }
      let(:unit_description) { measurement_unit.description }

      it { is_expected.to include('measurement_unit_code' => unit_code) }
      it { is_expected.to include('unit' => nil) }
      it { is_expected.to include('abbreviation' => '') }
      it { is_expected.to include('unit_question' => "Please enter unit: #{unit_description}") }
      it { is_expected.to include('unit_hint' => nil) }
      it { expect(Raven).to have_received(:capture_message) }
    end

    context 'with measurement unit not in the database' do
      let(:unit) { MeasurementUnit.measurement_unit('UNKNOWN') }

      it "will raise an InvalidMeasurementUnit exception" do
        expect { unit }.to raise_exception(MeasurementUnit::InvalidMeasurementUnit)
      end
    end

    context 'without specifying a unit' do
      it { expect { MeasurementUnit.measurement_unit }.to raise_exception ArgumentError }
    end
  end
end
