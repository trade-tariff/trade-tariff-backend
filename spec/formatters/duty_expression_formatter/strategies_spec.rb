RSpec.shared_context 'with duty expression formatter strategy helpers' do
  let(:measurement_unit) { instance_double(MeasurementUnit, description: 'kilogram') }

  def build_context(overrides = {})
    DutyExpressionFormatter::Context.new(
      {
        duty_expression_id: '66',
        duty_expression_description: nil,
        duty_expression_abbreviation: nil,
        duty_amount: nil,
        monetary_unit: nil,
        measurement_unit: measurement_unit,
        measurement_unit_qualifier: nil,
        measurement_unit_abbreviation: nil,
        measurement_unit_expansion: nil,
        monetary_unit_to_symbol: nil,
        resolved_meursing_component: false,
        formatted: false,
        verbose: false,
      }.merge(overrides),
    )
  end
end

RSpec.describe DutyExpressionFormatter::Strategies::Base do
  include_context 'with duty expression formatter strategy helpers'

  describe DutyExpressionFormatter::Strategies::UnitOnly do
    it 'returns the measurement unit fragment' do
      context = build_context(
        duty_expression_id: '99',
        measurement_unit_abbreviation: 'kg',
      )

      expect(described_class.new(context).call).to eq(%w[kg])
    end
  end

  describe DutyExpressionFormatter::Strategies::DescriptionOnly do
    it 'prefers the duty expression abbreviation' do
      context = build_context(
        duty_expression_id: '12',
        duty_expression_abbreviation: 'MAX',
        duty_expression_description: 'Maximum duty',
      )

      expect(described_class.new(context).call).to eq(%w[MAX])
    end
  end

  describe DutyExpressionFormatter::Strategies::DescriptionAmount do
    it 'assembles description, amount, percent, and measurement unit fragments' do
      context = build_context(
        duty_expression_id: '15',
        duty_expression_description: 'MIN',
        duty_amount: 0.52,
        measurement_unit_abbreviation: 'kg',
      )

      expect(described_class.new(context).call).to eq(['MIN', '0.52', '%', '/ kg'])
    end

    it 'renders formatted measurement unit fragments when requested' do
      context = build_context(
        duty_expression_id: '15',
        duty_expression_description: 'MIN',
        duty_amount: 0.52,
        measurement_unit_abbreviation: 'kg',
        formatted: true,
      )

      expect(described_class.new(context).call).to eq([
        'MIN',
        '<span>0.52</span>',
        '%',
        "/ <abbr title='kilogram'>kg</abbr>",
      ])
    end
  end

  describe DutyExpressionFormatter::Strategies::Default do
    it 'returns the monetary symbol when verbose output is enabled' do
      context = build_context(
        duty_expression_description: 'Standard duty',
        duty_amount: 0.52,
        monetary_unit: 'EUR',
        monetary_unit_to_symbol: '€0.52',
        verbose: true,
      )

      expect(described_class.new(context).call).to eq(['€0.52'])
    end

    it 'falls back to a percent sign when no description is present' do
      context = build_context(duty_amount: 0.52)

      expect(described_class.new(context).call).to eq(['0.52', '%'])
    end
  end
end
