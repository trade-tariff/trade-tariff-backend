RSpec.describe Measure::DutyExpressionPresenter do
  subject(:presenter) { described_class.new(measure) }

  let(:measure) { instance_double(Measure, measure_components: components, resolved_measure_components: []) }

  let(:components) do
    [
      instance_double(MeasureComponent, duty_expression_str: '12%', formatted_duty_expression: '12.00%', verbose_duty_expression: '12 %'),
      instance_double(MeasureComponent, duty_expression_str: '+ 5.00 EUR', formatted_duty_expression: '+ 5.00 EUR', verbose_duty_expression: '+ 5.00  EUR'),
    ]
  end

  describe '#plain' do
    it 'joins each component duty_expression_str with a space' do
      expect(presenter.plain).to eq '12% + 5.00 EUR'
    end
  end

  describe '#formatted' do
    it 'joins each component formatted_duty_expression with a space' do
      expect(presenter.formatted).to eq '12.00% + 5.00 EUR'
    end
  end

  describe '#verbose' do
    it 'joins verbose expressions, collapses double spaces, and removes space before %' do
      expect(presenter.verbose).to eq '12% + 5.00 EUR'
    end

    context 'when there is a double space in a component expression' do
      let(:components) do
        [instance_double(MeasureComponent, verbose_duty_expression: '10  %')]
      end

      it 'collapses double spaces to a single space' do
        expect(presenter.verbose).to eq '10%'
      end
    end

    context 'when there is a space between a number and a percent sign' do
      let(:components) do
        [instance_double(MeasureComponent, verbose_duty_expression: '10 %')]
      end

      it 'removes the space between the number and the percent sign' do
        expect(presenter.verbose).to eq '10%'
      end
    end
  end

  describe '#resolved' do
    context 'when the measure does not resolve Meursing components' do
      before { allow(measure).to receive(:resolves_meursing_measures?).and_return(false) }

      it 'returns an empty string' do
        expect(presenter.resolved).to eq ''
      end
    end

    context 'when the measure resolves Meursing components' do
      let(:resolved_component) { instance_double(MeasureComponent, formatted_duty_expression: '8.00%') }

      before do
        allow(measure).to receive_messages(
          resolves_meursing_measures?: true,
          resolved_measure_components: [resolved_component],
        )
      end

      it 'joins the resolved component formatted expressions' do
        expect(presenter.resolved).to eq '8.00%'
      end
    end
  end

  describe '#supplementary_unit' do
    context 'when the first component has no measurement unit' do
      let(:components) { [instance_double(MeasureComponent, measurement_unit: nil)] }

      it 'returns nil' do
        expect(presenter.supplementary_unit).to be_nil
      end
    end

    context 'when the first component has a measurement unit' do
      let(:unit) { instance_double(MeasurementUnit, description: 'Hectolitre', abbreviation: 'hl') }
      let(:components) { [instance_double(MeasureComponent, measurement_unit: unit)] }

      it 'returns a human-readable string with description and abbreviation' do
        expect(presenter.supplementary_unit).to eq 'Hectolitre (hl)'
      end
    end

    context 'when there are no components' do
      let(:components) { [] }

      it 'returns nil' do
        expect(presenter.supplementary_unit).to be_nil
      end
    end
  end
end
