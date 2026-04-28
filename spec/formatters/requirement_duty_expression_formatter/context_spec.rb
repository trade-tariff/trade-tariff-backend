RSpec.describe RequirementDutyExpressionFormatter::Context do
  describe '.build' do
    let(:measurement_unit_abbreviation) do
      create(:measurement_unit_abbreviation, :with_measurement_unit, :include_qualifier)
    end
    let(:measurement_unit) do
      measurement_unit_abbreviation.measurement_unit
    end

    it 'prefers the monetary unit abbreviation when it is present' do
      context = described_class.build(
        monetary_unit: 'Euro',
        monetary_unit_abbreviation: 'EUR',
      )

      expect(context.monetary_unit).to eq('EUR')
    end

    it 'stores the formatted measurement unit qualifier and derived abbreviation' do
      context = described_class.build(
        measurement_unit: measurement_unit,
        formatted_measurement_unit_qualifier: 'L',
      )

      expect(context.measurement_unit_qualifier).to eq('L')
      expect(context.measurement_unit_abbreviation).to eq(
        measurement_unit.abbreviation(measurement_unit_qualifier: 'L'),
      )
    end
  end
end
