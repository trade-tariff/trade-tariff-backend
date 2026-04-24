RSpec.describe DutyExpressionFormatter::Context do
  describe '.build' do
    let(:measurement_unit_abbreviation) do
      create(:measurement_unit_abbreviation, :with_measurement_unit, :include_qualifier)
    end
    let(:measurement_unit) do
      measurement_unit_abbreviation.measurement_unit
    end
    let(:measurement_unit_qualifier) do
      create(:measurement_unit_qualifier, measurement_unit_qualifier_code: measurement_unit_abbreviation.measurement_unit_qualifier)
    end

    it 'prefers the monetary unit abbreviation when both values are provided' do
      context = described_class.build(
        duty_expression_id: '12',
        monetary_unit: 'Euro',
        monetary_unit_abbreviation: 'EUR',
      )

      expect(context.monetary_unit).to eq('EUR')
    end

    it 'populates derived verbose fields when verbose output is requested' do
      context = described_class.build(
        duty_expression_id: '66',
        duty_amount: 0.52,
        monetary_unit: 'EUR',
        measurement_unit: measurement_unit,
        measurement_unit_qualifier: measurement_unit_qualifier,
        verbose: true,
      )

      expect(context.measurement_unit_abbreviation).to eq(
        measurement_unit.abbreviation(measurement_unit_qualifier: measurement_unit_qualifier),
      )
      expect(context.measurement_unit_expansion).to eq(
        measurement_unit.expansion(measurement_unit_qualifier: measurement_unit_qualifier),
      )
      expect(context.monetary_unit_to_symbol).to eq(
        Currency.new('EUR').format(DutyExpressionFormatter.prettify(0.52).to_s),
      )
    end

    it 'leaves verbose-only fields unset when verbose output is disabled' do
      context = described_class.build(
        duty_expression_id: '66',
        duty_amount: 0.52,
        monetary_unit: 'EUR',
        measurement_unit: measurement_unit,
        measurement_unit_qualifier: measurement_unit_qualifier,
        verbose: false,
      )

      expect(context.measurement_unit_expansion).to be_nil
      expect(context.monetary_unit_to_symbol).to be_nil
    end
  end
end
