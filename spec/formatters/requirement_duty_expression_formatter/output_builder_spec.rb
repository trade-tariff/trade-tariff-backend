RSpec.describe RequirementDutyExpressionFormatter::OutputBuilder do
  subject(:output) { described_class.call(context) }

  let(:measurement_unit) { instance_double(MeasurementUnit, description: 'kilogram', to_s: 'kilogram') }
  let(:context) do
    RequirementDutyExpressionFormatter::Context.new(
      duty_amount: duty_amount,
      monetary_unit: monetary_unit,
      measurement_unit: measurement_unit,
      measurement_unit_qualifier: measurement_unit_qualifier,
      measurement_unit_abbreviation: measurement_unit_abbreviation,
      formatted: formatted,
    )
  end
  let(:duty_amount) { nil }
  let(:monetary_unit) { nil }
  let(:measurement_unit_qualifier) { nil }
  let(:measurement_unit_abbreviation) { nil }
  let(:formatted) { false }

  context 'when a duty amount is present' do
    let(:duty_amount) { 3.5 }

    it 'renders the numeric amount' do
      expect(output).to eq(['3.50'])
    end

    context 'when formatted output is requested' do
      let(:formatted) { true }

      it 'wraps the amount in a span' do
        expect(output).to eq(['<span>3.50</span>'])
      end
    end
  end

  context 'when monetary unit, measurement unit, and qualifier are present' do
    let(:monetary_unit) { 'EUR' }
    let(:measurement_unit_qualifier) { 'L' }
    let(:measurement_unit_abbreviation) { 'kg' }

    it 'renders the combined qualifier fragment' do
      expect(output).to eq(['EUR / (kilogram / L)'])
    end

    context 'when formatted output is requested' do
      let(:formatted) { true }

      it 'renders the qualifier fragment with an abbreviation tag' do
        expect(output).to eq(["EUR / (<abbr title='kilogram'>kg</abbr> / L)"])
      end
    end
  end

  context 'when only a measurement unit is present' do
    let(:measurement_unit_abbreviation) { 'kg' }

    it 'returns the measurement unit object for plain output' do
      expect(output).to eq([measurement_unit])
    end

    context 'when formatted output is requested' do
      let(:formatted) { true }

      it 'renders the measurement unit abbreviation tag' do
        expect(output).to eq(["<abbr title='kilogram'>kg</abbr>"])
      end
    end
  end

  context 'when only a monetary unit is present' do
    let(:monetary_unit) { 'EUR' }

    it 'returns the monetary unit fragment' do
      expect(output).to eq(%w[EUR])
    end
  end
end
