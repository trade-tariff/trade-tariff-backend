require 'rails_helper'

describe MeasurementUnit do
  let(:measurement_unit) { create :measurement_unit, :with_description }

  describe '#to_s' do
    it 'is an alias for description' do
      expect(measurement_unit.to_s).to eq measurement_unit.description
    end
  end

  describe 'validations' do
    # MU1 The measurement unit code must be unique.
    it { is_expected.to validate_uniqueness.of(:measurement_unit_code) }
    # MU2 The start date must be less than or equal to the end date.
    it { is_expected.to validate_validity_dates }
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
end
