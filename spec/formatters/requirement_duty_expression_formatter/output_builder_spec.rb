RSpec.describe RequirementDutyExpressionFormatter::OutputBuilder do
  subject(:output) { described_class.call(context) }

  let(:measurement_unit) { instance_double(MeasurementUnit, description: 'kilogram', to_s: 'kilogram') }
  let(:context) do
    RequirementDutyExpressionFormatter::Context.new(**context_attributes)
  end
  let(:context_attributes) do
    {
      duty_amount: nil,
      monetary_unit: nil,
      measurement_unit:,
      measurement_unit_qualifier: nil,
      measurement_unit_abbreviation: nil,
      formatted: false,
    }
  end

  context 'when a duty amount is present' do
    let(:context_attributes) { super().merge(duty_amount: 3.5) }

    it 'renders the numeric amount' do
      expect(output).to eq(['3.50'])
    end

    context 'when formatted output is requested' do
      let(:context_attributes) { super().merge(formatted: true) }

      it 'wraps the amount in a span' do
        expect(output).to eq(['<span>3.50</span>'])
      end
    end
  end

  context 'when monetary unit, measurement unit, and qualifier are present' do
    let(:context_attributes) do
      super().merge(
        monetary_unit: 'EUR',
        measurement_unit_qualifier: 'L',
        measurement_unit_abbreviation: 'kg',
      )
    end

    it 'renders the combined qualifier fragment' do
      expect(output).to eq(['EUR / (kilogram / L)'])
    end

    context 'when formatted output is requested' do
      let(:context_attributes) { super().merge(formatted: true) }

      it 'renders the qualifier fragment with an abbreviation tag' do
        expect(output).to eq(["EUR / (<abbr title='kilogram'>kg</abbr> / L)"])
      end
    end
  end

  context 'when only a measurement unit is present' do
    let(:context_attributes) { super().merge(measurement_unit_abbreviation: 'kg') }

    it 'returns the measurement unit object for plain output' do
      expect(output).to eq([measurement_unit])
    end

    context 'when formatted output is requested' do
      let(:context_attributes) { super().merge(formatted: true) }

      it 'renders the measurement unit abbreviation tag' do
        expect(output).to eq(["<abbr title='kilogram'>kg</abbr>"])
      end
    end
  end

  context 'when only a monetary unit is present' do
    let(:context_attributes) { super().merge(monetary_unit: 'EUR') }

    it 'returns the monetary unit fragment' do
      expect(output).to eq(%w[EUR])
    end
  end
end
