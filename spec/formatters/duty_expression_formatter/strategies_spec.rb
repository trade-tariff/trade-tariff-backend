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

  describe '.format integration' do
    let(:measurement_unit) do
      instance_double(
        MeasurementUnit,
        description: 'kilogram',
        abbreviation: 'kg',
        expansion: 'kilogram (kg)',
      ).tap do |dbl|
        allow(dbl).to receive(:abbreviation).with(measurement_unit_qualifier: nil).and_return('kg')
        allow(dbl).to receive(:expansion).with(measurement_unit_qualifier: nil).and_return('kilogram (kg)')
      end
    end

    describe 'UnitOnly strategy (duty_expression_id 99)' do
      it 'returns the plain measurement unit abbreviation' do
        result = DutyExpressionFormatter.format(
          duty_expression_id: '99',
          measurement_unit:,
          measurement_unit_qualifier: nil,
        )

        expect(result).to eq('kg')
      end

      it 'returns a formatted abbr tag when formatted: true' do
        result = DutyExpressionFormatter.format(
          duty_expression_id: '99',
          measurement_unit:,
          measurement_unit_qualifier: nil,
          formatted: true,
        )

        expect(result).to eq("<abbr title='kilogram'>kg</abbr>")
      end

      it 'returns the expanded unit when verbose: true' do
        result = DutyExpressionFormatter.format(
          duty_expression_id: '99',
          measurement_unit:,
          measurement_unit_qualifier: nil,
          verbose: true,
        )

        expect(result).to eq('kilogram (kg)')
      end
    end

    describe 'DescriptionOnly strategy (duty_expression_id 12)' do
      it 'returns the duty expression abbreviation when present' do
        result = DutyExpressionFormatter.format(
          duty_expression_id: '12',
          duty_expression_abbreviation: 'MAX',
          duty_expression_description: 'Maximum',
        )

        expect(result).to eq('MAX')
      end

      it 'falls back to description when abbreviation is absent' do
        result = DutyExpressionFormatter.format(
          duty_expression_id: '12',
          duty_expression_description: 'Maximum',
        )

        expect(result).to eq('Maximum')
      end
    end

    describe 'DescriptionAmount strategy (duty_expression_id 02)' do
      it 'returns plain description, amount and percent for a simple case' do
        result = DutyExpressionFormatter.format(
          duty_expression_id: '02',
          duty_expression_abbreviation: 'MIN',
          duty_amount: 1.5,
        )

        expect(result).to eq('MIN 1.50 %')
      end

      it 'returns formatted HTML fragments when formatted: true' do
        result = DutyExpressionFormatter.format(
          duty_expression_id: '02',
          duty_expression_abbreviation: 'MIN',
          duty_amount: 1.5,
          formatted: true,
        )

        expect(result).to eq('MIN <span>1.50</span> %')
      end

      it 'includes the measurement unit when present' do
        result = DutyExpressionFormatter.format(
          duty_expression_id: '02',
          duty_expression_abbreviation: 'MIN',
          duty_amount: 1.5,
          measurement_unit:,
          measurement_unit_qualifier: nil,
        )

        expect(result).to eq('MIN 1.50 % / kg')
      end
    end

    describe 'Default strategy (other duty expression ids)' do
      it 'returns amount and percent for a simple case' do
        result = DutyExpressionFormatter.format(
          duty_expression_id: '66',
          duty_amount: 4.0,
        )

        expect(result).to eq('4.00 %')
      end

      it 'returns amount and monetary unit when monetary unit is present' do
        result = DutyExpressionFormatter.format(
          duty_expression_id: '66',
          duty_amount: 4.0,
          monetary_unit: 'GBP',
        )

        expect(result).to eq('4.00 % GBP')
      end

      it 'returns formatted HTML when formatted: true' do
        result = DutyExpressionFormatter.format(
          duty_expression_id: '66',
          duty_amount: 4.0,
          formatted: true,
        )

        expect(result).to eq('<span>4.00</span> %')
      end

      it 'includes a measurement unit when present' do
        result = DutyExpressionFormatter.format(
          duty_expression_id: '66',
          duty_amount: 4.0,
          measurement_unit:,
          measurement_unit_qualifier: nil,
        )

        expect(result).to eq('4.00 % / kg')
      end

      it 'wraps output in strong tags when resolved_meursing: true' do
        result = DutyExpressionFormatter.format(
          duty_expression_id: '66',
          duty_amount: 4.0,
          resolved_meursing: true,
        )

        expect(result).to eq('<strong>4.00 %</strong>')
      end
    end
  end
end
